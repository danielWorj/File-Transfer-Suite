@echo off
REM Génère app.exe à partir du projet Flask avec PyInstaller
REM À lancer depuis le répertoire du projet

echo ========================================
echo  Compilation du projet Flask en EXE
echo ========================================

REM Étape 1 : Installer les dépendances si nécessaire
echo.
echo [1/3] Installation des dépendances...
pip install -r requirements.txt
if errorlevel 1 goto :error

REM Étape 2 : Installer PyInstaller si nécessaire
echo.
echo [2/3] Installation de PyInstaller...
pip install pyinstaller
if errorlevel 1 goto :error

REM Étape 3 : Générer l'EXE
echo.
echo [3/3] Génération de l'exécutable...
pyinstaller app.spec --clean
if errorlevel 1 goto :error

echo.
echo ========================================
echo  ✅ EXE généré avec succès !
echo ========================================
echo.
echo Votre exécutable se trouve à :
echo   .\dist\app.exe
echo.
echo 📌 IMPORTANT : Avant de lancer app.exe, assurez-vous que ces dossiers
echo    se trouvent dans le même répertoire que l'EXE :
echo    - static\        (interface web)
echo    - certs\         (certificats SSL, optionnel)
echo.
echo ℹ️  Les fichiers transférés seront stockés dans :
echo    .\storage\       (créé automatiquement au démarrage)
echo.
pause
goto :end

:error
echo.
echo ❌ ERREUR lors de la compilation !
echo Vérifiez que Python et pip sont correctement installés.
pause

:end
