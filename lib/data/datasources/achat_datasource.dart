import '../../../core/database/database.dart';
import '../../../core/utils/format.dart';
import '../../data/models/facture_achat.dart';

class AchatDataSource {
  final Database db;

  AchatDataSource(this.db);

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

  Future<List<FactureAchat>> getFacturesAchat({
    DateTime? from,
    DateTime? to,
    String? tiersId,
    String? searchQuery,
  }) async {
    _ensureConnected();

    final conditions = <String>[];
    if (from != null) {
      conditions.add("FA.DATE_FACTURE >= '${toSqlDateTime(from)}'");
    }
    if (to != null) {
      conditions.add("FA.DATE_FACTURE <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'");
    }
    if (tiersId != null && tiersId.isNotEmpty) {
      conditions.add("FA.TIERS_ID = '$tiersId'");
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().replaceAll("'", "''");
      conditions.add("(FA.NUM_FACTURE LIKE '%$q%' OR FA.DESIGNATION LIKE '%$q%' OR T.NOM LIKE '%$q%')");
    }

    final whereSql = conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}';
    final query = '''
      SELECT FA.ID, FA.TIERS_ID, FA.NUM_FACTURE, FA.DATE_FACTURE, FA.MONTANT,
             FA.DESIGNATION, FA.USER_ID, FA.CREATED_AT, FA.UPDATED_AT,
             T.NOM AS FOURNISSEUR_NOM, T.TELEPHONE AS FOURNISSEUR_TEL, T.EMAIL AS FOURNISSEUR_EMAIL
      FROM FACTURE_ACHAT FA
      LEFT JOIN TIERS T ON T.ID = FA.TIERS_ID
      $whereSql
      ORDER BY FA.DATE_FACTURE DESC, FA.NUM_FACTURE DESC
    ''';

    final rows = await db.connection.connection!.execute(query);

    return rows.map((r) {
      return FactureAchat(
        id: r['ID'].toString().trim(),
        tiersId: r['TIERS_ID'].toString().trim(),
        numFacture: r['NUM_FACTURE'].toString().trim(),
        dateFacture: _parseDate(r['DATE_FACTURE']),
        montant: double.tryParse(r['MONTANT']?.toString().trim() ?? '0') ?? 0.0,
        designation: r['DESIGNATION']?.toString().trim(),
        userId: r['USER_ID']?.toString().trim() ?? 'SYSTEM',
        createdAt: r['CREATED_AT'] == null ? null : _parseDate(r['CREATED_AT']),
        updatedAt: r['UPDATED_AT'] == null ? null : _parseDate(r['UPDATED_AT']),
        fournisseurNom: r['FOURNISSEUR_NOM']?.toString().trim(),
        fournisseurTelephone: r['FOURNISSEUR_TEL']?.toString().trim(),
        fournisseurEmail: r['FOURNISSEUR_EMAIL']?.toString().trim(),
      );
    }).toList();
  }

  Future<void> createFactureAchat(FactureAchat fa) async {
    _ensureConnected();
    final numFacture = fa.numFacture.replaceAll("'", "''");
    final dateStr = toSqlDateTime(fa.dateFacture);
    final designation = (fa.designation ?? '').replaceAll("'", "''");
    final userId = fa.userId.isEmpty ? 'SYSTEM' : fa.userId;

    final query = '''
      INSERT INTO FACTURE_ACHAT
      (ID, TIERS_ID, NUM_FACTURE, DATE_FACTURE, MONTANT, DESIGNATION, USER_ID)
      VALUES
      ('${fa.id}', '${fa.tiersId}', '$numFacture', '$dateStr', ${fa.montant}, '$designation', '$userId')
    ''';

    await db.connection.connection!.execute(query);
  }

  Future<String> generateNextNumFacture() async {
    _ensureConnected();
    final now = DateTime.now();
    final year = now.year;
    final prefix = 'FA-$year-';

    final query = "SELECT COUNT(*) AS CNT FROM FACTURE_ACHAT WHERE NUM_FACTURE LIKE '$prefix%'";
    final rows = await db.connection.connection!.execute(query);
    final count = int.tryParse(rows.first['CNT']?.toString().trim() ?? '0') ?? 0;
    final nextNumber = (count + 1).toString().padLeft(4, '0');
    return '$prefix$nextNumber';
  }
}
