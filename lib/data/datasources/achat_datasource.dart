import '../../../core/database/database.dart';
import '../../../core/services/invoice_number_service.dart';
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
      SELECT FA.ID, FA.TIERS_ID, FA.NUM_FACTURE, FA.NUM_FACTURE_FOURNISSEUR,
             FA.DATE_FACTURE, FA.MONTANT,
             FA.DESIGNATION, FA.USER_ID, FA.CREATED_AT, FA.UPDATED_AT,
             FA.DEPARTEMENT_ID, FA.COMPTE_ID, FA.MODE_PAIEMENT, FA.TYPE_ACHAT,
             T.NOM AS FOURNISSEUR_NOM, T.TELEPHONE AS FOURNISSEUR_TEL, T.EMAIL AS FOURNISSEUR_EMAIL,
             D.NOM AS DEPARTEMENT_NOM, C.LIBELLE AS COMPTE_LIBELLE,
             COALESCE((
               SELECT SUM(RF.MONTANT_APPLIQUE)
               FROM REGLEMENT_FACTURE RF
               WHERE RF.FACTURE_ID = FA.ID AND RF.FACTURE_TYPE = 'ACHAT'
             ), 0.0) AS MONTANT_REGLE
      FROM FACTURE_ACHAT FA
      LEFT JOIN TIERS T ON T.ID = FA.TIERS_ID
      LEFT JOIN DEPARTEMENT D ON D.ID = FA.DEPARTEMENT_ID
      LEFT JOIN COMPTES C ON C.ID = FA.COMPTE_ID
      $whereSql
      ORDER BY FA.DATE_FACTURE DESC, FA.NUM_FACTURE DESC
    ''';

    final rows = await db.connection.connection!.execute(query);

    return rows.map((r) {
      return FactureAchat(
        id: r['ID'].toString().trim(),
        tiersId: r['TIERS_ID'].toString().trim(),
        numFacture: r['NUM_FACTURE'].toString().trim(),
        numFactureFournisseur: r['NUM_FACTURE_FOURNISSEUR']?.toString().trim(),
        dateFacture: _parseDate(r['DATE_FACTURE']),
        montant: double.tryParse(r['MONTANT']?.toString().trim() ?? '0') ?? 0.0,
        designation: r['DESIGNATION']?.toString().trim(),
        userId: r['USER_ID']?.toString().trim() ?? 'SYSTEM',
        createdAt: r['CREATED_AT'] == null ? null : _parseDate(r['CREATED_AT']),
        updatedAt: r['UPDATED_AT'] == null ? null : _parseDate(r['UPDATED_AT']),
        departementId: r['DEPARTEMENT_ID']?.toString().trim(),
        compteId: r['COMPTE_ID']?.toString().trim(),
        modePaiement: r['MODE_PAIEMENT']?.toString().trim(),
        typeAchat: r['TYPE_ACHAT']?.toString().trim() ?? 'ACHAT',
        fournisseurNom: r['FOURNISSEUR_NOM']?.toString().trim(),
        fournisseurTelephone: r['FOURNISSEUR_TEL']?.toString().trim(),
        fournisseurEmail: r['FOURNISSEUR_EMAIL']?.toString().trim(),
        departementNom: r['DEPARTEMENT_NOM']?.toString().trim(),
        compteLibelle: r['COMPTE_LIBELLE']?.toString().trim(),
        montantRegle: double.tryParse(r['MONTANT_REGLE']?.toString().trim() ?? '0') ?? 0.0,
      );
    }).toList();
  }

  Future<void> createFactureAchat(FactureAchat fa) async {
    _ensureConnected();
    final numFacture = fa.numFacture.replaceAll("'", "''");
    final numFournisseurSql = (fa.numFactureFournisseur != null && fa.numFactureFournisseur!.isNotEmpty)
        ? "'${fa.numFactureFournisseur!.replaceAll("'", "''")}'"
        : 'NULL';
    final dateStr = toSqlDateTime(fa.dateFacture);
    final designation = (fa.designation ?? '').replaceAll("'", "''");
    final userId = fa.userId.isEmpty ? 'SYSTEM' : fa.userId;
    final depIdSql = (fa.departementId != null && fa.departementId!.isNotEmpty) ? "'${fa.departementId}'" : "NULL";
    final compteIdSql = (fa.compteId != null && fa.compteId!.isNotEmpty) ? "'${fa.compteId}'" : "NULL";
    final modePaiementSql = (fa.modePaiement != null && fa.modePaiement!.isNotEmpty) ? "'${fa.modePaiement!.replaceAll("'", "''")}'" : "NULL";
    final typeAchatSql = fa.typeAchat.replaceAll("'", "''");

    final query = '''
      INSERT INTO FACTURE_ACHAT
      (ID, TIERS_ID, NUM_FACTURE, NUM_FACTURE_FOURNISSEUR, DATE_FACTURE, MONTANT, DESIGNATION, USER_ID, DEPARTEMENT_ID, COMPTE_ID, MODE_PAIEMENT, TYPE_ACHAT)
      VALUES
      ('${fa.id}', '${fa.tiersId}', '$numFacture', $numFournisseurSql, '$dateStr', ${fa.montant}, '$designation', '$userId', $depIdSql, $compteIdSql, $modePaiementSql, '$typeAchatSql')
    ''';

    await db.connection.connection!.execute(query);
  }

  /// Reads the format pattern from APP_SETTINGS (ACHAT_NUM_FORMAT) and generates
  /// the next sequential invoice number using [InvoiceNumberService].
  Future<String> generateNextNumFacture() async {
    _ensureConnected();

    // Load format from settings (fallback to default if not set)
    const defaultFormat = 'FA{YY}/{NNNN}';
    String format = defaultFormat;
    try {
      final fmtRows = await db.connection.connection!.execute(
        "SELECT SETTING_VALUE FROM APP_SETTINGS WHERE SETTING_KEY = 'ACHAT_NUM_FORMAT'",
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
          "SELECT COUNT(*) AS CNT FROM FACTURE_ACHAT WHERE NUM_FACTURE LIKE '$safePrefix%'",
        );
        return int.tryParse(rows.first['CNT']?.toString().trim() ?? '0') ?? 0;
      },
    );
  }
}
