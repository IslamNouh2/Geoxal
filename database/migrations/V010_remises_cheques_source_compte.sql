-- Migration V010: Add SOURCE_COMPTE_ID column to REMISES_CHEQUES
-- Allows specifying the source account (Compte Recette / Vente d'origine) distinctly from the destination bank account

ALTER TABLE REMISES_CHEQUES ADD SOURCE_COMPTE_ID VARCHAR(36);

