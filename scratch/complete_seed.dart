import 'package:dart_odbc/dart_odbc.dart';
import 'package:geoxal/app/app_config.dart';

void main() async {
  final odbc = DartOdbc(dsn: AppConfig.databaseDataSource);
  try {
    await odbc.connect(
      username: AppConfig.databaseUserId,
      password: AppConfig.databasePassword,
    );
    final users = await odbc.execute('SELECT ID FROM USERS');
    final adminUser = users.first['ID'].toString();

    // Check which accounts are missing from database.md
    final list = [
      // charges
      ['c0000000-0000-4000-8000-000000000012', '62', 'Eau et electricite', 'eau et electricite', 'c0000000-0000-4000-8000-000000000002', 3],
      ['c0000000-0000-4000-8000-000000000013', '63', 'Transport', 'transport', 'c0000000-0000-4000-8000-000000000002', 3],
      ['c0000000-0000-4000-8000-000000000014', '64', 'Telephone', 'telephone', 'c0000000-0000-4000-8000-000000000002', 3],
      ['c0000000-0000-4000-8000-000000000015', '65', 'Internet', 'internet', 'c0000000-0000-4000-8000-000000000002', 3],
      ['c0000000-0000-4000-8000-000000000016', '66', 'Fournitures de bureau', 'fournitures de bureau', 'c0000000-0000-4000-8000-000000000002', 3],
      ['c0000000-0000-4000-8000-000000000017', '67', 'Entretien', 'entretien', 'c0000000-0000-4000-8000-000000000002', 3],
      ['c0000000-0000-4000-8000-000000000018', '68', 'Autres charges', 'autres charges', 'c0000000-0000-4000-8000-000000000002', 3],

      // achat et vente
      ['c0000000-0000-4000-8000-000000000030', '7', 'Achat et vente', 'achat et vent', 'c0000000-0000-4000-8000-000000000001', 2],
      ['c0000000-0000-4000-8000-000000000031', '70', 'Achats', 'achats', 'c0000000-0000-4000-8000-000000000030', 3],
      ['c0000000-0000-4000-8000-000000000032', '71', 'Ventes', 'ventes', 'c0000000-0000-4000-8000-000000000030', 3],

      // caisse et banque
      ['c0000000-0000-4000-8000-000000000040', '5', 'Caisse et banque', 'caisse et banque', 'c0000000-0000-4000-8000-000000000001', 2],
      ['c0000000-0000-4000-8000-000000000041', '53', 'Caisse', 'caisse', 'c0000000-0000-4000-8000-000000000040', 3],
      ['c0000000-0000-4000-8000-000000000042', '531', 'Caisse principale', 'caisse principale', 'c0000000-0000-4000-8000-000000000041', 4],
      ['c0000000-0000-4000-8000-000000000043', '532', 'Caisse mobile', 'caisse mobile', 'c0000000-0000-4000-8000-000000000041', 4],
      ['c0000000-0000-4000-8000-000000000050', '51', 'Banque', 'banque', 'c0000000-0000-4000-8000-000000000040', 3],
      ['c0000000-0000-4000-8000-000000000051', '512', 'Banque principale', 'banque principal', 'c0000000-0000-4000-8000-000000000050', 4],
    ];

    for (final item in list) {
      try {
        await odbc.execute(
          "INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, PARENT_ID, NIVEAU, USER_ID) "
          "VALUES ('${item[0]}', '${item[1]}', '${item[2]}', '${item[3]}', '${item[4]}', ${item[5]}, '$adminUser')",
        );
        print('Inserted ${item[1]} - ${item[2]}');
      } catch (e) {
        print('Skip/Error ${item[1]}: $e');
      }
    }

    // Also seed Tiers
    try {
      await odbc.execute('''
        INSERT INTO TIERS (ID, ID_TYPE_CLIENT, NOM, RC, NIF, AI, NIS, ADRESSE, TELEPHONE, EMAIL, USER_ID)
        VALUES ('t0000000-0000-4000-8000-000000000001', 1, 'SARL ALGERIE TECH', '16/00-1234567B16', '001616012345678', '16012345678', '001616012345678', '12 Rue Didouche Mourad, Alger', '021 23 45 67', 'contact@algerietech.dz', '$adminUser')
      ''');
      print('Inserted Client SARL ALGERIE TECH');
    } catch (_) {}

    try {
      await odbc.execute('''
        INSERT INTO TIERS (ID, ID_TYPE_CLIENT, NOM, RC, NIF, AI, NIS, ADRESSE, TELEPHONE, EMAIL, USER_ID)
        VALUES ('t0000000-0000-4000-8000-000000000002', 2, 'ETS DISTRIBUTION RAPIDE', '16/00-7654321A16', '001616087654321', '16087654321', '001616087654321', 'Zone Industrielle Oued Smar, Alger', '023 89 12 34', 'commercial@distribution.dz', '$adminUser')
      ''');
      print('Inserted Fournisseur ETS DISTRIBUTION RAPIDE');
    } catch (_) {}

    print('DONE!');
  } catch (e) {
    print('Fatal: $e');
  } finally {
    try {
      await odbc.disconnect();
    } catch (_) {}
  }
}
