# Guide d'Installation Serveur Client — Geoxal ERP

Ce guide décrit la procédure pas-à-pas pour installer le serveur de base de données et configurer l'application Geoxal ERP chez un nouveau client.

---

## 📋 Prérequis Serveur (Windows)

Avant de lancer le script d'installation automatique, assurez-vous d'avoir installé sur le serveur client :

1. **Firebird 2.5 Server (64-bit ou 32-bit)** :
   - Fichier recommandé : `Firebird-2.5.9.27149_0_x64.exe` (ou version 2.5.x).
   - Pendant l'installation :
     - Type d'installation : **SuperClassic** ou **Classic** (ou SuperServer).
     - Cocher : **« Exécuter en tant que service »** (Run as a Service).
     - Cocher : **« Démarrer Firebird automatiquement au démarrage »**.
     - Cocher : **« Copier la bibliothèque cliente Firebird dans le dossier <system> »** (`fbclient.dll`).
     - Mot de passe SYSDBA par défaut : `masterkey`.

2. **Pilote Firebird ODBC Driver** :
   - Fichier recommandé : `Firebird_ODBC_2.0.5.156_x64.exe` (ou version 32-bit selon l'OS / runtime).
   - Installation standard en conservant les options par défaut.

---

## 🚀 Étape 1 : Copier les Fichiers sur le Serveur

Copiez le dossier de l'application Geoxal ou le dossier contenant les fichiers de déploiement sur le serveur client (par exemple dans `C:\Geoxal` ou `D:\Geoxal`) :

```text
Geoxal/
├── database/
│   └── schema_complete.sql     <-- Définition complète des tables & seed
├── setup_server.ps1            <-- Script d'installation PowerShell
├── setup_server.bat            <-- Lanceur automatique 1-clic
└── geoxal.exe (ou build/)      <-- Application cliente Geoxal
```

---

## ⚡ Étape 2 : Lancer l'Installation Automatique (1 Clic)

1. Faites un clic droit sur [setup_server.bat](file:///e:/Geoxal/setup_server.bat) et choisissez **« Exécuter en tant qu'administrateur »**.
2. Le script exécute automatiquement les opérations suivantes :
   - Détecte l'emplacement du moteur Firebird (`isql.exe` et `fbclient.dll`).
   - Crée le dossier cible (par défaut `F:\Geoxal Project` ou le dossier spécifié).
   - Initialise le fichier de base de données `GEOXAL.FDB` avec encodage `WIN1251` et `PAGE_SIZE 8192`.
   - Exécute [database/schema_complete.sql](file:///e:/Geoxal/database/schema_complete.sql) :
     - Crée toutes les tables (`USERS`, `COMPTES`, `MOVEMENTS_TRISOIR`, `TIERS`, `FACTURE_VENTE`, `FACTURE_ACHAT`, `JOURNAL_SUPPRESSION`, etc.).
     - Crée le compte Administrateur par défaut.
     - Crée l'arbre hiérarchique officiel du plan comptable (Caisse principale, Banque, Charges, Achats/Ventes).
   - Configure automatiquement le **DSN ODBC nommé `GEOXAL`** dans le registre Windows.

---

## ⚙️ Étape 3 (Optionnelle) : Personnaliser l'Emplacement de la Base de Données

Si vous souhaitez stocker la base de données sur un autre disque ou dossier (par exemple `D:\Data\GEOXAL.FDB`) :

Ouvrez PowerShell en tant qu'administrateur et tapez :

```powershell
powershell -ExecutionPolicy Bypass -File .\setup_server.ps1 -DbPath "D:\Data\GEOXAL.FDB"
```

---

## 🔑 Étape 4 : Connexion Initiale à l'Application

Lancez l'application Geoxal (`geoxal.exe`) :

- **Nom d'utilisateur** : `admin`
- **Mot de passe** : `admin@1234`

Une fois connecté en tant qu'administrateur :
1. Accédez à l'écran **Gestion des Utilisateurs** pour :
   - Créer les comptes utilisateurs standard.
   - Attribuer les caisses autorisées.
   - Configurer les permissions :
     - *Créer / Modifier / Supprimer des mouvements*
     - *Consulter le Journal des suppressions*
     - *Voir l'ancien solde (Solde initial / report)*
     - *Gestion complète des comptes ou consultation seule du plan comptable*
2. Vous pouvez changer le mot de passe de l'administrateur à tout moment dans ce même écran.

---

## 🛡️ Vérifications et Dépannage Rapide

- **Le service Firebird est-il démarré ?**  
  Vérifiez dans `services.msc` que le service **Firebird Server** est bien en statut *En cours d'exécution*.
- **Le DSN ODBC est-il visible ?**  
  Ouvrez l'Administrateur de sources de données ODBC Windows (`odbcad32.exe`), onglet **DSN Utilisateur** ou **DSN Système** : la source `GEOXAL` doit être présente et pointer vers votre fichier `.FDB`.
- **Pare-feu Windows (si les postes clients se connectent à distance au serveur)** :  
  Ouvrez le port **3050 TCP** (port standard de Firebird) dans le Pare-feu Windows du serveur.
