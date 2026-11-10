-- @statement
-- ============================================================================
-- Migration V012: Permissions CRUD Utilisateurs pour Charges et Remises de Chèques
-- Date: 2026-11-07
-- Description:
--   Ajout des colonnes de droits d'accès détaillés pour:
--   1. Le module Gestion des Charges
--   2. Le module Remises de Chèques
-- ============================================================================
ALTER TABLE USERS ADD CAN_VIEW_CHARGES CHAR(1) DEFAULT 'O';

-- @statement
ALTER TABLE USERS ADD CAN_CREATE_CHARGES CHAR(1) DEFAULT 'O';

-- @statement
ALTER TABLE USERS ADD CAN_UPDATE_CHARGES CHAR(1) DEFAULT 'O';

-- @statement
ALTER TABLE USERS ADD CAN_DELETE_CHARGES CHAR(1) DEFAULT 'N';

-- @statement
ALTER TABLE USERS ADD CAN_VIEW_REMISES CHAR(1) DEFAULT 'O';

-- @statement
ALTER TABLE USERS ADD CAN_CREATE_REMISES CHAR(1) DEFAULT 'O';

-- @statement
ALTER TABLE USERS ADD CAN_UPDATE_REMISES CHAR(1) DEFAULT 'O';

-- @statement
ALTER TABLE USERS ADD CAN_DELETE_REMISES CHAR(1) DEFAULT 'N';

-- @statement
UPDATE USERS
SET
  CAN_VIEW_CHARGES = COALESCE(CAN_VIEW_CHARGES, 'O'),
  CAN_CREATE_CHARGES = COALESCE(CAN_CREATE_CHARGES, 'O'),
  CAN_UPDATE_CHARGES = COALESCE(CAN_UPDATE_CHARGES, 'O'),
  CAN_DELETE_CHARGES = CASE WHEN UPPER(ROLE) = 'ADMIN' THEN 'O' ELSE COALESCE(CAN_DELETE_CHARGES, 'N') END,
  CAN_VIEW_REMISES = COALESCE(CAN_VIEW_REMISES, 'O'),
  CAN_CREATE_REMISES = COALESCE(CAN_CREATE_REMISES, 'O'),
  CAN_UPDATE_REMISES = COALESCE(CAN_UPDATE_REMISES, 'O'),
  CAN_DELETE_REMISES = CASE WHEN UPPER(ROLE) = 'ADMIN' THEN 'O' ELSE COALESCE(CAN_DELETE_REMISES, 'N') END;

-- @statement
INSERT INTO SCHEMA_MIGRATIONS (
    ID,
    VERSION,
    SUCCESS,
    NOTES
)
VALUES (
    12,
    'V012_user_permissions_charges_and_remises',
    'O',
    'Add CRUD user permissions for charges and remises'
);
