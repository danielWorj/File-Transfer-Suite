"""
Point d'entrée de l'application Flask - VERSION PYINSTALLER.

Lance le serveur Flask en HTTPS (certificat mkcert si présent, sinon HTTP
en clair), génère un token de pairing et affiche le QR code à scanner depuis
le téléphone, puis sert l'API ainsi que l'interface (dossier ./static).

Peut être lancé comme :
  - Application Python : python main.py
  - Exécutable Windows : app.exe (généré par PyInstaller)

IMPORTANT : Si lancé depuis un .exe, les dossiers ./static, ./certs et ./storage
doivent être au même niveau que l'EXE, OU seront créés/utilisés depuis le répertoire
où se trouve l'EXE.
"""

import sys
import eventlet
eventlet.monkey_patch()

import os
import socket
import webbrowser
from pathlib import Path
from threading import Timer

import qrcode
from flask import Flask, redirect, send_from_directory
from flask_cors import CORS
from flask_socketio import SocketIO

# Déterminer le répertoire de base : soit celui du script .py, soit celui de l'EXE
if getattr(sys, 'frozen', False):
    # Lancé depuis un .exe PyInstaller
    BASE_DIR = Path(sys.executable).resolve().parent
else:
    # Lancé en Python standard
    BASE_DIR = Path(__file__).resolve().parent

# Importer après avoir défini BASE_DIR (les modules du projet peuvent en avoir besoin)
from api.transfertapi import transfert_bp, init_socketio, start_network_watch
from service.transfertservice import transfert_service

# ---------- Configuration ----------

HOST = "0.0.0.0"
PORT = 8443

CERT_DIR = BASE_DIR / "certs"
CERT_FILE = CERT_DIR / "cert.pem"
KEY_FILE = CERT_DIR / "key.pem"

# Dossier contenant l'interface (HTML/CSS/JS)
STATIC_DIR = BASE_DIR / "static"

# S'assurer que les dossiers nécessaires existent
CERT_DIR.mkdir(exist_ok=True)


def get_local_ip() -> str:
    """Détermine l'IP locale de la machine sur le réseau WiFi/Ethernet."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        sock.close()


def print_pairing_qr_code(url: str) -> None:
    """Affiche un QR code en ASCII dans le terminal."""
    qr = qrcode.QRCode(border=1)
    qr.add_data(url)
    qr.make()
    qr.print_ascii(invert=True)
    print(f"\nURL de connexion (mobile) : {url}\n")


def create_app() -> Flask:
    app = Flask(__name__, static_folder=str(STATIC_DIR), static_url_path="/app")

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

    # Repart sur un stockage vide à chaque démarrage du serveur : les
    # fichiers d'une session précédente n'ont aucune raison de persister
    # et de continuer à occuper de l'espace disque inutilement.
    transfert_service.clear_all()

    if transfert_service.current_token() is None:
        transfert_service.generate_token()

    app.register_blueprint(transfert_bp)
    socketio = init_socketio(app)

    # Surveille en continu l'IP locale : si le WiFi est coupé ou que la
    # machine change de réseau, le token de pairing est automatiquement
    # invalidé/régénéré (voir TransfertService.check_network_or_invalidate).
    start_network_watch()

    @app.route("/", methods=["GET"])
    def root():
        return redirect("/app/reception.html")

    @app.route("/app/<path:path>", methods=["GET"])
    def serve_static(path):
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

    ssl_kwargs = {}
    scheme = "http"
    
    if CERT_FILE.exists() and KEY_FILE.exists():
        ssl_kwargs = {
            "certfile": str(CERT_FILE),
            "keyfile": str(KEY_FILE)
        }
        scheme = "https"
    else:
        print(
            "⚠️  Aucun certificat trouvé dans ./certs/ (cert.pem, key.pem).\n"
            "   Le serveur démarre en HTTP. Génère un certificat avec mkcert pour activer HTTPS, ex :\n"
            f"   mkcert -install && mkcert -cert-file certs/cert.pem "
            f"-key-file certs/key.pem {local_ip} localhost 127.0.0.1\n"
        )

    pairing_url = f"{scheme}://{local_ip}:{PORT}/app/reception.html?token={token}"
    local_app_url = f"{scheme}://{local_ip}:{PORT}/"

    print("=" * 60)
    print(" Serveur de partage de fichiers démarré")
    print("=" * 60)
    print(f" Interface (sur cet ordinateur) : {local_app_url}")
    print_pairing_qr_code(pairing_url)
    print(" Scannez ce QR code depuis votre téléphone pour vous connecter.")
    print("=" * 60)

    # Ouvre automatiquement l'interface dans le navigateur par défaut
    Timer(1.2, _open_browser, args=(local_app_url,)).start()

    # Lance le serveur Flask avec SocketIO
    socketio.run(
        app,
        host=HOST,
        port=PORT,
        debug=False,
        allow_unsafe_werkzeug=True,
        **ssl_kwargs
    )