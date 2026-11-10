import '../../../core/database/database.dart';
import '../../../core/services/invoice_number_service.dart';
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
      conditions.add(
        "FV.DATE_FACTURE <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'",
      );
    }
    if (tiersId != null && tiersId.isNotEmpty) {
      conditions.add("FV.TIERS_ID = '$tiersId'");
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().replaceAll("'", "''");
      conditions.add(
        "(FV.NUM_FACTURE LIKE '%$q%' OR FV.DESIGNATION LIKE '%$q%' OR T.NOM LIKE '%$q%')",
      );
    }

    final whereSql = conditions.isEmpty
        ? ''
        : ' WHERE ${conditions.join(' AND ')}';
    final query =
        '''
      SELECT FV.ID, FV.TIERS_ID, FV.NUM_FACTURE, FV.DATE_FACTURE, FV.MONTANT,
             FV.DESIGNATION, FV.USER_ID, FV.CREATED_AT, FV.UPDATED_AT,
             FV.DEPARTEMENT_ID, FV.COMPTE_ID, FV.MODE_PAIEMENT,
             T.NOM AS CLIENT_NOM, T.TELEPHONE AS CLIENT_TEL, T.EMAIL AS CLIENT_EMAIL,
             D.NOM AS DEPARTEMENT_NOM, C.LIBELLE AS COMPTE_LIBELLE,
             COALESCE((
               SELECT SUM(RF.MONTANT_APPLIQUE)
               FROM REGLEMENT_FACTURE RF
               WHERE RF.FACTURE_ID = FV.ID AND RF.FACTURE_TYPE = 'VENTE'
             ), 0.0) AS MONTANT_REGLE
      FROM FACTURE_VENTE FV
      LEFT JOIN TIERS T ON T.ID = FV.TIERS_ID
      LEFT JOIN DEPARTEMENT D ON D.ID = FV.DEPARTEMENT_ID
      LEFT JOIN COMPTES C ON C.ID = FV.COMPTE_ID
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
        departementId: r['DEPARTEMENT_ID']?.toString().trim(),
        compteId: r['COMPTE_ID']?.toString().trim(),
        modePaiement: r['MODE_PAIEMENT']?.toString().trim(),
        clientNom: r['CLIENT_NOM']?.toString().trim(),
        clientTelephone: r['CLIENT_TEL']?.toString().trim(),
        clientEmail: r['CLIENT_EMAIL']?.toString().trim(),
        departementNom: r['DEPARTEMENT_NOM']?.toString().trim(),
        compteLibelle: r['COMPTE_LIBELLE']?.toString().trim(),
        montantRegle:
            double.tryParse(r['MONTANT_REGLE']?.toString().trim() ?? '0') ??
            0.0,
      );
    }).toList();
  }

  Future<void> createFactureVente(FactureVente fv) async {
    _ensureConnected();
    final numFacture = fv.numFacture.replaceAll("'", "''");
    final dateStr = toSqlDateTime(fv.dateFacture);
    final designation = (fv.designation ?? '').replaceAll("'", "''");
    final userId = fv.userId.isEmpty ? 'SYSTEM' : fv.userId;
    final depIdSql = (fv.departementId != null && fv.departementId!.isNotEmpty)
        ? "'${fv.departementId}'"
        : "NULL";
    final compteIdSql = (fv.compteId != null && fv.compteId!.isNotEmpty)
        ? "'${fv.compteId}'"
        : "NULL";
    final modePaiementSql =
        (fv.modePaiement != null && fv.modePaiement!.isNotEmpty)
        ? "'${fv.modePaiement!.replaceAll("'", "''")}'"
        : "NULL";

    final query =
        '''
      INSERT INTO FACTURE_VENTE
      (ID, TIERS_ID, NUM_FACTURE, DATE_FACTURE, MONTANT, DESIGNATION, USER_ID, DEPARTEMENT_ID, COMPTE_ID, MODE_PAIEMENT)
      VALUES
      ('${fv.id}', '${fv.tiersId}', '$numFacture', '$dateStr', ${fv.montant}, '$designation', '$userId', $depIdSql, $compteIdSql, $modePaiementSql)
    ''';

    await db.connection.connection!.execute(query);
  }

  /// Reads the format pattern from APP_SETTINGS (VENTE_NUM_FORMAT) and generates
  /// the next sequential invoice number using [InvoiceNumberService].
  Future<String> generateNextNumFacture() async {
    _ensureConnected();

    // Load format from settings (fallback to default if not set)
    const defaultFormat = 'FV{YY}/{NNNN}';
    String format = defaultFormat;
    try {
      final fmtRows = await db.connection.connection!.execute(
        "SELECT SETTING_VALUE FROM APP_SETTINGS WHERE SETTING_KEY = 'VENTE_NUM_FORMAT'",
      );
      if (fmtRows.isNotEmpty) {
        final val = fmtRows.first['SETTING_VALUE']?.toString().trim() ?? '';
        if (val.isNotEmpty) format = val;
      }
    } catch (_) {
      format = defaultFormat;
    }

    return InvoiceNumberService.generateNext(
      formatPattern: format,
      countByPrefix: (prefix) async {
        final safePrefix = prefix.replaceAll("'", "''");
        final rows = await db.connection.connection!.execute(
          "SELECT COUNT(*) AS CNT FROM FACTURE_VENTE WHERE NUM_FACTURE LIKE '$safePrefix%'",
        );
        return int.tryParse(rows.first['CNT']?.toString().trim() ?? '0') ?? 0;
      },
    );
  }
}
