import '../../../core/database/database.dart';
import '../../../core/utils/format.dart';

/// DataSource responsible for CHARGES table operations.
///
/// Firebird 2.5 compatible.
/// Uses direct interpolated SQL consistent with other DataSources (e.g. VenteDataSource, ReglementDataSource)
/// to avoid dart_odbc parameter binding issues with Null values and specific Firebird types.
class ChargesDataSource {
  final Database db;

  ChargesDataSource(this.db);

  dynamic get _connection => db.connection.connection!;

  String _escape(String? value) {
    if (value == null) return '';
    return value.replaceAll("'", "''");
  }

  String _sqlString(String? value) {
    if (value == null || value.trim().isEmpty) return 'NULL';
    return "'${_escape(value.trim())}'";
  }

  String _sqlDate(dynamic value) {
    if (value == null) return 'NULL';
    if (value is DateTime) {
      return "'${toSqlDateOnly(value)}'";
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) {
      return "'${toSqlDateOnly(parsed)}'";
    }
    return 'NULL';
  }

  // ============================================================
  // GET ALL CHARGES
  // ============================================================

  Future<List<Map<String, dynamic>>> getCharges({
    String? compteId,
    String? categorie,
    DateTime? dateDebut,
    DateTime? dateFin,
    bool? reglee,
  }) async {
    final conditions = <String>[];

    if (compteId != null && compteId.isNotEmpty) {
      conditions.add("C.COMPTE_ID = '$compteId'");
    }

    if (categorie != null && categorie.isNotEmpty) {
      conditions.add("C.CATEGORIE_CHARGE = '$categorie'");
    }

    if (dateDebut != null) {
      conditions.add("C.DATE_CHARGE >= '${toSqlDateOnly(dateDebut)}'");
    }

    if (dateFin != null) {
      conditions.add("C.DATE_CHARGE <= '${toSqlDateOnly(dateFin)}'");
    }

    if (reglee == true) {
      conditions.add('C.MONTANT_REGLE >= C.MONTANT_CHARGE');
    } else if (reglee == false) {
      conditions.add('C.MONTANT_REGLE < C.MONTANT_CHARGE');
    }

    final whereClause = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final sql = '''
      SELECT
        C.*,
        CP.CODE AS COMPTE_CODE,
        CP.LIBELLE AS COMPTE_LIBELLE
      FROM CHARGES C
      LEFT JOIN COMPTES CP
        ON CP.ID = C.COMPTE_ID
      $whereClause
      ORDER BY C.DATE_CHARGE DESC, C.DATE_CREAT DESC
    ''';

    final result = await _connection.execute(sql);
    return _mapRows(result);
  }

  // ============================================================
  // GET CHARGE BY ID
  // ============================================================

  Future<Map<String, dynamic>?> getChargeById(String chargeId) async {
    final sql = '''
      SELECT
        C.*,
        CP.CODE AS COMPTE_CODE,
        CP.LIBELLE AS COMPTE_LIBELLE
      FROM CHARGES C
      LEFT JOIN COMPTES CP
        ON CP.ID = C.COMPTE_ID
      WHERE C.ID_CHARGE = '$chargeId'
    ''';

    final result = await _connection.execute(sql);
    final rows = _mapRows(result);
    return rows.isEmpty ? null : rows.first;
  }

  // ============================================================
  // CREATE CHARGE
  // ============================================================

  Future<void> createCharge(Map<String, dynamic> data) async {
    final idCharge = data['ID_CHARGE']?.toString() ?? '';
    final userId = data['USER_ID']?.toString() ?? 'SYSTEM';
    final refCharge = data['REF_CHARGE']?.toString() ?? '';
    final dateCharge = _sqlDate(data['DATE_CHARGE']);
    final compteId = data['COMPTE_ID']?.toString() ?? '';
    final categorie = data['CATEGORIE_CHARGE']?.toString() ?? 'SIMPLE';
    final currency = data['CURRENCY_CODE']?.toString() ?? 'DZD';
    final tauxChange = (data['TAUX_CHANGE'] is num) ? (data['TAUX_CHANGE'] as num).toDouble() : 1.0;
    final okAmort = data['OK_AMORTISSABLE']?.toString() ?? 'N';
    final montantCharge = (data['MONTANT_CHARGE'] is num) ? (data['MONTANT_CHARGE'] as num).toDouble() : 0.0;
    final montantRegle = (data['MONTANT_REGLE'] is num) ? (data['MONTANT_REGLE'] as num).toDouble() : 0.0;
    final designation = data['DESIGNATION']?.toString() ?? '';
    final observation = data['OBSERVATION']?.toString();

    final dateDebutConso = _sqlDate(data['DATE_DEBUT_CONSOMMATION']);
    final dateFinConso = _sqlDate(data['DATE_FIN_CONSOMMATION']);
    final dateDebutAmort = _sqlDate(data['DATE_DEBUT_AMORTISSEMENT']);
    final dateFinAmort = _sqlDate(data['DATE_FIN_AMORTISSEMENT']);
    final idMvtTresor = _sqlString(data['ID_MVT_TRESOR']?.toString());

    final sql = '''
      INSERT INTO CHARGES (
        ID_CHARGE,
        USER_ID,
        REF_CHARGE,
        DATE_CHARGE,
        COMPTE_ID,
        CATEGORIE_CHARGE,
        CURRENCY_CODE,
        TAUX_CHANGE,
        OK_AMORTISSABLE,
        MONTANT_CHARGE,
        MONTANT_REGLE,
        DESIGNATION,
        OBSERVATION,
        DATE_DEBUT_CONSOMMATION,
        DATE_FIN_CONSOMMATION,
        DATE_DEBUT_AMORTISSEMENT,
        DATE_FIN_AMORTISSEMENT,
        ID_MVT_TRESOR
      ) VALUES (
        '${_escape(idCharge)}',
        '${_escape(userId)}',
        '${_escape(refCharge)}',
        $dateCharge,
        '${_escape(compteId)}',
        '${_escape(categorie)}',
        '${_escape(currency)}',
        $tauxChange,
        '${_escape(okAmort)}',
        $montantCharge,
        $montantRegle,
        '${_escape(designation)}',
        ${_sqlString(observation)},
        $dateDebutConso,
        $dateFinConso,
        $dateDebutAmort,
        $dateFinAmort,
        $idMvtTresor
      )
    ''';

    await _connection.execute(sql);
  }

  // ============================================================
  // UPDATE CHARGE
  // ============================================================

  Future<void> updateCharge({
    required String chargeId,
    required Map<String, dynamic> data,
  }) async {
    final sets = <String>[];

    if (data.containsKey('REF_CHARGE')) {
      sets.add("REF_CHARGE = '${_escape(data['REF_CHARGE']?.toString() ?? '')}'");
    }
    if (data.containsKey('DATE_CHARGE')) {
      sets.add("DATE_CHARGE = ${_sqlDate(data['DATE_CHARGE'])}");
    }
    if (data.containsKey('COMPTE_ID')) {
      sets.add("COMPTE_ID = '${_escape(data['COMPTE_ID']?.toString() ?? '')}'");
    }
    if (data.containsKey('CATEGORIE_CHARGE')) {
      sets.add("CATEGORIE_CHARGE = '${_escape(data['CATEGORIE_CHARGE']?.toString() ?? '')}'");
    }
    if (data.containsKey('CURRENCY_CODE')) {
      sets.add("CURRENCY_CODE = '${_escape(data['CURRENCY_CODE']?.toString() ?? 'DZD')}'");
    }
    if (data.containsKey('TAUX_CHANGE')) {
      final rate = (data['TAUX_CHANGE'] is num) ? (data['TAUX_CHANGE'] as num).toDouble() : 1.0;
      sets.add("TAUX_CHANGE = $rate");
    }
    if (data.containsKey('OK_AMORTISSABLE')) {
      sets.add("OK_AMORTISSABLE = '${_escape(data['OK_AMORTISSABLE']?.toString() ?? 'N')}'");
    }
    if (data.containsKey('MONTANT_CHARGE')) {
      final amount = (data['MONTANT_CHARGE'] is num) ? (data['MONTANT_CHARGE'] as num).toDouble() : 0.0;
      sets.add("MONTANT_CHARGE = $amount");
    }
    if (data.containsKey('DESIGNATION')) {
      sets.add("DESIGNATION = '${_escape(data['DESIGNATION']?.toString() ?? '')}'");
    }
    if (data.containsKey('OBSERVATION')) {
      sets.add("OBSERVATION = ${_sqlString(data['OBSERVATION']?.toString())}");
    }
    if (data.containsKey('DATE_DEBUT_CONSOMMATION')) {
      sets.add("DATE_DEBUT_CONSOMMATION = ${_sqlDate(data['DATE_DEBUT_CONSOMMATION'])}");
    }
    if (data.containsKey('DATE_FIN_CONSOMMATION')) {
      sets.add("DATE_FIN_CONSOMMATION = ${_sqlDate(data['DATE_FIN_CONSOMMATION'])}");
    }
    if (data.containsKey('DATE_DEBUT_AMORTISSEMENT')) {
      sets.add("DATE_DEBUT_AMORTISSEMENT = ${_sqlDate(data['DATE_DEBUT_AMORTISSEMENT'])}");
    }
    if (data.containsKey('DATE_FIN_AMORTISSEMENT')) {
      sets.add("DATE_FIN_AMORTISSEMENT = ${_sqlDate(data['DATE_FIN_AMORTISSEMENT'])}");
    }
    if (data.containsKey('ID_MVT_TRESOR')) {
      sets.add("ID_MVT_TRESOR = ${_sqlString(data['ID_MVT_TRESOR']?.toString())}");
    }

    if (sets.isEmpty) return;

    sets.add("DATE_MODIF = CURRENT_TIMESTAMP");

    final sql = '''
      UPDATE CHARGES
      SET ${sets.join(', ')}
      WHERE ID_CHARGE = '$chargeId'
    ''';

    await _connection.execute(sql);
  }

  // ============================================================
  // DELETE CHARGE
  // ============================================================

  Future<void> deleteCharge(String chargeId) async {
    // Delete attached movement details first
    await _connection.execute("DELETE FROM DETAIL_MVT_CHARGES WHERE ID_CHARGE = '$chargeId'");
    // Delete charge
    await _connection.execute("DELETE FROM CHARGES WHERE ID_CHARGE = '$chargeId'");
  }

  // ============================================================
  // GET CHARGE SUMMARY
  // ============================================================

  Future<Map<String, dynamic>> getChargesSummary({
    DateTime? dateDebut,
    DateTime? dateFin,
    String? compteId,
  }) async {
    final conditions = <String>[];

    if (compteId != null && compteId.isNotEmpty) {
      conditions.add("COMPTE_ID = '$compteId'");
    }
    if (dateDebut != null) {
      conditions.add("DATE_CHARGE >= '${toSqlDateOnly(dateDebut)}'");
    }
    if (dateFin != null) {
      conditions.add("DATE_CHARGE <= '${toSqlDateOnly(dateFin)}'");
    }

    final whereClause = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final sql = '''
      SELECT
        COUNT(*) AS TOTAL_COUNT,
        COALESCE(SUM(MONTANT_CHARGE), 0) AS TOTAL_MONTANT,
        COALESCE(SUM(MONTANT_REGLE), 0) AS TOTAL_REGLE,
        COALESCE(SUM(MONTANT_CHARGE - MONTANT_REGLE), 0) AS TOTAL_RESTE,
        COALESCE(
          SUM(CASE WHEN CATEGORIE_CHARGE = 'SIMPLE' THEN MONTANT_CHARGE ELSE 0 END), 0
        ) AS TOTAL_SIMPLE,
        COALESCE(
          SUM(CASE WHEN CATEGORIE_CHARGE = 'AMORTISSABLE' THEN MONTANT_CHARGE ELSE 0 END), 0
        ) AS TOTAL_AMORTISSABLE
      FROM CHARGES
      $whereClause
    ''';

    final result = await _connection.execute(sql);
    final rows = _mapRows(result);
    return rows.isEmpty ? {} : rows.first;
  }

  // ============================================================
  // RESULT MAPPING
  // ============================================================

  List<Map<String, dynamic>> _mapRows(dynamic result) {
    final rows = <Map<String, dynamic>>[];
    for (final row in result) {
      rows.add(Map<String, dynamic>.from(row as Map));
    }
    return rows;
  }
}
