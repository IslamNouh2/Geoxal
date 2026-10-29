import '../../../core/database/database.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/uuid.dart';
import '../models/bank_rule.dart';
import '../models/cheque_remise.dart';
import '../models/compte.dart';

class BankingDataSource {
  final Database db;

  BankingDataSource(this.db);

  void _ensureConnected() {
    if (!db.connection.isConnected) {
      throw Exception('Database not connected.');
    }
  }

  // ==========================================
  // 1. COMPTES BANCAIRES & CHARGES (depuis table COMPTES)
  // ==========================================

  /// Récupère tous les comptes bancaires (type 'banque' ou code '51%') dans COMPTES
  Future<List<Compte>> getBankAccounts() async {
    _ensureConnected();
    final rows = await db.connection.connection!.execute(
      "SELECT ID, CODE, LIBELLE, COMPTE_FR, NIVEAU, BG, BD, IS_ACTIVE, USER_ID, TYPE_COMPTE "
      "FROM COMPTES "
      "WHERE (TYPE_COMPTE = 'banque' OR CODE STARTING WITH '51') AND IS_ACTIVE = 'O' "
      "ORDER BY CODE",
    );
    return rows.map((r) => Compte(
      id: r['ID'].toString(),
      code: r['CODE'].toString().trim(),
      libelle: cleanMojibake(r['LIBELLE'].toString().trim()),
      compteFr: r['COMPTE_FR'] != null ? cleanMojibake(r['COMPTE_FR'].toString().trim()) : null,
      niveau: int.tryParse(r['NIVEAU']?.toString().trim() ?? '1') ?? 1,
      bg: int.tryParse(r['BG']?.toString().trim() ?? '0') ?? 0,
      bd: int.tryParse(r['BD']?.toString().trim() ?? '1') ?? 1,
      active: true,
      userId: r['USER_ID']?.toString().trim(),
      typeCompte: CompteType.banque,
    )).toList();
  }

  /// Récupère les comptes de type 'dépense' (pour commissions et frais)
  Future<List<Compte>> getExpenseAccounts() async {
    _ensureConnected();
    final rows = await db.connection.connection!.execute(
      "SELECT ID, CODE, LIBELLE, COMPTE_FR, NIVEAU, BG, BD, IS_ACTIVE, USER_ID, TYPE_COMPTE "
      "FROM COMPTES "
      "WHERE (TYPE_COMPTE = 'depense' OR TYPE_COMPTE = 'recette_depense' OR CODE STARTING WITH '6') AND IS_ACTIVE = 'O' "
      "ORDER BY CODE",
    );
    return rows.map((r) => Compte(
      id: r['ID'].toString(),
      code: r['CODE'].toString().trim(),
      libelle: cleanMojibake(r['LIBELLE'].toString().trim()),
      compteFr: r['COMPTE_FR'] != null ? cleanMojibake(r['COMPTE_FR'].toString().trim()) : null,
      niveau: int.tryParse(r['NIVEAU']?.toString().trim() ?? '1') ?? 1,
      bg: int.tryParse(r['BG']?.toString().trim() ?? '0') ?? 0,
      bd: int.tryParse(r['BD']?.toString().trim() ?? '1') ?? 1,
      active: true,
      userId: r['USER_ID']?.toString().trim(),
      typeCompte: CompteType.fromString(r['TYPE_COMPTE']?.toString()) ?? CompteType.depense,
    )).toList();
  }

  // ==========================================
  // 2. TRANSACTION TYPES CATALOG
  // ==========================================

  Future<List<TransactionTypeCatalog>> getTransactionTypes() async {
    _ensureConnected();
    final rows = await db.connection.connection!.execute(
      "SELECT ID, CODE, LABEL, ACTIVE FROM TRANSACTION_TYPES WHERE ACTIVE = 'O' ORDER BY LABEL",
    );
    return rows.map((r) => TransactionTypeCatalog.fromMap(r)).toList();
  }

  // ==========================================
  // 3. RÈGLES BANCAIRES (BANK_RULES)
  // ==========================================

  Future<List<BankRule>> getBankRules({String? bankCompteId, String? transactionTypeId, bool? onlyActive}) async {
    _ensureConnected();
    String query = '''
      SELECT 
        br.ID, br.NAME, br.ACTIVE, br.PRIORITY, br.BANK_COMPTE_ID,
        br.TRANSACTION_TYPE_ID, br.CHARGE_COMPTE_ID, br.CALC_METHOD, br.AMOUNT,
        br.PERCENT_VAL, br.MIN_AMOUNT, br.MAX_AMOUNT, br.BASE_TYPE, br.PARENT_RULE_ID,
        br.TAX_COMPTE_ID, br.TAX_RATE_PERCENT, br.ROUNDING_MODE, br.VALID_FROM, br.VALID_TO, br.IS_CUMULATIVE,
        cb.LIBELLE as BANK_LABEL, tt.LABEL as TX_LABEL, cc.LIBELLE as CHARGE_LABEL, ct.LIBELLE as TAX_LABEL
      FROM BANK_RULES br
      LEFT JOIN COMPTES cb ON cb.ID = br.BANK_COMPTE_ID
      LEFT JOIN TRANSACTION_TYPES tt ON tt.ID = br.TRANSACTION_TYPE_ID
      JOIN COMPTES cc ON cc.ID = br.CHARGE_COMPTE_ID
      LEFT JOIN COMPTES ct ON ct.ID = br.TAX_COMPTE_ID
      WHERE 1=1
    ''';

    if (onlyActive == true) {
      query += " AND br.ACTIVE = 'O'";
    }
    if (bankCompteId != null) {
      query += " AND (br.BANK_COMPTE_ID = '$bankCompteId' OR br.BANK_COMPTE_ID IS NULL)";
    }
    if (transactionTypeId != null) {
      query += " AND (br.TRANSACTION_TYPE_ID = '$transactionTypeId' OR br.TRANSACTION_TYPE_ID IS NULL)";
    }

    query += " ORDER BY br.PRIORITY DESC, br.NAME ASC";

    final rows = await db.connection.connection!.execute(query);
    return rows.map((r) => BankRule.fromMap(r)).toList();
  }

  Future<void> saveBankRule(BankRule rule) async {
    _ensureConnected();
    final bankVal = rule.bankCompteId != null ? "'${rule.bankCompteId}'" : "NULL";
    final txTypeVal = rule.transactionTypeId != null ? "'${rule.transactionTypeId}'" : "NULL";
    final parentVal = rule.parentRuleId != null ? "'${rule.parentRuleId}'" : "NULL";
    final taxVal = rule.taxCompteId != null ? "'${rule.taxCompteId}'" : "NULL";
    final validToVal = rule.validTo != null ? "'${toSqlDateTime(rule.validTo!)}'" : "NULL";

    await db.connection.connection!.execute(
      '''
      UPDATE OR INSERT INTO BANK_RULES (
        ID, NAME, ACTIVE, PRIORITY, BANK_COMPTE_ID, TRANSACTION_TYPE_ID,
        CHARGE_COMPTE_ID, CALC_METHOD, AMOUNT, PERCENT_VAL, MIN_AMOUNT, MAX_AMOUNT,
        BASE_TYPE, PARENT_RULE_ID, TAX_COMPTE_ID, TAX_RATE_PERCENT, ROUNDING_MODE, VALID_FROM, VALID_TO, IS_CUMULATIVE
      ) VALUES (
        '${rule.id}', '${rule.name.replaceAll("'", "''")}', '${rule.active ? 'O' : 'N'}',
        ${rule.priority}, $bankVal, $txTypeVal,
        '${rule.chargeCompteId}', '${rule.calcMethod.code}', ${rule.amount}, ${rule.percentVal},
        ${rule.minAmount}, ${rule.maxAmount}, '${rule.baseType.code}', $parentVal, $taxVal,
        ${rule.taxRatePercent}, '${rule.roundingMode}', '${toSqlDateTime(rule.validFrom)}', $validToVal,
        '${rule.isCumulative ? 'O' : 'N'}'
      ) MATCHING (ID)
      ''',
    );
  }

  Future<void> deleteBankRule(String ruleId) async {
    _ensureConnected();
    await db.connection.connection!.execute(
      "DELETE FROM BANK_RULES WHERE ID = '$ruleId'",
    );
  }

  // ==========================================
  // 4. CHÈQUES & REMISES
  // ==========================================

  Future<List<Cheque>> getChequesInPortfolio() async {
    _ensureConnected();
    final query = '''
      SELECT 
        c.ID, c.CHEQUE_NUMBER, c.MONTANT, c.TIERS_ID, c.DRAWEE_BANK_COMPTE_ID, c.DRAWEE_BANK_NAME,
        c.ISSUE_DATE, c.DUE_DATE, c.FACTURE_VENTE_ID, c.REMISE_ID, c.STATUS, c.NOTES, c.USER_ID,
        t.NOM as CLIENT_NOM, db.LIBELLE as DRAWEE_BANK_LIBELLE,
        fv.NUM_FACTURE as NUM_FACTURE
      FROM CHEQUES c
      JOIN TIERS t ON t.ID = c.TIERS_ID
      LEFT JOIN COMPTES db ON db.ID = c.DRAWEE_BANK_COMPTE_ID
      LEFT JOIN FACTURE_VENTE fv ON fv.ID = c.FACTURE_VENTE_ID
      WHERE c.STATUS = 'EN_PORTEFEUILLE'
      ORDER BY c.ISSUE_DATE ASC
    ''';

    final rows = await db.connection.connection!.execute(query);
    return rows.map((r) => Cheque.fromMap(r)).toList();
  }

  Future<List<Cheque>> getChequesByRemiseId(String remiseId) async {
    _ensureConnected();
    final query = '''
      SELECT 
        c.ID, c.CHEQUE_NUMBER, c.MONTANT, c.TIERS_ID, c.DRAWEE_BANK_COMPTE_ID, c.DRAWEE_BANK_NAME,
        c.ISSUE_DATE, c.DUE_DATE, c.FACTURE_VENTE_ID, c.REMISE_ID, c.STATUS, c.NOTES, c.USER_ID,
        t.NOM as CLIENT_NOM, db.LIBELLE as DRAWEE_BANK_LIBELLE,
        fv.NUM_FACTURE as NUM_FACTURE
      FROM CHEQUES c
      JOIN TIERS t ON t.ID = c.TIERS_ID
      LEFT JOIN COMPTES db ON db.ID = c.DRAWEE_BANK_COMPTE_ID
      LEFT JOIN FACTURE_VENTE fv ON fv.ID = c.FACTURE_VENTE_ID
      WHERE c.REMISE_ID = '$remiseId'
      ORDER BY c.CHEQUE_NUMBER ASC
    ''';

    final rows = await db.connection.connection!.execute(query);
    return rows.map((r) => Cheque.fromMap(r)).toList();
  }

  Future<List<BankTransactionFee>> getFeesByRemiseId(String remiseId) async {
    _ensureConnected();
    final query = '''
      SELECT 
        f.ID, f.REMISE_ID, f.MOVEMENT_TRISOR_ID, f.RULE_ID, f.CHARGE_COMPTE_ID,
        f.BASE_AMOUNT, f.RATE_OR_AMOUNT, f.COMPUTED_AMOUNT, f.FINAL_AMOUNT,
        f.IS_MANUALLY_EDITED, f.EDITED_BY, f.EDIT_REASON,
        cc.CODE as CHARGE_CODE, cc.LIBELLE as CHARGE_LABEL,
        br.NAME as RULE_NAME
      FROM BANK_TRANSACTION_FEES f
      JOIN COMPTES cc ON cc.ID = f.CHARGE_COMPTE_ID
      LEFT JOIN BANK_RULES br ON br.ID = f.RULE_ID
      WHERE f.REMISE_ID = '$remiseId'
      ORDER BY f.BASE_AMOUNT DESC
    ''';

    final rows = await db.connection.connection!.execute(query);
    return rows.map((r) => BankTransactionFee.fromMap(r)).toList();
  }

  Future<List<RemiseCheque>> getRemises() async {
    _ensureConnected();
    final query = '''
      SELECT 
        r.ID, r.BORDEREAU_NUMBER, r.DATE_REMISE, r.BANK_COMPTE_ID,
        r.TOTAL_AMOUNT, r.CHEQUES_COUNT, r.STATUS, r.NOTES,
        r.MOVEMENT_TRISOR_ID, r.CREATED_BY, r.VALIDATED_BY, r.VALIDATED_AT,
        r.CANCELLED_BY, r.CANCELLED_AT,
        cb.CODE as BANK_CODE, cb.LIBELLE as BANK_LABEL
      FROM REMISES_CHEQUES r
      JOIN COMPTES cb ON cb.ID = r.BANK_COMPTE_ID
      ORDER BY r.DATE_REMISE DESC
    ''';

    final rows = await db.connection.connection!.execute(query);
    return rows.map((r) => RemiseCheque.fromMap(r)).toList();
  }

  Future<void> saveFees(List<BankTransactionFee> fees) async {
    _ensureConnected();
    for (final f in fees) {
      final remiseVal = f.remiseId != null ? "'${f.remiseId}'" : "NULL";
      final movVal = f.movementTrisorId != null ? "'${f.movementTrisorId}'" : "NULL";
      final ruleVal = f.ruleId != null ? "'${f.ruleId}'" : "NULL";
      final editedByVal = f.editedBy != null ? "'${f.editedBy}'" : "NULL";
      final reasonVal = f.editReason != null ? "'${f.editReason!.replaceAll("'", "''")}'" : "NULL";

      await db.connection.connection!.execute(
        '''
        UPDATE OR INSERT INTO BANK_TRANSACTION_FEES (
          ID, REMISE_ID, MOVEMENT_TRISOR_ID, RULE_ID, CHARGE_COMPTE_ID,
          BASE_AMOUNT, RATE_OR_AMOUNT, COMPUTED_AMOUNT, FINAL_AMOUNT,
          IS_MANUALLY_EDITED, EDITED_BY, EDITED_AT, EDIT_REASON
        ) VALUES (
          '${f.id}', $remiseVal, $movVal, $ruleVal, '${f.chargeCompteId}',
          ${f.baseAmount}, ${f.rateOrAmount}, ${f.computedAmount}, ${f.finalAmount},
          '${f.isManuallyEdited ? 'O' : 'N'}', $editedByVal,
          ${f.editedAt != null ? "'${toSqlDateTime(f.editedAt!)}'" : "NULL"},
          $reasonVal
        ) MATCHING (ID)
        ''',
      );
    }
  }

  Future<void> createRemiseDraft({
    required RemiseCheque remise,
    required List<String> chequeIds,
    required List<BankTransactionFee> fees,
  }) async {
    _ensureConnected();
    await db.connection.connection!.execute(
      '''
      INSERT INTO REMISES_CHEQUES (
        ID, BORDEREAU_NUMBER, DATE_REMISE, BANK_COMPTE_ID,
        TOTAL_AMOUNT, CHEQUES_COUNT, STATUS, NOTES, CREATED_BY
      ) VALUES (
        '${remise.id}', '${remise.bordereauNumber.replaceAll("'", "''")}',
        '${toSqlDateTime(remise.dateRemise)}', '${remise.bankCompteId}',
        ${remise.totalAmount}, ${remise.chequesCount}, 'BROUILLON',
        ${remise.notes != null ? "'${remise.notes!.replaceAll("'", "''")}'" : "NULL"},
        '${remise.createdBy}'
      )
      ''',
    );

    for (final chqId in chequeIds) {
      await db.connection.connection!.execute(
        "UPDATE CHEQUES SET REMISE_ID = '${remise.id}', STATUS = 'DANS_REMISE' WHERE ID = '$chqId'",
      );
    }

    await saveFees(fees);
  }

  Future<void> validateRemise({
    required String remiseId,
    required String validatedByUserId,
    required String bankCompteId,
    required double totalAmount,
    required String bordereauNumber,
    required List<BankTransactionFee> fees,
  }) async {
    _ensureConnected();
    final movId = Uuid.v4();
    final now = DateTime.now();

    // Versement Trésorerie: Entrée sur le compte bancaire choisi dans COMPTES
    await db.connection.connection!.execute(
      '''
      INSERT INTO MOVEMENTS_TRISOIR (
        ID, DATE_MOV, COMPTE_SOURCE_ID, COMPTE_DEST_ID, MONTANT, DESIGNATION, USER_ID
      ) VALUES (
        '$movId', '${toSqlDateTime(now)}',
        '$bankCompteId',
        '$bankCompteId',
        $totalAmount,
        'Versement chèques - Bordereau $bordereauNumber',
        '$validatedByUserId'
      )
      ''',
    );

    await db.connection.connection!.execute(
      '''
      UPDATE REMISES_CHEQUES 
      SET STATUS = 'VALIDEE',
          VALIDATED_BY = '$validatedByUserId',
          VALIDATED_AT = '${toSqlDateTime(now)}',
          MOVEMENT_TRISOR_ID = '$movId'
      WHERE ID = '$remiseId'
      ''',
    );

    await db.connection.connection!.execute(
      "UPDATE CHEQUES SET STATUS = 'REMIS_EN_BANQUE' WHERE REMISE_ID = '$remiseId'",
    );

    for (final f in fees) {
      await db.connection.connection!.execute(
        "UPDATE BANK_TRANSACTION_FEES SET MOVEMENT_TRISOR_ID = '$movId' WHERE ID = '${f.id}'",
      );
    }

    await db.connection.connection!.execute(
      '''
      INSERT INTO BANK_AUDIT_LOGS (ID, USER_ID, ACTION, ENTITY_NAME, ENTITY_ID, DETAILS)
      VALUES (
        '${Uuid.v4()}', '$validatedByUserId', 'REMISE_VALIDATED', 'REMISES_CHEQUES', '$remiseId',
        'Validation de la remise $bordereauNumber (Montant: $totalAmount DZD)'
      )
      ''',
    );
  }

  Future<void> cancelRemise({
    required String remiseId,
    required String cancelledByUserId,
    required String reason,
  }) async {
    _ensureConnected();
    final now = DateTime.now();

    await db.connection.connection!.execute(
      "UPDATE CHEQUES SET REMISE_ID = NULL, STATUS = 'EN_PORTEFEUILLE' WHERE REMISE_ID = '$remiseId'",
    );

    await db.connection.connection!.execute(
      '''
      UPDATE REMISES_CHEQUES 
      SET STATUS = 'ANNULEE',
          CANCELLED_BY = '$cancelledByUserId',
          CANCELLED_AT = '${now.toIso8601String()}',
          NOTES = COALESCE(NOTES, '') || ' [Annulé: ${reason.replaceAll("'", "''")}]'
      WHERE ID = '$remiseId'
      ''',
    );

    await db.connection.connection!.execute(
      '''
      INSERT INTO BANK_AUDIT_LOGS (ID, USER_ID, ACTION, ENTITY_NAME, ENTITY_ID, DETAILS)
      VALUES (
        '${Uuid.v4()}', '$cancelledByUserId', 'REMISE_CANCELLED', 'REMISES_CHEQUES', '$remiseId',
        'Annulation de la remise: ${reason.replaceAll("'", "''")}'
      )
      ''',
    );
  }
}
