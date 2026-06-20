"""
Point d'entrée de l'application Flask.

Lance le serveur Flask en HTTPS (certificat mkcert si présent, sinon HTTP
en clair), génère un token de pairing et affiche le QR code à scanner depuis
le téléphone, puis sert l'API ainsi que l'interface (dossier ./static, au
même niveau que ce fichier).

Démarrage (depuis la racine du projet backend, là où se trouve ce fichier) :
    pip install -r requirements.txt
    python main.py

Puis ouvrir, sur cet ordinateur : http://<IP locale>:8443/
(ou https://... si un certificat mkcert est présent dans ./certs/)
"""

import socket
import webbrowser
from pathlib import Path
from threading import Timer

import qrcode
from flask import Flask, redirect, send_from_directory
from flask_cors import CORS
from flask_socketio import SocketIO

from api.transfertapi import transfert_bp, init_socketio
from service.transfertservice import transfert_service

# ---------- Configuration ----------

HOST = "0.0.0.0"  # écoute sur toutes les interfaces locales (WiFi compris)
PORT = 8443

CERT_DIR = Path(__file__).resolve().parent / "certs"
CERT_FILE = CERT_DIR / "cert.pem"
KEY_FILE = CERT_DIR / "key.pem"

# Dossier contenant l'interface (HTML/CSS/JS), au même niveau que main.py.
STATIC_DIR = Path(__file__).resolve().parent / "static"


def get_local_ip() -> str:
    """Détermine l'IP locale de la machine sur le réseau WiFi/Ethernet."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # On ne se connecte pas réellement : ça sert juste à déterminer
        # quelle interface réseau locale serait utilisée pour sortir.
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        sock.close()


def print_pairing_qr_code(url: str) -> None:
    """Affiche un QR code en ASCII dans le terminal, pour un scan rapide depuis le téléphone."""
    qr = qrcode.QRCode(border=1)
    qr.add_data(url)
    qr.make()
    qr.print_ascii(invert=True)
    print(f"\nURL de connexion (mobile) : {url}\n")


def create_app() -> Flask:
    app = Flask(__name__, static_folder=str(STATIC_DIR), static_url_path="/app")

    # CORS permissif en local : PC (interface web) et mobile consomment la même API
    CORS(
        app,
        resources={
            r"/api/*": {
                "origins": "*",
                "methods": ["GET", "POST", "DELETE", "OPTIONS"],
                "allow_headers": ["*"],
            }
        },
    )

    # Un token de pairing est toujours actif dès que le serveur répond,
    # que l'app soit lancée via `python main.py` ou par un autre serveur WSGI :
    # on le génère ici plutôt que de dépendre du bloc __main__.
    if transfert_service.current_token() is None:
        transfert_service.generate_token()

    # Enregistre le blueprint de l'API
    app.register_blueprint(transfert_bp)

    # Initialise SocketIO pour les WebSockets
    socketio = init_socketio(app)

    @app.route("/", methods=["GET"])
    def root():
        """Page d'accueil : redirige vers l'écran de réception."""
        return redirect("/app/reception.html")

    @app.route("/app/<path:path>", methods=["GET"])
    def serve_static(path):
        """Sert les fichiers statiques (HTML/CSS/JS) sous /app."""
        if not STATIC_DIR.exists():
            return f"⚠️  Dossier static introuvable : {STATIC_DIR}", 404
        
        if path == "":
            path = "reception.html"
        
        return send_from_directory(STATIC_DIR, path)

    return app, socketio


app, socketio = create_app()


def _open_browser(url: str) -> None:
    try:
        webbrowser.open(url)
    except Exception:
        pass


if __name__ == "__main__":
    local_ip = get_local_ip()
    token = transfert_service.current_token() or transfert_service.generate_token()

    ssl_context = None
    scheme = "http"
    
    if CERT_FILE.exists() and KEY_FILE.exists():
        ssl_context = (str(CERT_FILE), str(KEY_FILE))
        scheme = "https"
    else:
        print(
            "⚠️  Aucun certificat trouvé dans ./certs/ (cert.pem, key.pem).\n"
            "   Le serveur démarre en HTTP. Génère un certificat avec mkcert pour activer HTTPS, ex :\n"
            f"   mkcert -install && mkcert -cert-file certs/cert.pem "
            f"-key-file certs/key.pem {local_ip} localhost 127.0.0.1\n"
        )

    pairing_url = f"{scheme}://{local_ip}:{PORT}/api/pair?token={token}"
    local_app_url = f"{scheme}://{local_ip}:{PORT}/"

    print("=" * 60)
    print(" Serveur de partage de fichiers démarré")
    print("=" * 60)
    print(f" Interface (sur cet ordinateur) : {local_app_url}")
    print_pairing_qr_code(pairing_url)
    print(" Scannez ce QR code depuis votre téléphone pour vous connecter.")
    print("=" * 60)

    # Ouvre automatiquement l'interface dans le navigateur par défaut,
    # une fois le serveur prêt à répondre.
    Timer(1.2, _open_browser, args=(local_app_url,)).start()

    # Lance le serveur Flask avec SocketIO
    socketio.run(
        app,
        host=HOST,
        port=PORT,
        ssl_context=ssl_context,
        debug=False,
        allow_unsafe_werkzeug=True
    )
