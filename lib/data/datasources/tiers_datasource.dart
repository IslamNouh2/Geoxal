import '../../../core/database/database.dart';
import '../../data/models/tiers.dart';

class TiersDataSource {
  final Database db;

  TiersDataSource(this.db);

  void _ensureConnected() {
    if (!db.connection.isConnected) {
      throw Exception('Database not connected.');
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final s = value.toString().trim();
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  Future<List<Tiers>> getTiers({int? typeId}) async {
    _ensureConnected();

    var query = '''
      SELECT T.ID, T.ID_TYPE_CLIENT, T.NOM, T.RC, T.NIF, T.AI, T.NIS,
             T.ADRESSE, T.TELEPHONE, T.EMAIL, T.USER_ID, T.CREATED_AT,
             TT.TYPE AS TYPE_LIBELLE
      FROM TIERS T
      LEFT JOIN TYPE_TIERS TT ON TT.ID = T.ID_TYPE_CLIENT
    ''';

    if (typeId != null) {
      query += ' WHERE T.ID_TYPE_CLIENT = $typeId';
    }

    query += ' ORDER BY T.NOM ASC';

    final rows = await db.connection.connection!.execute(query);

    return rows.map((r) {
      return Tiers(
        id: r['ID'].toString().trim(),
        idTypeClient: int.tryParse(r['ID_TYPE_CLIENT']?.toString().trim() ?? '1') ?? 1,
        nom: r['NOM']?.toString().trim() ?? '',
        rc: r['RC']?.toString().trim(),
        nif: r['NIF']?.toString().trim(),
        ai: r['AI']?.toString().trim(),
        nis: r['NIS']?.toString().trim(),
        adresse: r['ADRESSE']?.toString().trim(),
        telephone: r['TELEPHONE']?.toString().trim(),
        email: r['EMAIL']?.toString().trim(),
        userId: r['USER_ID']?.toString().trim(),
        createdAt: r['CREATED_AT'] == null ? null : _parseDate(r['CREATED_AT']),
        typeLibelle: r['TYPE_LIBELLE']?.toString().trim(),
      );
    }).toList();
  }

  Future<void> createTiers(Tiers tiers) async {
    _ensureConnected();
    final nom = tiers.nom.replaceAll("'", "''");
    final rc = (tiers.rc ?? '').replaceAll("'", "''");
    final nif = (tiers.nif ?? '').replaceAll("'", "''");
    final ai = (tiers.ai ?? '').replaceAll("'", "''");
    final nis = (tiers.nis ?? '').replaceAll("'", "''");
    final adresse = (tiers.adresse ?? '').replaceAll("'", "''");
    final telephone = (tiers.telephone ?? '').replaceAll("'", "''");
    final email = (tiers.email ?? '').replaceAll("'", "''");
    final userId = tiers.userId ?? 'SYSTEM';

    final query = '''
      INSERT INTO TIERS
      (ID, ID_TYPE_CLIENT, NOM, RC, NIF, AI, NIS, ADRESSE, TELEPHONE, EMAIL, USER_ID)
      VALUES
      ('${tiers.id}', ${tiers.idTypeClient}, '$nom', '$rc', '$nif', '$ai', '$nis', '$adresse', '$telephone', '$email', '$userId')
    ''';

    await db.connection.connection!.execute(query);
  }

  Future<void> updateTiers(Tiers tiers) async {
    _ensureConnected();
    final nom = tiers.nom.replaceAll("'", "''");
    final rc = (tiers.rc ?? '').replaceAll("'", "''");
    final nif = (tiers.nif ?? '').replaceAll("'", "''");
    final ai = (tiers.ai ?? '').replaceAll("'", "''");
    final nis = (tiers.nis ?? '').replaceAll("'", "''");
    final adresse = (tiers.adresse ?? '').replaceAll("'", "''");
    final telephone = (tiers.telephone ?? '').replaceAll("'", "''");
    final email = (tiers.email ?? '').replaceAll("'", "''");

    final query = '''
      UPDATE TIERS SET
        ID_TYPE_CLIENT = ${tiers.idTypeClient},
        NOM = '$nom',
        RC = '$rc',
        NIF = '$nif',
        AI = '$ai',
        NIS = '$nis',
        ADRESSE = '$adresse',
        TELEPHONE = '$telephone',
        EMAIL = '$email',
        UPDATED_AT = CURRENT_TIMESTAMP
      WHERE ID = '${tiers.id}'
    ''';

    await db.connection.connection!.execute(query);
  }
}
