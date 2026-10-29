# 📒 Compte & Finance Module

This module manages the **Chart of Accounts (Plan Comptable)** and **Treasury Movements (Mouvements de Trésorerie)** for the Geoxal application, backed by a Firebird database over ODBC.

---

## 🗂️ Directory Structure

```
lib/
├── data/
│   ├── models/
│   │   ├── compte.dart          # Compte model + CompteType enum + NSM helpers
│   │   └── movement.dart        # Movement model + FinanceStats
│   ├── datasources/
│   │   └── finance_datasource.dart   # Raw SQL queries against Firebird
│   └── repositories/
│       └── finance_repository.dart   # Business-logic layer wrapping datasource
│
└── features/
    └── accounting/
        ├── controllers/
        │   └── accounting_controller.dart   # UI-facing controller
        ├── pages/
        │   ├── accounts_page.dart           # Chart of accounts tree UI
        │   └── accounting_page.dart         # Movements / journal UI
        └── widgets/
            ├── new_account_dialog.dart      # Create-account dialog
            ├── new_movement_dialog.dart     # Create-movement dialog
            ├── account_tree_picker.dart     # Reusable account selector popup
            ├── account_tree_panel.dart      # Inline account tree panel
            └── select_caisse_dialog.dart    # Quick caisse/banque selector
```

---

## 🌳 Nested Set Model (NSM) — How the Account Tree Works

Accounts are stored using the **Nested Set Model** instead of a simple `parent_id` foreign key. This allows efficient subtree queries with a single SQL `WHERE` clause.

### Fields

| Field    | Type    | Description                                    |
|----------|---------|------------------------------------------------|
| `ID`     | VARCHAR | Unique UUID identifier                         |
| `BG`     | INTEGER | Borne Gauche — left boundary of the node       |
| `BD`     | INTEGER | Borne Droite — right boundary of the node      |
| `NIVEAU` | INTEGER | Depth level in the tree (root = 1)             |

### Key Rules

```
A is an ANCESTOR of B    →  A.BG < B.BG  AND  A.BD > B.BD
A is DIRECT PARENT of B  →  isAncestorOf(B) AND B.NIVEAU == A.NIVEAU + 1
A is a LEAF node         →  BD - BG == 1   (no children)
A is a PARENT node       →  BD - BG > 1    (has children)
```

### Example Tree

```
Bilan (BG=1, BD=20, NIVEAU=1)
├── Caisse et Banque (BG=2, BD=9, NIVEAU=2)
│   ├── Banque (BG=3, BD=6, NIVEAU=3)
│   │   └── CCP (BG=4, BD=5, NIVEAU=4)
│   └── Caisse (BG=7, BD=8, NIVEAU=3)
└── Charges (BG=10, BD=19, NIVEAU=2)
    └── Achats (BG=11, BD=18, NIVEAU=3)
        └── Achat matières (BG=12, BD=13, NIVEAU=4)
```

### Inserting a New Account

When inserting a child under a parent with `BD = parentBd`:
1. All nodes with `BD >= parentBd` have their `BD` shifted `+2`
2. All nodes with `BG >= parentBd` have their `BG` shifted `+2`
3. New leaf is inserted with `BG = parentBd`, `BD = parentBd + 1`

### Deleting an Account

1. Record `width = BD - BG + 1`
2. Delete the node (or subtree if `deleteSubtree = true`)
3. All nodes with `BD > deleted.BD` shift `BD - width`
4. All nodes with `BG > deleted.BD` shift `BG - width`

### Moving a Subtree

1. Mark the moving subtree with **negative** BG/BD (to protect from gap shifts)
2. Close the old gap (`-width`)
3. Open new gap at the target position (`+width`)
4. Restore the marked subtree to the new position and update `NIVEAU`

---

## 🏷️ CompteType — Account Classification

Every account has an **effective type** used to classify treasury movements.

### Enum Values

| Value            | Label             | Badge Color |
|------------------|-------------------|-------------|
| `caisse`         | Caisse            | 🟢 Green    |
| `banque`         | Banque            | 🔵 Blue     |
| `recette`        | Recette           | 🟣 Purple   |
| `depense`        | Dépense           | 🔴 Red      |
| `recetteDepense` | Recette / Dépense | 🟡 Amber    |

### Type Resolution (`resolveEffectiveType`)

The effective type is determined in this priority order:

1. **Explicit DB value**: If `TYPE_COMPTE` is set → use it directly.
2. **NSM ancestor check** (in order):
   - Inside `Charges` (code `6`) → `depense`
   - Inside `Caisse` (code `53`) → `caisse`
   - Inside `Banque` (code `51`) → `banque`
   - Inside `Caisse et Banque` (code `5`) → `caisse` or `banque` by name
   - Inside `Achat et Vente` (code `7`) → `depense` (achat) / `recette` (vente)
3. **Name fallback**: Matches keywords in `libelle` (`caisse`, `banque`, `vente`…)
4. **Default**: `depense`

> **Sub-accounts under `Charges` are automatically classified as `Dépense`** — no manual type needed.

---

## 🗄️ Database Schema

### Table: `COMPTES`

```sql
CREATE TABLE COMPTES (
  ID          VARCHAR(36)  NOT NULL PRIMARY KEY,
  CODE        VARCHAR(20)  NOT NULL,
  LIBELLE     VARCHAR(200) NOT NULL,
  COMPTE_FR   VARCHAR(200),
  NIVEAU      INTEGER      DEFAULT 1,
  BG          INTEGER      NOT NULL,
  BD          INTEGER      NOT NULL,
  IS_ACTIVE   CHAR(1)      DEFAULT 'O',   -- 'O' = actif, 'N' = inactif
  USER_ID     VARCHAR(36),
  TYPE_COMPTE VARCHAR(30)
  -- TYPE_COMPTE values: 'caisse' | 'banque' | 'recette' | 'depense' | 'recette_depense'
);
```

### Table: `MOVEMENTS_TRISOIR`

```sql
CREATE TABLE MOVEMENTS_TRISOIR (
  ID               VARCHAR(36)    NOT NULL PRIMARY KEY,
  DATE_MOV         TIMESTAMP      NOT NULL,
  COMPTE_SOURCE_ID VARCHAR(36)    NOT NULL REFERENCES COMPTES(ID),
  COMPTE_DEST_ID   VARCHAR(36)    NOT NULL REFERENCES COMPTES(ID),
  MONTANT          NUMERIC(15, 2) NOT NULL,
  DESIGNATION      VARCHAR(500),
  USER_ID          VARCHAR(36)
);
```

### Table: `JOURNAL_SUPPRESSION`

Audit log recording every deleted movement before removal:

```sql
CREATE TABLE JOURNAL_SUPPRESSION (
  ID               VARCHAR(36)    NOT NULL PRIMARY KEY,
  DATE_SUPPRESSION TIMESTAMP      NOT NULL,
  USER_SUPPRESSION VARCHAR(36),
  MOV_ID           VARCHAR(36)    NOT NULL,
  MOV_DATE         TIMESTAMP      NOT NULL,
  MOV_MONTANT      NUMERIC(15, 2) NOT NULL,
  MOV_DESIGNATION  VARCHAR(500),
  MOV_SOURCE_ID    VARCHAR(36),
  MOV_DEST_ID      VARCHAR(36),
  MOV_SOURCE_CODE  VARCHAR(50),
  MOV_SOURCE_LIB   VARCHAR(200),
  MOV_DEST_CODE    VARCHAR(50),
  MOV_DEST_LIB     VARCHAR(200)
);
```

> **Business rule**: An account that appears in `MOVEMENTS_TRISOIR` **cannot have sub-accounts added to it**.

---

## 🔄 Data Flow

```
AccountsPage / AccountingPage
        │
        ▼
AccountingController          ← UI layer, delegates only
        │
        ▼
FinanceRepository             ← Business logic, UUID generation
        │
        ▼
FinanceDataSource             ← Raw SQL, NSM shift operations
        │
        ▼
  Firebird Database (ODBC)
```

---

## 🧩 Key Methods Reference

### `FinanceDataSource`

| Method | Description |
|---|---|
| `getAccounts()` | Load all accounts ordered by `BG` |
| `createAccount(compte, parentBg, parentBd)` | NSM-aware insert with tree shift |
| `updateAccount(compte)` | Update fields (not position) |
| `deleteAccount(id, deleteSubtree)` | Delete leaf or subtree, close NSM gap |
| `moveAccount(id, targetParentId)` | Relocate subtree, recalculate BG/BD/NIVEAU |
| `getAncestors(id)` | All ancestors root → direct parent |
| `getDescendants(id)` | Entire subtree under an account |
| `getDirectChildren(id)` | Immediate children (NIVEAU + 1) only |
| `canDeleteAccount(id)` | `false` if account has children or movements |
| `getMovements(...)` | Movements with optional account/date filters |
| `getStats(...)` | Aggregate totals (entrées, sorties, total) |

### `Compte` Model Helpers

| Property / Method | Description |
|---|---|
| `isLeaf` | `true` if `BD - BG == 1` |
| `isParent` | `true` if `BD - BG > 1` |
| `isAncestorOf(other)` | NSM containment: `BG < other.BG && BD > other.BD` |
| `isDirectParentOf(other)` | Ancestor + `other.NIVEAU == NIVEAU + 1` |
| `resolveEffectiveType(allAccounts)` | Infers type from NSM position or explicit value |
| `displayName` | `"code - compteFr"` or `"code - libelle"` |

---

## ⚙️ ODBC / Firebird Setup (Windows)

The app uses a 64-bit Windows build, which requires the **64-bit Firebird client** configured in the ODBC DSN registry:

```powershell
# Set the 64-bit Firebird client path in the DSN registry
Set-ItemProperty `
  -Path "HKCU:\Software\ODBC\ODBC.INI\GEOXAL" `
  -Name "Client" `
  -Value "C:\Program Files\Firebird\Firebird_2_5\bin\fbclient.dll"
```

> ⚠️ **Do NOT** use the 32-bit path (`Program Files (x86)`). In a 64-bit Flutter build it causes a `0xc0000005` access violation crash in `OdbcFb.dll` at login.

---

## 📋 Business Rules Summary

| Rule | Detail |
|---|---|
| Account with movements → no sub-accounts | Enforced in `NewAccountDialog` via `accountIdsWithMovements` |
| Parent account → cannot be deleted directly | `canDeleteAccount()` returns `false` |
| Sub-accounts under `Charges` → auto `Dépense` | Via `resolveEffectiveType()` NSM check |
| Type can be overridden explicitly | Set `TYPE_COMPTE` in DB or via the account creation dialog |
| Tree display order | Sorted by `BG` ascending (NSM natural order = left-to-right) |
| Root accounts | `NIVEAU == 1` (minimum niveau in the table) |
