# ==============================================================================
# Telecharge Bootstrap, Font Awesome et Socket.IO en local dans static/vendor/
# A lancer UNE SEULE FOIS, depuis une machine connectee a internet, a la racine
# de ton dossier "static" (la ou se trouvent envoi.html, reception.html...).
#
# Usage (PowerShell, depuis le dossier static) :
#   powershell -ExecutionPolicy Bypass -File telecharger_dependances.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path "vendor\bootstrap\css" | Out-Null
New-Item -ItemType Directory -Force -Path "vendor\bootstrap\js" | Out-Null
New-Item -ItemType Directory -Force -Path "vendor\fontawesome\css" | Out-Null
New-Item -ItemType Directory -Force -Path "vendor\fontawesome\webfonts" | Out-Null
New-Item -ItemType Directory -Force -Path "vendor\socketio" | Out-Null

Write-Host "-> Bootstrap CSS..."
Invoke-WebRequest -Uri "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/5.3.3/css/bootstrap.min.css" -OutFile "vendor\bootstrap\css\bootstrap.min.css"

Write-Host "-> Bootstrap JS (bundle, inclut Popper)..."
Invoke-WebRequest -Uri "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/5.3.3/js/bootstrap.bundle.min.js" -OutFile "vendor\bootstrap\js\bootstrap.bundle.min.js"

Write-Host "-> Font Awesome CSS..."
Invoke-WebRequest -Uri "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" -OutFile "vendor\fontawesome\css\all.min.css"

Write-Host "-> Font Awesome webfonts (necessaires pour que les icones s'affichent)..."
$fonts = @("fa-brands-400", "fa-regular-400", "fa-solid-900", "fa-v4compatibility")
$exts = @("woff2", "ttf")
foreach ($font in $fonts) {
    foreach ($ext in $exts) {
        $url = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/webfonts/$font.$ext"
        $out = "vendor\fontawesome\webfonts\$font.$ext"
        try {
            Invoke-WebRequest -Uri $url -OutFile $out
        } catch {
            Write-Host "   (ignore, fichier optionnel introuvable : $font.$ext)"
        }
    }
}

Write-Host "-> Socket.IO client..."
Invoke-WebRequest -Uri "https://cdn.socket.io/4.8.3/socket.io.min.js" -OutFile "vendor\socketio\socket.io.min.js"

Write-Host ""
Write-Host "Termine. Arborescence :"
Get-ChildItem -Recurse vendor | Where-Object { -not $_.PSIsContainer } | ForEach-Object { Write-Host $_.FullName }
