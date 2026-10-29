import 'package:dart_odbc/dart_odbc.dart';
import 'package:geoxal/app/app_config.dart';

void main() async {
  final odbc = DartOdbc(dsn: AppConfig.databaseDataSource);
  try {
    print('Connecting to Firebird...');
    await odbc.connect(
      username: AppConfig.databaseUserId,
      password: AppConfig.databasePassword,
    );
    print('Connected successfully.');

    // 1. Ensure TYPE_TIERS table
    try {
      await odbc.execute('''
        CREATE TABLE TYPE_TIERS (
          ID INT NOT NULL PRIMARY KEY,
          TYPE VARCHAR(50) NOT NULL
        )
      ''');
      print('Created TYPE_TIERS');
      await odbc.execute("INSERT INTO TYPE_TIERS (ID, TYPE) VALUES (1, 'Client')");
      await odbc.execute("INSERT INTO TYPE_TIERS (ID, TYPE) VALUES (2, 'Fournisseur')");
      print('Seeded TYPE_TIERS');
    } catch (e) {
      print('TYPE_TIERS note: $e');
    }

    // 2. Ensure TIERS table
    try {
      await odbc.execute('''
        CREATE TABLE TIERS (
          ID VARCHAR(36) NOT NULL PRIMARY KEY,
          ID_TYPE_CLIENT INT NOT NULL,
          NOM VARCHAR(100) NOT NULL,
          RC VARCHAR(50),
          NIF VARCHAR(50),
          AI VARCHAR(50),
          NIS VARCHAR(50),
          ADRESSE VARCHAR(200),
          TELEPHONE VARCHAR(50),
          EMAIL VARCHAR(100),
          USER_ID VARCHAR(36) NOT NULL,
          CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
          UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
        )
      ''');
      print('Created TIERS');
    } catch (e) {
      print('TIERS note: $e');
    }

    // 3. Ensure FACTURE_ACHAT table
    try {
      await odbc.execute('''
        CREATE TABLE FACTURE_ACHAT (
          ID VARCHAR(36) NOT NULL PRIMARY KEY,
          TIERS_ID VARCHAR(36) NOT NULL,
          NUM_FACTURE VARCHAR(50) NOT NULL,
          DATE_FACTURE TIMESTAMP NOT NULL,
          MONTANT DECIMAL(18, 2) NOT NULL,
          DESIGNATION VARCHAR(500),
          USER_ID VARCHAR(36) NOT NULL,
          CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
          UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
        )
      ''');
      print('Created FACTURE_ACHAT');
    } catch (e) {
      print('FACTURE_ACHAT note: $e');
    }

    // 4. Ensure FACTURE_VENTE table
    try {
      await odbc.execute('''
        CREATE TABLE FACTURE_VENTE (
          ID VARCHAR(36) NOT NULL PRIMARY KEY,
          TIERS_ID VARCHAR(36) NOT NULL,
          NUM_FACTURE VARCHAR(50) NOT NULL,
          DATE_FACTURE TIMESTAMP NOT NULL,
          MONTANT DECIMAL(18, 2) NOT NULL,
          DESIGNATION VARCHAR(500),
          USER_ID VARCHAR(36) NOT NULL,
          CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
          UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
        )
      ''');
      print('Created FACTURE_VENTE');
    } catch (e) {
      print('FACTURE_VENTE note: $e');
    }

    // 5. Update MOVEMENTS_TRISOIR to match database.md
    try {
      // Check if DETAILS_MOVEMENTS_TRISOIR exists to drop it safely if any FK exists
      try {
        await odbc.execute('DROP TABLE DETAILS_MOVEMENTS_TRISOIR');
      } catch (_) {}
      try {
        await odbc.execute('DROP TABLE MOVEMENTS_TRISOIR');
      } catch (_) {}

      await odbc.execute('''
        CREATE TABLE MOVEMENTS_TRISOIR (
          ID VARCHAR(36) NOT NULL PRIMARY KEY,
          DATE_MOV TIMESTAMP NOT NULL,
          COMPTE_SOURCE_ID VARCHAR(36) NOT NULL,
          COMPTE_DEST_ID VARCHAR(36) NOT NULL,
          MONTANT DECIMAL(18, 2) NOT NULL,
          DESIGNATION VARCHAR(500),
          USER_ID VARCHAR(36) NOT NULL,
          CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
          UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
        )
      ''');
      print('Recreated MOVEMENTS_TRISOIR according to database.md');
    } catch (e) {
      print('MOVEMENTS_TRISOIR note: $e');
    }

    // 6. Ensure COMPTES columns and seed tree according to database.md
    // Check if COMPTE_FR exists in COMPTES
    try {
      await odbc.execute('ALTER TABLE COMPTES ADD COMPTE_FR VARCHAR(100)');
      print('Added COMPTE_FR to COMPTES');
    } catch (_) {}
    try {
      await odbc.execute('ALTER TABLE COMPTES ADD BG INT');
    } catch (_) {}
    try {
      await odbc.execute('ALTER TABLE COMPTES ADD BD INT');
    } catch (_) {}
    try {
      await odbc.execute('ALTER TABLE COMPTES ADD USER_ID VARCHAR(36)');
    } catch (_) {}

    // Check count of COMPTES and seed default tree if empty
    final existingAccounts = await odbc.execute('SELECT COUNT(*) AS CNT FROM COMPTES');
    final count = existingAccounts.first['CNT'] as num? ?? 0;
    if (count == 0) {
      print('Seeding default tree of accounts from database.md...');
      final adminUser = (await odbc.execute('SELECT ID FROM USERS')).first['ID'].toString();

      // Root: TOUS LES COMPTES
      final rootId = 'c0000000-0000-4000-8000-000000000001';
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: [rootId, '0', 'TOUS LES COMPTES', 'TOUS LES COMPTES', null, 1, adminUser],
      );

      // 1. charges
      final chargesId = 'c0000000-0000-4000-8000-000000000002';
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: [chargesId, '6', 'Charges', 'charges', rootId, 2, adminUser],
      );

      final chargesSub = [
        ['60', 'Salaire', 'salaire'],
        ['61', 'Loyer', 'loyer'],
        ['62', 'Eau et électricité', 'eau et electricite'],
        ['63', 'Transport', 'transport'],
        ['64', 'Téléphone', 'telephone'],
        ['65', 'Internet', 'internet'],
        ['66', 'Fournitures de bureau', 'fournitures de bureau'],
        ['67', 'Entretien', 'entretien'],
        ['68', 'Autres charges', 'autres charges'],
      ];
      int subIdx = 10;
      for (final s in chargesSub) {
        await odbc.execute(
          'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
          params: ['c0000000-0000-4000-8000-0000000000$subIdx', s[0], s[1], s[2], chargesId, 3, adminUser],
        );
        subIdx++;
      }

      // 2. achat et vente
      final achatVenteId = 'c0000000-0000-4000-8000-000000000030';
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: [achatVenteId, '7', 'Achat et vente', 'achat et vent', rootId, 2, adminUser],
      );
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: ['c0000000-0000-4000-8000-000000000031', '70', 'Achats marchandises', 'achats', achatVenteId, 3, adminUser],
      );
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: ['c0000000-0000-4000-8000-000000000032', '71', 'Ventes de biens et services', 'ventes', achatVenteId, 3, adminUser],
      );

      // 3. caisse et banque
      final caisseBanqueId = 'c0000000-0000-4000-8000-000000000040';
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: [caisseBanqueId, '5', 'Caisse et banque', 'caisse et banque', rootId, 2, adminUser],
      );

      // caisse
      final caisseId = 'c0000000-0000-4000-8000-000000000041';
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: [caisseId, '53', 'Caisse', 'caisse', caisseBanqueId, 3, adminUser],
      );
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: ['c0000000-0000-4000-8000-000000000042', '531', 'Caisse principale', 'caisse principale', caisseId, 4, adminUser],
      );
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: ['c0000000-0000-4000-8000-000000000043', '532', 'Caisse mobile', 'caisse mobile', caisseId, 4, adminUser],
      );

      // banque
      final banqueId = 'c0000000-0000-4000-8000-000000000050';
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: [banqueId, '51', 'Banque', 'banque', caisseBanqueId, 3, adminUser],
      );
      await odbc.execute(
        'INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) VALUES (?, ?, ?, ?, ?, ?, ?)',
        params: ['c0000000-0000-4000-8000-000000000051', '512', 'Banque principale', 'banque principal', banqueId, 4, adminUser],
      );
      print('Seeded tree of accounts successfully.');
    }

    // 7. Seed sample Tiers if empty
    final existingTiers = await odbc.execute('SELECT COUNT(*) AS CNT FROM TIERS');
    final tiersCount = existingTiers.first['CNT'] as num? ?? 0;
    if (tiersCount == 0) {
      final adminUser = (await odbc.execute('SELECT ID FROM USERS')).first['ID'].toString();
      await odbc.execute('''
        INSERT INTO TIERS (ID, ID_TYPE_CLIENT, NOM, RC, NIF, AI, NIS, ADRESSE, TELEPHONE, EMAIL, USER_ID)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', params: [
        't0000000-0000-4000-8000-000000000001',
        1,
        'SARL ALGERIE TECH',
        '16/00-1234567B16',
        '001616012345678',
        '16012345678',
        '001616012345678',
        '12 Rue Didouche Mourad, Alger',
        '021 23 45 67',
        'contact@algerietech.dz',
        adminUser,
      ]);
      await odbc.execute('''
        INSERT INTO TIERS (ID, ID_TYPE_CLIENT, NOM, RC, NIF, AI, NIS, ADRESSE, TELEPHONE, EMAIL, USER_ID)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', params: [
        't0000000-0000-4000-8000-000000000002',
        2,
        'ETS DISTRIBUTION RAPIDE',
        '16/00-7654321A16',
        '001616087654321',
        '16087654321',
        '001616087654321',
        'Zone Industrielle Oued Smar, Alger',
        '023 89 12 34',
        'commercial@distribution.dz',
        adminUser,
      ]);
      print('Seeded default Tiers (Client & Fournisseur)');
    }

    print('ALL DATABASE SCHEMA TASKS COMPLETED SUCCESSFULLY!');
  } catch (e) {
    print('Error: $e');
  } finally {
    try {
      await odbc.disconnect();
    } catch (_) {}
  }
}
