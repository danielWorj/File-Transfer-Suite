# -*- mode: python ; coding: utf-8 -*-
"""
Fichier de configuration PyInstaller pour générer app.exe
À lancer depuis le répertoire du projet : pyinstaller app.spec
"""

from pathlib import Path
from PyInstaller.utils.hooks import collect_submodules

block_cipher = None

# Dans un fichier .spec, utiliser SPECPATH (variable fournie par PyInstaller)
PROJECT_DIR = Path(SPECPATH)

# eventlet choisit son "hub" (epolls, kqueue, selects, poll...) dynamiquement
# à l'exécution via importlib, donc PyInstaller ne peut pas les détecter par
# analyse statique du code. Il faut donc forcer l'inclusion de TOUS les
# sous-modules de eventlet.hubs (et de eventlet en général), sinon l'EXE
# plante sur une autre machine avec "No module named 'eventlet.hubs.epolls'".
hidden_eventlet = collect_submodules('eventlet')
hidden_engineio = collect_submodules('engineio')
hidden_socketio = collect_submodules('socketio')
hidden_dns = collect_submodules('dns')  # dépendance d'eventlet (eventlet.support.greendns)

a = Analysis(
    ['main.py'],
    pathex=[str(PROJECT_DIR)],
    binaries=[],
    datas=[
        (str(PROJECT_DIR / 'static'), 'static'),
    ],
    hiddenimports=[
        'flask',
        'flask_cors',
        'flask_socketio',
        'python_socketio',
        'python_engineio',
        'qrcode',
        'PIL',
        'engineio.async_drivers.eventlet',
    ] + hidden_eventlet + hidden_engineio + hidden_socketio + hidden_dns,
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='Fts',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
