import '../../../core/database/database.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/uuid.dart';
import '../models/charge.dart';
import '../models/compte.dart';
import '../datasources/charges_data_source.dart';

class ChargesRepository {
  final ChargesDataSource _dataSource;
  final Database _db;

  ChargesRepository(this._dataSource, this._db);

  void _ensureConnected() {
    if (!_db.connection.isConnected) {
      throw Exception('Database not connected.');
    }
  }

  // ============================================================
  // CHARGES CRUD
  // ============================================================

  Future<List<Charge>> getCharges({
    String? compteId,
    String? categorie,
    DateTime? dateDebut,
    DateTime? dateFin,
    bool? reglee,
    String? searchQuery,
  }) async {
    final rows = await _dataSource.getCharges(
      compteId: compteId,
      categorie: categorie,
      dateDebut: dateDebut,
      dateFin: dateFin,
      reglee: reglee,
    );

    var list = rows.map((r) => Charge.fromMap(r)).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((c) {
        return c.referance.toLowerCase().contains(q) ||
            c.designation.toLowerCase().contains(q) ||
            (c.compteLibelle?.toLowerCase().contains(q) ?? false) ||
            (c.compteCode?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return list;
  }

  Future<Charge?> getChargeById(String chargeId) async {
    final row = await _dataSource.getChargeById(chargeId);
    if (row == null) return null;
    return Charge.fromMap(row);
  }

  Future<String> generateNextRefCharge() async {
    _ensureConnected();
    final year = DateTime.now().year;
    final prefix = 'CHG-$year-';
    final query =
        "SELECT COUNT(*) AS CNT FROM CHARGES WHERE REF_CHARGE LIKE '$prefix%'";
    final rows = await _db.connection.connection!.execute(query);
    final count =
        int.tryParse(rows.first['CNT']?.toString().trim() ?? '0') ?? 0;
    return '$prefix${(count + 1).toString().padLeft(4, '0')}';
  }

  Future<void> createCharge(Charge charge) async {
    final map = <String, dynamic>{
      'ID_CHARGE': charge.id,
      'USER_ID': charge.userId,
      'REF_CHARGE': charge.referance,
      'DATE_CHARGE': charge.dateCharge,
      'COMPTE_ID': charge.compteId,
      'CATEGORIE_CHARGE': charge.categorie.toDbValue(),
      'CURRENCY_CODE': charge.currencyCode,
      'TAUX_CHANGE': charge.tauxChange ?? 1.0,
      'OK_AMORTISSABLE': charge.amortissable ? 'O' : 'N',
      'MONTANT_CHARGE': charge.montantCharge,
      'MONTANT_REGLE': charge.montantRegle,
      'DESIGNATION': charge.designation,
      'OBSERVATION': charge.observation,
      if (charge.categorie == CategorieCharge.simple) ...{
        'DATE_DEBUT_CONSOMMATION': charge.dateDebutConsommation,
        'DATE_FIN_CONSOMMATION': charge.dateFinConsommation,
      } else ...{
        'DATE_DEBUT_AMORTISSEMENT':
            charge.dateDebutAmortissement ?? charge.dateCreation,
        'DATE_FIN_AMORTISSEMENT': charge.dateFinAmortissement,
      },
    };

    await _dataSource.createCharge(map);
  }

  Future<void> updateCharge(Charge charge) async {
    final map = <String, dynamic>{
      'REF_CHARGE': charge.referance,
      'DATE_CHARGE': charge.dateCharge,
      'COMPTE_ID': charge.compteId,
      'CATEGORIE_CHARGE': charge.categorie.toDbValue(),
      'CURRENCY_CODE': charge.currencyCode,
      'TAUX_CHANGE': charge.tauxChange ?? 1.0,
      'OK_AMORTISSABLE': charge.amortissable ? 'O' : 'N',
      'MONTANT_CHARGE': charge.montantCharge,
      'DESIGNATION': charge.designation,
      'OBSERVATION': charge.observation,
      if (charge.categorie == CategorieCharge.simple) ...{
        'DATE_DEBUT_CONSOMMATION': charge.dateDebutConsommation,
        'DATE_FIN_CONSOMMATION': charge.dateFinConsommation,
        'DATE_DEBUT_AMORTISSEMENT': null,
        'DATE_FIN_AMORTISSEMENT': null,
      } else ...{
        'DATE_DEBUT_AMORTISSEMENT':
            charge.dateDebutAmortissement ?? charge.dateCreation,
        'DATE_FIN_AMORTISSEMENT': charge.dateFinAmortissement,
        'DATE_DEBUT_CONSOMMATION': null,
        'DATE_FIN_CONSOMMATION': null,
      },
    };

    await _dataSource.updateCharge(chargeId: charge.id, data: map);
  }

  Future<void> deleteCharge(String chargeId) async {
    _ensureConnected();
    await _dataSource.deleteCharge(chargeId);
  }

  /// Returns the MOVEMENTS_TRISOIR ID linked to this charge via DETAIL_MVT_CHARGES,
  /// but only if that movement was auto-created from trésorerie (OBSERVATION matches).
  Future<String?> getAutoLinkedMovementId(String chargeId) async {
    _ensureConnected();
    final sql = '''
      SELECT D.ID_MVT_TRESOR
      FROM DETAIL_MVT_CHARGES D
      JOIN CHARGES C ON C.ID_CHARGE = D.ID_CHARGE
      WHERE D.ID_CHARGE = '$chargeId'
        AND C.OBSERVATION = 'Créée automatiquement depuis Trésorerie'
      ROWS 1
    ''';
    final rows = await _db.connection.connection!.execute(sql);
    if (rows.isEmpty) return null;
    return rows.first['ID_MVT_TRESOR']?.toString().trim();
  }

  /// Returns the auto-charge ID linked to a trésorerie movement, if any.
  Future<({String chargeId, String detailId})?> getAutoChargeForMovement(String mvtId) async {
    _ensureConnected();
    final sql = '''
      SELECT D.ID_DETAIL_MVT_CHARGE, D.ID_CHARGE
      FROM DETAIL_MVT_CHARGES D
      JOIN CHARGES C ON C.ID_CHARGE = D.ID_CHARGE
      WHERE D.ID_MVT_TRESOR = '$mvtId'
        AND C.OBSERVATION = 'Créée automatiquement depuis Trésorerie'
      ROWS 1
    ''';
    final rows = await _db.connection.connection!.execute(sql);
    if (rows.isEmpty) return null;
    return (
      chargeId: rows.first['ID_CHARGE']?.toString().trim() ?? '',
      detailId: rows.first['ID_DETAIL_MVT_CHARGE']?.toString().trim() ?? '',
    );
  }

  /// Deletes the DETAIL_MVT_CHARGES row for a given movement + charge.
  Future<void> deleteDetailMvtCharge(String detailId) async {
    _ensureConnected();
    await _db.connection.connection!.execute(
      "DELETE FROM DETAIL_MVT_CHARGES WHERE ID_DETAIL_MVT_CHARGE = '$detailId'",
    );
  }

  /// Deletes a movement from MOVEMENTS_TRISOIR (used for cascade from charges).
  Future<void> deleteMovement(String mvtId) async {
    _ensureConnected();
    await _db.connection.connection!.execute(
      "DELETE FROM MOVEMENTS_TRISOIR WHERE ID = '$mvtId'",
    );
  }

  // ============================================================
  // ACCOUNTS (Nested Set Model for Expense Subtree & Payment Treasuries)
  // ============================================================

  /// Returns only leaf active expense accounts under the 60 Charges subtree.
  Future<List<Compte>> getExpenseAccounts() async {
    _ensureConnected();
    final query = '''
      SELECT ID, CODE, LIBELLE, COMPTE_FR, NIVEAU, BG, BD, IS_ACTIVE, USER_ID, TYPE_COMPTE, IS_DEVISE, CODE_DEVISE
      FROM COMPTES
      WHERE (TYPE_COMPTE = 'Dأ©pense' OR TYPE_COMPTE = 'depense' OR CODE LIKE '6%')
        AND (BD - BG = 1)
        AND (IS_ACTIVE IS NULL OR IS_ACTIVE = 'O' OR IS_ACTIVE = '1')
      ORDER BY CODE ASC
    ''';
    final rows = await _db.connection.connection!.execute(query);
    return rows
        .map(
          (r) => Compte(
            id: r['ID'].toString().trim(),
            code: r['CODE'].toString().trim(),
            libelle: r['LIBELLE'].toString().trim(),
            compteFr: r['COMPTE_FR']?.toString().trim(),
            niveau: int.tryParse(r['NIVEAU']?.toString().trim() ?? '1') ?? 1,
            bg: int.tryParse(r['BG']?.toString().trim() ?? '0') ?? 0,
            bd: int.tryParse(r['BD']?.toString().trim() ?? '1') ?? 1,
            active: true,
            typeCompte: CompteType.fromString(r['TYPE_COMPTE']?.toString()),
          ),
        )
        .toList();
  }

  /// Returns available payment treasury accounts (Caisses and Banques).
  Future<List<Compte>> getTreasuryPaymentAccounts() async {
    _ensureConnected();
    final query = '''
      SELECT ID, CODE, LIBELLE, COMPTE_FR, NIVEAU, BG, BD, IS_ACTIVE, USER_ID, TYPE_COMPTE, IS_DEVISE, CODE_DEVISE
      FROM COMPTES
      WHERE (LOWER(TYPE_COMPTE) LIKE '%caisse%' OR LOWER(TYPE_COMPTE) LIKE '%banque%')
        AND (BD - BG = 1)
        AND (IS_ACTIVE IS NULL OR IS_ACTIVE = 'O' OR IS_ACTIVE = '1')
      ORDER BY CODE ASC
    ''';
    final rows = await _db.connection.connection!.execute(query);
    return rows
        .map(
          (r) => Compte(
            id: r['ID'].toString().trim(),
            code: r['CODE'].toString().trim(),
            libelle: r['LIBELLE'].toString().trim(),
            compteFr: r['COMPTE_FR']?.toString().trim(),
            niveau: int.tryParse(r['NIVEAU']?.toString().trim() ?? '1') ?? 1,
            bg: int.tryParse(r['BG']?.toString().trim() ?? '0') ?? 0,
            bd: int.tryParse(r['BD']?.toString().trim() ?? '1') ?? 1,
            active: true,
            typeCompte: CompteType.fromString(r['TYPE_COMPTE']?.toString()),
          ),
        )
        .toList();
  }

  // ============================================================
  // CHARGE PAYMENTS (Integration with MOVEMENTS_TRISOIR and DETAIL_MVT_CHARGES)
  // ============================================================

  /// Fetches payment tranches associated with a charge.
  Future<List<Map<String, dynamic>>> getChargePaymentDetails(
    String chargeId,
  ) async {
    _ensureConnected();
    final query =
        '''
      SELECT 
        D.ID_DETAIL_MVT_CHARGE, D.ID_MVT_TRESOR, D.TRANCHE_MONTANT, D.ID_CHARGE, D.DATE_CREAT,
        M.DATE_MOV, M.DESIGNATION, M.MODE_PAIEMENT, M.NUM_CHEQUE,
        C_SRC.CODE AS CAISSE_CODE, C_SRC.LIBELLE AS CAISSE_LIBELLE
      FROM DETAIL_MVT_CHARGES D
      JOIN MOVEMENTS_TRISOIR M ON M.ID = D.ID_MVT_TRESOR
      LEFT JOIN COMPTES C_SRC ON C_SRC.ID = M.COMPTE_SOURCE_ID
      WHERE D.ID_CHARGE = '$chargeId'
      ORDER BY D.DATE_CREAT DESC
    ''';
    final rows = await _db.connection.connection!.execute(query);
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  /// Adds a payment for a charge inside a single database transaction.
  ///
  /// - Source account = Treasury account (caisse/banque where money leaves)
  /// - Destination account = Charge expense account (COMPTES)
  /// - Creates MOVEMENTS_TRISOIR entry with ORIGINE_MODULE = 'CHARGE'
  /// - Creates DETAIL_MVT_CHARGES entry
  /// - Firebird trigger TRG_DMC_AI automatically updates CHARGES.MONTANT_REGLE and validates that total paid does not exceed MONTANT_CHARGE.
  Future<void> addPayment({
    required Charge charge,
    required String sourceCaisseId,
    required double montant,
    required DateTime datePaiement,
    required String modePaiement,
    String? numCheque,
    DateTime? dateCheque,
    String? observation,
    required String userId,
  }) async {
    _ensureConnected();
    if (montant <= 0) {
      throw ArgumentError('Le montant du paiement doit أھtre supأ©rieur أ  0.');
    }
    if (montant > charge.resteARegler + 0.001) {
      throw ArgumentError(
        'Le montant dأ©passe le reste أ  rأ©gler (${charge.resteARegler.toStringAsFixed(2)} DZD).',
      );
    }

    final mvtId = Uuid.v4();
    final detailId = Uuid.v4();
    final now = DateTime.now();

    final dateMovSql = toSqlDateTime(datePaiement);
    final numChequeSql = (numCheque != null && numCheque.trim().isNotEmpty)
        ? "'${numCheque.trim().replaceAll("'", "''")}'"
        : 'NULL';
    final dateChequeSql = dateCheque != null
        ? "'${toSqlDateTime(dateCheque)}'"
        : 'NULL';

    final obsLabel = (observation != null && observation.trim().isNotEmpty)
        ? ' - ${observation.trim()}'
        : '';
    final designation =
        'Rأ¨glement charge ${charge.referance} (${charge.designation})$obsLabel'
            .replaceAll("'", "''");

    // 1. Insert Movement in MOVEMENTS_TRISOIR
    final insertMovSql =
        '''
      INSERT INTO MOVEMENTS_TRISOIR (
        ID, DATE_MOV, COMPTE_SOURCE_ID, COMPTE_DEST_ID, MONTANT, DESIGNATION, USER_ID,
        MODE_PAIEMENT, NUM_CHEQUE, DATE_CHEQUE, ORIGINE_MODULE
      ) VALUES (
        '$mvtId', '$dateMovSql', '$sourceCaisseId', '${charge.compteId}', $montant,
        '$designation', '$userId', '$modePaiement', $numChequeSql, $dateChequeSql, 'CHARGE'
      )
    ''';

    // 2. Insert Detail in DETAIL_MVT_CHARGES
    final insertDetailSql =
        '''
      INSERT INTO DETAIL_MVT_CHARGES (
        ID_DETAIL_MVT_CHARGE, ID_MVT_TRESOR, TRANCHE_MONTANT, ID_CHARGE, DATE_CREAT
      ) VALUES (
        '$detailId', '$mvtId', $montant, '${charge.id}', '${toSqlDateTime(now)}'
      )
    ''';

    await _db.connection.connection!.execute(insertMovSql);
    await _db.connection.connection!.execute(insertDetailSql);
  }
}



