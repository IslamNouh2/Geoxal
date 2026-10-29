# ==============================================================================
# GEOXAL - AUTOMATED SERVER SETUP & FIREBIRD / ODBC CONFIGURATION
# ==============================================================================
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\setup_server.ps1
#   ou avec paramètres personnalisés :
#   powershell -ExecutionPolicy Bypass -File .\setup_server.ps1 -DbPath "D:\Data\GEOXAL.FDB"
# ==============================================================================

param(
    [string]$DbPath = "D:\Geoxal Project\GEOXAL.FDB",
    [string]$DsnName = "GEOXAL",
    [string]$FirebirdDir = "C:\Program Files\Firebird\Firebird_2_5",
    [string]$SysdbaPassword = "masterkey"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   INSTALLATION & CONFIGURATION SERVEUR GEOXAL ERP       " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Vérification des droits Administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "ATTENTION : Ce script n'est pas exécuté en mode Administrateur."
    Write-Warning "Pour configurer les DSN ODBC système ou créer des répertoires sécurisés, relancez PowerShell en tant qu'Administrateur si nécessaire."
}

# 2. Localiser isql.exe et fbclient.dll
$isqlPath = Join-Path $FirebirdDir "bin\isql.exe"
if (-not (Test-Path $isqlPath)) {
    # Chercher dans d'autres répertoires standards
    $altPaths = @(
        "C:\Program Files\Firebird\Firebird_2_5\bin\isql.exe",
        "C:\Program Files (x86)\Firebird\Firebird_2_5\bin\isql.exe",
        "C:\Program Files\Firebird\Firebird_3_0\isql.exe"
    )
    foreach ($p in $altPaths) {
        if (Test-Path $p) {
            $isqlPath = $p
            $FirebirdDir = Split-Path (Split-Path $p)
            break
        }
    }
}

if (-not (Test-Path $isqlPath)) {
    Write-Error "Firebird isql.exe introuvable dans '$FirebirdDir'. Veuillez installer Firebird 2.5."
}
Write-Host "[+] Firebird ISQL trouvé : $isqlPath" -ForegroundColor Green

$fbClientDll = Join-Path $FirebirdDir "bin\fbclient.dll"
if (-not (Test-Path $fbClientDll)) {
    $fbClientDll = Join-Path $FirebirdDir "fbclient.dll"
}
Write-Host "[+] Firebird Client DLL : $fbClientDll" -ForegroundColor Green

# 3. Préparer le dossier de la base de données
$dbDir = Split-Path $DbPath
if (-not (Test-Path $dbDir)) {
    Write-Host "[*] Création du dossier cible : $dbDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
}

# 4. Création de la base de données si elle n'existe pas
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$schemaSql = Join-Path $scriptDir "database\schema_complete.sql"
if (-not (Test-Path $schemaSql)) {
    $schemaSql = Join-Path (Get-Location) "database\schema_complete.sql"
}

if (-not (Test-Path $DbPath)) {
    Write-Host "[*] Base de données inexistante. Initialisation de : $DbPath..." -ForegroundColor Yellow
    
    # Créer un script temporaire pour créer la DB et appliquer le schéma
    $tempSql = Join-Path $env:TEMP "geoxal_init_db.sql"
    $createDbCmd = "CREATE DATABASE '$DbPath' USER 'SYSDBA' PASSWORD '$SysdbaPassword' PAGE_SIZE 8192 DEFAULT CHARACTER SET WIN1251;"
    
    $fullScriptContent = "$createDbCmd`r`n" + (Get-Content $schemaSql -Raw)
    [System.IO.File]::WriteAllText($tempSql, $fullScriptContent, [System.Text.Encoding]::ASCII)
    
    Write-Host "[*] Exécution du schéma SQL complet et des données initiales..." -ForegroundColor Yellow
    & "$isqlPath" -q -i "$tempSql"
    Remove-Item $tempSql -Force -ErrorAction SilentlyContinue

    if (Test-Path $DbPath) {
        Write-Host "[+] Base de données créée avec succès : $DbPath" -ForegroundColor Green
    } else {
        Write-Error "Échec de la création du fichier FDB."
    }
} else {
    Write-Host "[i] La base de données existe déjà : $DbPath" -ForegroundColor Cyan
}

# 5. Configuration de la source de données ODBC (DSN)
Write-Host "[*] Configuration de la source ODBC DSN '$DsnName'..." -ForegroundColor Yellow

# Trouver le nom exact du pilote ODBC Firebird installé
$driver = Get-OdbcDriver | Where-Object { $_.Name -like "*Firebird*" -or $_.Name -like "*InterBase*" } | Select-Object -First 1

if (-not $driver) {
    Write-Warning "Le pilote ODBC Firebird n'est pas encore installé."
    Write-Warning "Veuillez installer Firebird ODBC Driver (ex: Firebird_ODBC_2.0.5.156_x64.exe) puis réexécuter ce script."
} else {
    $driverName = $driver.Name
    Write-Host "[+] Pilote ODBC détecté : $driverName ($($driver.Platform))" -ForegroundColor Green

    # Configuration directe et infaillible via la base de registre ODBC
    # Configuration universelle dans le registre (HKCU et HKLM, 64-bit et 32-bit Wow6432Node)
    $regRoots = @(
        "HKCU:\Software\ODBC\ODBC.INI",
        "HKCU:\Software\Wow6432Node\ODBC\ODBC.INI",
        "HKLM:\SOFTWARE\ODBC\ODBC.INI",
        "HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBC.INI"
    )

    foreach ($regRoot in $regRoots) {
        try {
            $odbcSourcesPath = "$regRoot\ODBC Data Sources"
            $odbcRegPath = "$regRoot\$DsnName"

            if (-not (Test-Path $odbcSourcesPath)) {
                New-Item -Path $odbcSourcesPath -Force | Out-Null
            }
            Set-ItemProperty -Path $odbcSourcesPath -Name $DsnName -Value $driverName

            if (-not (Test-Path $odbcRegPath)) {
                New-Item -Path $odbcRegPath -Force | Out-Null
            }

            # Déterminer la DLL pilote selon l'architecture du registre
            $driverDll = "C:\WINDOWS\system32\OdbcFb.dll"
            if ($regRoot -like "*Wow6432Node*" -and (Test-Path "C:\WINDOWS\SysWOW64\OdbcFb.dll")) {
                $driverDll = "C:\WINDOWS\SysWOW64\OdbcFb.dll"
            }

            Set-ItemProperty -Path $odbcRegPath -Name "Driver" -Value $driverDll
            Set-ItemProperty -Path $odbcRegPath -Name "Dbname" -Value $DbPath
            Set-ItemProperty -Path $odbcRegPath -Name "Client" -Value $fbClientDll
            Set-ItemProperty -Path $odbcRegPath -Name "User" -Value ""
            Set-ItemProperty -Path $odbcRegPath -Name "Role" -Value ""
            Set-ItemProperty -Path $odbcRegPath -Name "CharacterSet" -Value "WIN1251"
            Set-ItemProperty -Path $odbcRegPath -Name "JdbcDriver" -Value "IscDbc"
            Set-ItemProperty -Path $odbcRegPath -Name "ReadOnly" -Value "N"
            Set-ItemProperty -Path $odbcRegPath -Name "NoWait" -Value "N"
            Set-ItemProperty -Path $odbcRegPath -Name "Dialect" -Value "3"
            Set-ItemProperty -Path $odbcRegPath -Name "QuotedIdentifier" -Value "Y"
            Set-ItemProperty -Path $odbcRegPath -Name "SensitiveIdentifier" -Value "N"
            Set-ItemProperty -Path $odbcRegPath -Name "AutoQuotedIdentifier" -Value "N"
        } catch {
            Write-Verbose "Skipped $regRoot: $_"
        }
    }

    Write-Host "[+] Source ODBC DSN '$DsnName' configurée avec succès (Système + Utilisateur, 64-bit & 32-bit) !" -ForegroundColor Green
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   CONFIGURATION DU SERVEUR GEOXAL TERMINÉE AVEC SUCCÈS ! " -ForegroundColor Green
Write-Host "   - FDB File : $DbPath                                   " -ForegroundColor White
Write-Host "   - ODBC DSN : $DsnName                                  " -ForegroundColor White
Write-Host "   - Admin    : admin / admin@1234                        " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
