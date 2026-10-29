# ==============================================================================
# Script de création du Package Client Geoxal ERP (Release Distribution)
# ==============================================================================

$sourceRelease = "e:\Geoxal\build\windows\x64\runner\Release"
$distFolder = "e:\Geoxal\dist\Geoxal_Package_Client"

Write-Host "[*] Préparation du dossier de distribution : $distFolder..." -ForegroundColor Yellow

if (Test-Path $distFolder) {
    Remove-Item -Recurse -Force $distFolder
}
New-Item -ItemType Directory -Path $distFolder -Force | Out-Null

# 1. Copier les fichiers exécutables Flutter
Write-Host "[*] Copie des fichiers exécutables (geoxal.exe, flutter_windows.dll, data/)..." -ForegroundColor Cyan
Copy-Item -Path "$sourceRelease\*" -Destination $distFolder -Recurse -Force

# 2. Copier les scripts d'installation automatique et le schéma SQL
Write-Host "[*] Copie des outils d'installation automatique..." -ForegroundColor Cyan
Copy-Item -Path "e:\Geoxal\setup_server.bat" -Destination $distFolder -Force
Copy-Item -Path "e:\Geoxal\setup_server.ps1" -Destination $distFolder -Force
Copy-Item -Path "e:\Geoxal\Doc\SERVER_INSTALLATION_GUIDE.md" -Destination $distFolder -Force

$distDb = Join-Path $distFolder "database"
New-Item -ItemType Directory -Path $distDb -Force | Out-Null
Copy-Item -Path "e:\Geoxal\database\schema_complete.sql" -Destination $distDb -Force

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   PACKAGE CLIENT PRÊT POUR DISTRIBUTION !                " -ForegroundColor Green
Write-Host "   Dossier : $distFolder                                  " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
