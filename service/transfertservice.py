"""
Service de gestion des transferts de fichiers - VERSION PYINSTALLER.

Ce module contient toute la logique métier :
- génération et validation du token de pairing (connexion PC <-> mobile)
- stockage des fichiers reçus sur le disque
- gestion des métadonnées des fichiers (liste, suppression)

Il ne contient aucune route HTTP : ça, c'est le rôle de `api/transfertapi.py`.

IMPORTANT : Ce fichier doit être dans le répertoire service/ qui est au même
niveau que main.py, pour que les chemins relatifs fonctionnent correctement.
"""

import sys
import shutil
import secrets
import socket
import uuid
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

# Déterminer le répertoire de base (compatible PyInstaller et mode normal)
if getattr(sys, 'frozen', False):
    # Mode EXE PyInstaller
    BASE_DIR = Path(sys.executable).resolve().parent
else:
    # Mode Python standard (recalculer depuis ce fichier)
    BASE_DIR = Path(__file__).resolve().parent.parent

# Dossier où sont stockés physiquement les fichiers transférés
STORAGE_DIR = BASE_DIR / "storage"
STORAGE_DIR.mkdir(exist_ok=True)

# Durée de validité du token de pairing (en minutes)
TOKEN_TTL_MINUTES = 10


def get_local_ip() -> Optional[str]:
    """
    Détermine l'IP locale de la machine sur le réseau WiFi/Ethernet, de la
    même façon que main.py (connexion UDP "à blanc" vers une IP publique,
    qui ne fait aucun trafic réel mais force l'OS à choisir une interface
    locale). Retourne None si aucune interface réseau n'est disponible
    (WiFi coupé, câble débranché, etc.) : c'est ce None qui sert de signal
    de coupure pour invalider le token de pairing.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return None
    finally:
        sock.close()


@dataclass
class FileMetadata:
    """Métadonnées associées à un fichier transféré."""

    id: str
    name: str
    size: int
    mime_type: str
    uploaded_at: str
    direction: str  # "pc-to-mobile" ou "mobile-to-pc"

    def to_dict(self) -> dict:
        return asdict(self)


class TransfertService:
    """
    Service central : gère le token de session et les fichiers en mémoire + disque.
    Une seule instance est partagée par toute l'application (voir main.py).
    """

    def __init__(self) -> None:
        self._token: Optional[str] = None
        self._token_expires_at: Optional[datetime] = None
        self._token_ip: Optional[str] = None
        self._files: dict[str, FileMetadata] = {}

    # ---------- Pairing / token ----------

    def generate_token(self) -> str:
        """Génère un nouveau token de pairing et invalide l'ancien."""
        self._token = secrets.token_urlsafe(24)
        self._token_expires_at = datetime.utcnow() + timedelta(minutes=TOKEN_TTL_MINUTES)
        # Mémorise l'IP locale au moment de la génération : c'est ce
        # "snapshot" qui sert de référence pour détecter une coupure WiFi
        # (voir check_network_or_invalidate).
        self._token_ip = get_local_ip()
        return self._token

    def is_token_valid(self, token: str) -> bool:
        """Vérifie qu'un token correspond au token courant et n'est pas expiré."""
        if not self._token or not self._token_expires_at:
            return False
        if token != self._token:
            return False
        if datetime.utcnow() > self._token_expires_at:
            return False
        return True

    def current_token(self) -> Optional[str]:
        return self._token

    def invalidate_token(self) -> None:
        """Invalide immédiatement le token courant (sans en générer un nouveau)."""
        self._token = None
        self._token_expires_at = None
        self._token_ip = None

    def check_network_or_invalidate(self) -> bool:
        """
        Vérifie que l'IP locale n'a pas changé depuis la génération du token
        courant. Si le WiFi a été coupé (plus d'IP) ou que la machine a
        basculé sur un autre réseau (IP différente), le token est régénéré :
        un appareil resté connecté à l'ancien réseau ne doit plus pouvoir
        s'en servir.

        Retourne True si le token a été régénéré (changement détecté),
        False si tout est inchangé.
        """
        if not self._token:
            return False

        current_ip = get_local_ip()
        if current_ip != self._token_ip:
            self.generate_token()
            return True
        return False

    # ---------- Fichiers ----------

    def save_file(self, filename: str, content: bytes, mime_type: str, direction: str) -> FileMetadata:
        """Sauvegarde un fichier reçu sur le disque et enregistre ses métadonnées."""
        file_id = str(uuid.uuid4())
        destination = STORAGE_DIR / f"{file_id}_{filename}"
        destination.write_bytes(content)

        metadata = FileMetadata(
            id=file_id,
            name=filename,
            size=len(content),
            mime_type=mime_type or "application/octet-stream",
            uploaded_at=datetime.utcnow().isoformat(),
            direction=direction,
        )
        self._files[file_id] = metadata
        return metadata

    def list_files(self) -> list[dict]:
        """Retourne la liste des fichiers disponibles dans la session courante."""
        return [f.to_dict() for f in self._files.values()]

    def get_file_path(self, file_id: str) -> Optional[Path]:
        """Retourne le chemin disque du fichier correspondant à l'id, ou None si introuvable."""
        metadata = self._files.get(file_id)
        if not metadata:
            return None
        path = STORAGE_DIR / f"{file_id}_{metadata.name}"
        return path if path.exists() else None

    def get_metadata(self, file_id: str) -> Optional[FileMetadata]:
        return self._files.get(file_id)

    def delete_file(self, file_id: str) -> bool:
        """Supprime un fichier (disque + métadonnées). Retourne True si la suppression a réussi."""
        metadata = self._files.pop(file_id, None)
        if not metadata:
            return False
        path = STORAGE_DIR / f"{file_id}_{metadata.name}"
        if path.exists():
            path.unlink()
        return True

    def clear_all(self) -> None:
        """Vide entièrement le stockage (utile au redémarrage du serveur)."""
        self._files.clear()
        if STORAGE_DIR.exists():
            shutil.rmtree(STORAGE_DIR)
        STORAGE_DIR.mkdir(exist_ok=True)


# Instance unique partagée par toute l'application
transfert_service = TransfertService()