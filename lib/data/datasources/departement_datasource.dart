import '../../../core/database/database.dart';
import '../../../core/utils/uuid.dart';
import '../models/departement.dart';

class DepartementDataSource {
  final Database db;

  DepartementDataSource(this.db);

  void _ensureConnected() {
    if (!db.connection.isConnected) {
      throw Exception('Database not connected.');
    }
  }

  Future<List<Departement>> getDepartements({bool onlyActive = false}) async {
    _ensureConnected();
    final where = onlyActive ? "WHERE IS_ACTIVE = 'O'" : "";
    final query = "SELECT ID, CODE, NOM, DESCRIPTION, IS_ACTIVE, CREATED_AT FROM DEPARTEMENT $where ORDER BY CODE";
    final rows = await db.connection.connection!.execute(query);
    return rows.map((r) => Departement.fromMap(r)).toList();
  }

  Future<void> createDepartement({
    required String code,
    required String nom,
    String? description,
    bool isActive = true,
  }) async {
    _ensureConnected();
    final id = Uuid.v4();
    final cleanCode = code.trim().replaceAll("'", "''");
    final cleanNom = nom.trim().replaceAll("'", "''");
    final cleanDesc = (description ?? '').trim().replaceAll("'", "''");
    final activeChar = isActive ? 'O' : 'N';

    final query = '''
      INSERT INTO DEPARTEMENT (ID, CODE, NOM, DESCRIPTION, IS_ACTIVE)
      VALUES ('$id', '$cleanCode', '$cleanNom', '$cleanDesc', '$activeChar')
    ''';
    await db.connection.connection!.execute(query);
  }

  Future<void> updateDepartement({
    required String id,
    required String code,
    required String nom,
    String? description,
    bool isActive = true,
  }) async {
    _ensureConnected();
    final cleanCode = code.trim().replaceAll("'", "''");
    final cleanNom = nom.trim().replaceAll("'", "''");
    final cleanDesc = (description ?? '').trim().replaceAll("'", "''");
    final activeChar = isActive ? 'O' : 'N';

    final query = '''
      UPDATE DEPARTEMENT 
      SET CODE = '$cleanCode', NOM = '$cleanNom', DESCRIPTION = '$cleanDesc', IS_ACTIVE = '$activeChar'
      WHERE ID = '$id'
    ''';
    await db.connection.connection!.execute(query);
  }

  Future<void> deleteDepartement(String id) async {
    _ensureConnected();
    final query = "DELETE FROM DEPARTEMENT WHERE ID = '$id'";
    await db.connection.connection!.execute(query);
  }
}

