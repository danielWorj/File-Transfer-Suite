"""
Service de gestion des transferts de fichiers.

Ce module contient toute la logique métier :
- génération et validation du token de pairing (connexion PC <-> mobile)
- stockage des fichiers reçus sur le disque
- gestion des métadonnées des fichiers (liste, suppression)

Il ne contient aucune route HTTP : ça, c'est le rôle de `api/transfertapi.py`.
"""

import shutil
import secrets
import uuid
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

# Dossier où sont stockés physiquement les fichiers transférés
STORAGE_DIR = Path(__file__).resolve().parent.parent / "storage"
STORAGE_DIR.mkdir(exist_ok=True)

# Durée de validité du token de pairing (en minutes)
TOKEN_TTL_MINUTES = 10


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
        self._files: dict[str, FileMetadata] = {}

    # ---------- Pairing / token ----------

    def generate_token(self) -> str:
        """Génère un nouveau token de pairing et invalide l'ancien."""
        self._token = secrets.token_urlsafe(24)
        self._token_expires_at = datetime.utcnow() + timedelta(minutes=TOKEN_TTL_MINUTES)
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
