import '../../../core/database/database.dart';
import '../../../core/utils/format.dart';
import '../../data/models/facture_vente.dart';

class VenteDataSource {
  final Database db;

  VenteDataSource(this.db);

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

  Future<List<FactureVente>> getFacturesVente({
    DateTime? from,
    DateTime? to,
    String? tiersId,
    String? searchQuery,
  }) async {
    _ensureConnected();

    final conditions = <String>[];
    if (from != null) {
      conditions.add("FV.DATE_FACTURE >= '${toSqlDateTime(from)}'");
    }
    if (to != null) {
      conditions.add("FV.DATE_FACTURE <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'");
    }
    if (tiersId != null && tiersId.isNotEmpty) {
      conditions.add("FV.TIERS_ID = '$tiersId'");
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().replaceAll("'", "''");
      conditions.add("(FV.NUM_FACTURE LIKE '%$q%' OR FV.DESIGNATION LIKE '%$q%' OR T.NOM LIKE '%$q%')");
    }

    final whereSql = conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}';
    final query = '''
      SELECT FV.ID, FV.TIERS_ID, FV.NUM_FACTURE, FV.DATE_FACTURE, FV.MONTANT,
             FV.DESIGNATION, FV.USER_ID, FV.CREATED_AT, FV.UPDATED_AT,
             T.NOM AS CLIENT_NOM, T.TELEPHONE AS CLIENT_TEL, T.EMAIL AS CLIENT_EMAIL
      FROM FACTURE_VENTE FV
      LEFT JOIN TIERS T ON T.ID = FV.TIERS_ID
      $whereSql
      ORDER BY FV.DATE_FACTURE DESC, FV.NUM_FACTURE DESC
    ''';

    final rows = await db.connection.connection!.execute(query);

    return rows.map((r) {
      return FactureVente(
        id: r['ID'].toString().trim(),
        tiersId: r['TIERS_ID'].toString().trim(),
        numFacture: r['NUM_FACTURE'].toString().trim(),
        dateFacture: _parseDate(r['DATE_FACTURE']),
        montant: double.tryParse(r['MONTANT']?.toString().trim() ?? '0') ?? 0.0,
        designation: r['DESIGNATION']?.toString().trim(),
        userId: r['USER_ID']?.toString().trim() ?? 'SYSTEM',
        createdAt: r['CREATED_AT'] == null ? null : _parseDate(r['CREATED_AT']),
        updatedAt: r['UPDATED_AT'] == null ? null : _parseDate(r['UPDATED_AT']),
        clientNom: r['CLIENT_NOM']?.toString().trim(),
        clientTelephone: r['CLIENT_TEL']?.toString().trim(),
        clientEmail: r['CLIENT_EMAIL']?.toString().trim(),
      );
    }).toList();
  }

  Future<void> createFactureVente(FactureVente fv) async {
    _ensureConnected();
    final numFacture = fv.numFacture.replaceAll("'", "''");
    final dateStr = toSqlDateTime(fv.dateFacture);
    final designation = (fv.designation ?? '').replaceAll("'", "''");
    final userId = fv.userId.isEmpty ? 'SYSTEM' : fv.userId;

    final query = '''
      INSERT INTO FACTURE_VENTE
      (ID, TIERS_ID, NUM_FACTURE, DATE_FACTURE, MONTANT, DESIGNATION, USER_ID)
      VALUES
      ('${fv.id}', '${fv.tiersId}', '$numFacture', '$dateStr', ${fv.montant}, '$designation', '$userId')
    ''';

    await db.connection.connection!.execute(query);
  }

  Future<String> generateNextNumFacture() async {
    _ensureConnected();
    final now = DateTime.now();
    final year = now.year;
    final prefix = 'FV-$year-';

    final query = "SELECT COUNT(*) AS CNT FROM FACTURE_VENTE WHERE NUM_FACTURE LIKE '$prefix%'";
    final rows = await db.connection.connection!.execute(query);
    final count = int.tryParse(rows.first['CNT']?.toString().trim() ?? '0') ?? 0;
    final nextNumber = (count + 1).toString().padLeft(4, '0');
    return '$prefix$nextNumber';
  }
}
