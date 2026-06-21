"""
Routes HTTP et WebSocket de l'API de transfert de fichiers.

Toute la logique métier est déléguée au service `transfert_service`
(voir service/transfertservice.py). Ce module ne fait que :
- exposer les endpoints REST
- vérifier l'authentification (token de pairing)
- gérer les connexions WebSocket pour notifier les clients en temps réel
"""

import io
from typing import Optional
from functools import wraps

import eventlet
import qrcode
from flask import Blueprint, request, jsonify, send_file, abort
from flask_socketio import SocketIO, emit, disconnect

from service.transfertservice import transfert_service

transfert_bp = Blueprint('transfert', __name__, url_prefix='/api')


# ---------- Gestionnaire WebSocket avec SocketIO ----------

class ConnectionManager:
    """Garde la liste des clients WebSocket connectés et diffuse les événements."""

    def __init__(self) -> None:
        self._connections = set()

    def add_connection(self, sid: str) -> None:
        """Enregistre une nouvelle connexion WebSocket."""
        self._connections.add(sid)

    def remove_connection(self, sid: str) -> None:
        """Supprime une connexion WebSocket fermée."""
        if sid in self._connections:
            self._connections.remove(sid)

    def broadcast(self, event: str, payload: dict) -> None:
        """Envoie un événement JSON à tous les clients connectés."""
        message = {"event": event, "data": payload}
        socketio.emit(event, message, namespace='/api/ws')


manager = ConnectionManager()
socketio = SocketIO()

# Intervalle (en secondes) entre deux vérifications de l'IP locale, pour
# détecter une coupure WiFi / un changement de réseau.
NETWORK_CHECK_INTERVAL_SECONDS = 5


def _network_watch_loop():
    """
    Tâche de fond (greenlet eventlet) : vérifie périodiquement que l'IP
    locale de la machine n'a pas changé. Si le WiFi est coupé ou que la
    machine a rejoint un autre réseau, le token est régénéré côté service
    (voir TransfertService.check_network_or_invalidate) et les clients
    encore connectés sont notifiés pour qu'ils invalident leur session
    et réaffichent un nouveau QR code.
    """
    while True:
        eventlet.sleep(NETWORK_CHECK_INTERVAL_SECONDS)
        try:
            if transfert_service.check_network_or_invalidate():
                manager.broadcast("session:expired", {
                    "reason": "network-changed",
                })
        except Exception:
            # Ne jamais laisser la boucle de surveillance mourir sur une
            # erreur ponctuelle (ex: résolution réseau temporairement KO).
            pass


def start_network_watch():
    """Démarre la surveillance réseau en arrière-plan (appelé depuis main.py)."""
    eventlet.spawn(_network_watch_loop)


# ---------- Dépendance d'authentification ----------

def require_valid_token(f):
    """
    Décorateur pour vérifier que l'en-tête `Authorization: Bearer <token>` 
    contient un token valide.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        authorization = request.headers.get('Authorization')
        
        if not authorization or not authorization.startswith("Bearer "):
            return jsonify({"detail": "Token manquant"}), 401

        token = authorization.removeprefix("Bearer ").strip()
        if not transfert_service.is_token_valid(token):
            return jsonify({"detail": "Token invalide ou expiré"}), 401

        # Passe le token à la fonction
        kwargs['token'] = token
        return f(*args, **kwargs)
    
    return decorated_function


def get_token_from_query():
    """Récupère et valide le token depuis la query string."""
    token = request.args.get('token', '')
    if not transfert_service.is_token_valid(token):
        return None
    return token


# ---------- Routes REST ----------

@transfert_bp.route("/ping", methods=["GET"])
def ping():
    """Permet au client de vérifier que le serveur est joignable."""
    return jsonify({"status": "ok"})


@transfert_bp.route("/pair", methods=["POST"])
def pair():
    """Valide le token scanné via QR code et confirme l'appairage."""
    data = request.get_json() or {}
    token = data.get('token')
    
    if not token or not transfert_service.is_token_valid(token):
        return jsonify({"detail": "Token invalide ou expiré"}), 401
    
    return jsonify({"status": "paired"})


@transfert_bp.route("/session", methods=["GET"])
def session():
    """
    Retourne le token de pairing courant.

    Utilisé uniquement par l'interface PC (servie depuis ce même serveur) pour
    s'auto-appairer sans avoir à scanner le QR code, qui lui reste destiné au
    mobile distant. Ne fuit aucune donnée sensible côté réseau externe puisque
    le token affiché ici est le même que celui imprimé en clair au démarrage.
    """
    token = transfert_service.current_token()
    if not token:
        return jsonify({"detail": "Aucune session active"}), 404
    return jsonify({"token": token})


@transfert_bp.route("/qrcode", methods=["GET"])
def qrcode_image():
    """
    Génère et retourne le QR code de pairing en PNG, entièrement côté serveur
    (aucun appel à un service externe type api.qrserver.com).

    Volontairement accessible sans authentification : c'est ce QR code qui
    contient le token, donc l'exiger en amont serait une impasse. Le risque
    est le même que celui déjà accepté pour /session (token visible en clair
    sur le réseau local), seulement encodé en image plutôt qu'en JSON.
    """
    token = transfert_service.current_token()
    if not token:
        return jsonify({"detail": "Aucune session active"}), 404

    # Reconstruit la même URL de pairing que celle affichée au démarrage
    # dans le terminal (voir print_pairing_qr_code dans main.py), à partir
    # de cette requête HTTP plutôt que de recalculer l'IP locale ici.
    # Pointe vers la page web réelle (et non vers /api/pair, qui est une
    # route purement API en POST attendant du JSON : un scan de QR code
    # ouvre toujours l'URL en GET dans le navigateur, donc /api/pair ne
    # mène à aucune page utilisable). fts-api.js lit le paramètre ?token=
    # au chargement de la page et appelle lui-même /api/pair en arrière-plan
    # (voir readTokenFromUrl / ensureToken / pair() dans fts-api.js).
    pairing_url = f"{request.scheme}://{request.host}/app/reception.html?token={token}"

    qr = qrcode.QRCode(border=2, box_size=8)
    qr.add_data(pairing_url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    buffer.seek(0)

    response = send_file(buffer, mimetype="image/png")
    # Le token change au redémarrage : on évite que le navigateur garde
    # une vieille image en cache après une régénération de session.
    response.headers["Cache-Control"] = "no-store"
    return response


@transfert_bp.route("/upload", methods=["POST"])
@require_valid_token
def upload_file(token=None):
    """Reçoit un fichier (envoyé par le PC ou le mobile) et le stocke côté serveur."""
    
    # Vérifie que le fichier est présent
    if 'file' not in request.files:
        return jsonify({"detail": "Aucun fichier fourni"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"detail": "Nom de fichier vide"}), 400
    
    content = file.read()
    direction = request.form.get('direction', 'mobile-to-pc')
    
    metadata = transfert_service.save_file(
        filename=file.filename or "fichier_sans_nom",
        content=content,
        mime_type=file.content_type or "application/octet-stream",
        direction=direction,
    )

    # Diffuse les événements aux clients WebSocket
    manager.broadcast("transfer:complete", metadata.to_dict())
    manager.broadcast("files:updated", {"files": transfert_service.list_files()})

    return jsonify(metadata.to_dict())


@transfert_bp.route("/files", methods=["GET"])
@require_valid_token
def list_files(token=None):
    """Retourne la liste des fichiers disponibles dans la session courante."""
    return jsonify({"files": transfert_service.list_files()})


@transfert_bp.route("/download/<file_id>", methods=["GET"])
@require_valid_token
def download_file(file_id, token=None):
    """Télécharge un fichier par son identifiant."""
    path = transfert_service.get_file_path(file_id)
    metadata = transfert_service.get_metadata(file_id)
    
    if not path or not metadata:
        return jsonify({"detail": "Fichier introuvable"}), 404

    return send_file(
        path,
        as_attachment=True,
        download_name=metadata.name,
        mimetype=metadata.mime_type
    )


@transfert_bp.route("/files/<file_id>", methods=["DELETE"])
@require_valid_token
async def delete_file(file_id, token=None):
    """Supprime un fichier de la session courante."""
    deleted = transfert_service.delete_file(file_id)
    
    if not deleted:
        return jsonify({"detail": "Fichier introuvable"}), 404

    manager.broadcast("files:updated", {"files": transfert_service.list_files()})
    return jsonify({"status": "deleted"})


# ---------- WebSocket ----------

@socketio.on('connect', namespace='/api/ws')
def websocket_connect(auth):
    """Gère la connexion WebSocket avec validation du token."""
    token = auth.get('token') if auth else None
    
    if not token or not transfert_service.is_token_valid(token):
        disconnect()
        return False
    
    manager.add_connection(request.sid)
    emit('connected', {'status': 'ok'})


@socketio.on('disconnect', namespace='/api/ws')
def websocket_disconnect():
    """Gère la déconnexion WebSocket."""
    manager.remove_connection(request.sid)


def init_socketio(app):
    """Initialise SocketIO avec l'app Flask."""
    global socketio
    socketio.init_app(app, cors_allowed_origins="*")
    return socketio