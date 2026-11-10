import '../../../core/database/database.dart';
import '../../../core/services/bank_fee_calculator.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/uuid.dart';
import '../models/bank_rule.dart';
import '../models/client_situation.dart';
import '../models/reglement.dart';

class ReglementDataSource {
  final Database db;

  ReglementDataSource(this.db);

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

  Future<String> generateNextNumReglement(String typeReglement) async {
    _ensureConnected();
    final year = DateTime.now().year;
    final prefix = typeReglement == 'CLIENT' ? 'REG-CL-$year-' : 'REG-FR-$year-';
    final query = "SELECT COUNT(*) AS CNT FROM REGLEMENT WHERE NUM_REGLEMENT LIKE '$prefix%'";
    final rows = await db.connection.connection!.execute(query);
    final count = int.tryParse(rows.first['CNT']?.toString().trim() ?? '0') ?? 0;
    return '$prefix${(count + 1).toString().padLeft(4, '0')}';
  }

  /// Récupère tous les règlements (avec filtre possible par client / fournisseur ou type)
  Future<List<Reglement>> getReglements({
    String? typeReglement,
    String? tiersId,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  }) async {
    _ensureConnected();
    final conditions = <String>[];
    if (typeReglement != null && typeReglement.isNotEmpty) {
      conditions.add("R.TYPE_REGLEMENT = '$typeReglement'");
    }
    if (tiersId != null && tiersId.isNotEmpty) {
      conditions.add("R.TIERS_ID = '$tiersId'");
    }
    if (from != null) {
      conditions.add("R.DATE_REGLEMENT >= '${toSqlDateTime(from)}'");
    }
    if (to != null) {
      conditions.add("R.DATE_REGLEMENT <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'");
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().replaceAll("'", "''");
      conditions.add("(R.NUM_REGLEMENT LIKE '%$q%' OR T.NOM LIKE '%$q%' OR R.OBSERVATION LIKE '%$q%')");
    }

    final whereSql = conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}';
    final query = '''
      SELECT R.ID, R.NUM_REGLEMENT, R.TYPE_REGLEMENT, R.TIERS_ID, R.COMPTE_CAISSE_ID,
             R.COMPTE_CONTREPARTIE_ID, R.DATE_REGLEMENT, R.MONTANT, R.MODE_PAIEMENT,
             R.DEPARTEMENT_ID, R.NUM_CHEQUE, R.DATE_CHEQUE, R.OBSERVATION,
             R.MOVEMENT_TRISOR_ID, R.USER_ID, R.CREATED_AT, R.UPDATED_AT,
             T.NOM AS TIERS_NOM, C.LIBELLE AS CAISSE_LIBELLE, D.NOM AS DEPARTEMENT_NOM
      FROM REGLEMENT R
      LEFT JOIN TIERS T ON T.ID = R.TIERS_ID
      LEFT JOIN COMPTES C ON C.ID = R.COMPTE_CAISSE_ID
      LEFT JOIN DEPARTEMENT D ON D.ID = R.DEPARTEMENT_ID
      $whereSql
      ORDER BY R.DATE_REGLEMENT DESC, R.NUM_REGLEMENT DESC
    ''';

    final rows = await db.connection.connection!.execute(query);
    final reglements = <Reglement>[];

    for (final r in rows) {
      final regId = r['ID'].toString().trim();
      final factures = await getFacturesForReglement(regId);
      reglements.add(Reglement.fromMap(r, factures: factures));
    }

    return reglements;
  }

  /// Récupère les factures réglées par un règlement précis
  Future<List<ReglementFacture>> getFacturesForReglement(String reglementId) async {
    _ensureConnected();
    final query = '''
      SELECT RF.ID, RF.REGLEMENT_ID, RF.FACTURE_TYPE, RF.FACTURE_ID, RF.MONTANT_APPLIQUE, RF.CREATED_AT,
             CASE WHEN RF.FACTURE_TYPE = 'VENTE' THEN FV.NUM_FACTURE ELSE FA.NUM_FACTURE END AS NUM_FACTURE,
             CASE WHEN RF.FACTURE_TYPE = 'VENTE' THEN FV.DATE_FACTURE ELSE FA.DATE_FACTURE END AS DATE_FACTURE,
             CASE WHEN RF.FACTURE_TYPE = 'VENTE' THEN FV.MONTANT ELSE FA.MONTANT END AS MONTANT_FACTURE
      FROM REGLEMENT_FACTURE RF
      LEFT JOIN FACTURE_VENTE FV ON FV.ID = RF.FACTURE_ID AND RF.FACTURE_TYPE = 'VENTE'
      LEFT JOIN FACTURE_ACHAT FA ON FA.ID = RF.FACTURE_ID AND RF.FACTURE_TYPE = 'ACHAT'
      WHERE RF.REGLEMENT_ID = '$reglementId'
      ORDER BY RF.CREATED_AT ASC
    ''';
    final rows = await db.connection.connection!.execute(query);
    return rows.map((r) => ReglementFacture.fromMap(r)).toList();
  }

  /// Calcule la situation d'un client (toutes ses factures, tous ses règlements, solde progressif)
  Future<ClientSituation> getClientSituation(String tiersId) async {
    _ensureConnected();
    // 1. Tiers info
    final tiersRows = await db.connection.connection!.execute("SELECT NOM FROM TIERS WHERE ID = '$tiersId'");
    final clientNom = tiersRows.isNotEmpty ? (tiersRows.first['NOM']?.toString().trim() ?? '') : '';

    // 2. Factures du client
    final facturesRows = await db.connection.connection!.execute('''
      SELECT ID, NUM_FACTURE, DATE_FACTURE, MONTANT, DESIGNATION, MODE_PAIEMENT
      FROM FACTURE_VENTE
      WHERE TIERS_ID = '$tiersId'
      ORDER BY DATE_FACTURE ASC
    ''');

    // 3. Règlements du client
    final reglementsRows = await db.connection.connection!.execute('''
      SELECT ID, NUM_REGLEMENT, DATE_REGLEMENT, MONTANT, MODE_PAIEMENT, OBSERVATION
      FROM REGLEMENT
      WHERE TIERS_ID = '$tiersId' AND TYPE_REGLEMENT = 'CLIENT'
      ORDER BY DATE_REGLEMENT ASC
    ''');

    // Fusionner chronologiquement
    final combined = <Map<String, dynamic>>[];
    for (final f in facturesRows) {
      combined.add({
        'id': f['ID'].toString().trim(),
        'date': _parseDate(f['DATE_FACTURE']),
        'type': 'FACTURE',
        'reference': f['NUM_FACTURE'].toString().trim(),
        'debit': double.tryParse(f['MONTANT']?.toString() ?? '0') ?? 0.0,
        'credit': 0.0,
        'modePaiement': f['MODE_PAIEMENT']?.toString().trim() ?? '—',
        'observation': f['DESIGNATION']?.toString().trim(),
      });
    }

    for (final r in reglementsRows) {
      combined.add({
        'id': r['ID'].toString().trim(),
        'date': _parseDate(r['DATE_REGLEMENT']),
        'type': 'REGLEMENT',
        'reference': r['NUM_REGLEMENT'].toString().trim(),
        'debit': 0.0,
        'credit': double.tryParse(r['MONTANT']?.toString() ?? '0') ?? 0.0,
        'modePaiement': r['MODE_PAIEMENT']?.toString().trim() ?? 'Espèces',
        'observation': r['OBSERVATION']?.toString().trim(),
      });
    }

    combined.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    double runningSolde = 0.0;
    double totalFactures = 0.0;
    double totalReglements = 0.0;
    final mouvements = <ClientSituationMovement>[];

    for (final item in combined) {
      final debit = item['debit'] as double;
      final credit = item['credit'] as double;
      totalFactures += debit;
      totalReglements += credit;
      runningSolde += (debit - credit);

      mouvements.add(ClientSituationMovement(
        id: item['id'] as String,
        date: item['date'] as DateTime,
        type: item['type'] as String,
        reference: item['reference'] as String,
        debit: debit,
        credit: credit,
        soldeProgressif: runningSolde,
        modePaiement: item['modePaiement'] as String,
        observation: item['observation'] as String?,
      ));
    }

    return ClientSituation(
      tiersId: tiersId,
      clientNom: clientNom,
      totalFactures: totalFactures,
      totalReglements: totalReglements,
      solde: runningSolde,
      mouvements: mouvements,
    );
  }

  /// Effectue un règlement (Versement ou Règle spécifique)
  /// - Crée le REGLEMENT
  /// - Crée les allocations dans REGLEMENT_FACTURE
  /// - Si chèque client : place le chèque dans CHEQUES (statut EN_PORTEFEUILLE)
  ///   et NE CRÉE PAS de mouvement de trésorerie direct ni de frais bancaires immédiats
  /// - Si autre mode ou fournisseur : Crée automatiquement le mouvement dans MOVEMENTS_TRISOIR
  ///   et applique les frais bancaires si banque
  Future<String> createReglement({
    required String typeReglement, // 'CLIENT' ou 'FOURNISSEUR'
    required String tiersId,
    required String compteCaisseId,
    String? compteContrepartieId,
    required DateTime dateReglement,
    required double montant,
    required String modePaiement,
    String? departementId,
    String? numCheque,
    DateTime? dateCheque,
    String? observation,
    required String userId,
    required List<Map<String, dynamic>> allocations, // [{'factureId': ..., 'factureType': 'VENTE'/'ACHAT', 'montant': ...}]
  }) async {
    _ensureConnected();
    final reglementId = Uuid.v4();
    final numReglement = await generateNextNumReglement(typeReglement);

    final isClientCheque = (typeReglement == 'CLIENT' && modePaiement == 'Chèque');

    final dateSql = toSqlDateTime(dateReglement);
    final dateChequeSql = dateCheque != null ? "'${toSqlDateTime(dateCheque)}'" : "NULL";
    final numChequeSql = (numCheque != null && numCheque.trim().isNotEmpty) ? "'${numCheque.trim().replaceAll("'", "''")}'" : "NULL";
    final cleanObs = (observation ?? '').replaceAll("'", "''");
    final depIdSql = (departementId != null && departementId.isNotEmpty) ? "'$departementId'" : "NULL";
    final contrepartieSql = (compteContrepartieId != null && compteContrepartieId.isNotEmpty) ? "'$compteContrepartieId'" : "NULL";

    String? movId;

    if (!isClientCheque) {
      // 1. Déterminer Compte Source et Compte Dest pour le Mouvement Trésorerie
      final String movSourceId;
      final String movDestId;

      if (typeReglement == 'CLIENT') {
        movDestId = compteCaisseId;
        movSourceId = (compteContrepartieId != null && compteContrepartieId.isNotEmpty)
            ? compteContrepartieId
            : 'e953f50c-b365-4dd7-a8ce-50972d9c2b39'; // Compte vente standard
      } else {
        movSourceId = compteCaisseId;
        movDestId = (compteContrepartieId != null && compteContrepartieId.isNotEmpty)
            ? compteContrepartieId
            : '3b78186d-3835-46a7-99d7-f2c3a69523f9'; // Compte achat standard
      }

      final designationMov = cleanObs.isNotEmpty 
          ? '$numReglement - $cleanObs' 
          : '$numReglement ($modePaiement)';

      final origineModule = typeReglement == 'CLIENT' ? 'VENTE' : 'ACHAT';
      movId = Uuid.v4();

      final insertMovSql = '''
        INSERT INTO MOVEMENTS_TRISOIR
        (ID, DATE_MOV, COMPTE_SOURCE_ID, COMPTE_DEST_ID, MONTANT, DESIGNATION, USER_ID,
         MODE_PAIEMENT, NUM_CHEQUE, DATE_CHEQUE, REGLEMENT_ID, ORIGINE_MODULE)
        VALUES
        ('$movId', '$dateSql', '$movSourceId', '$movDestId', $montant, '$designationMov', '$userId',
         '$modePaiement', $numChequeSql, $dateChequeSql, '$reglementId', '$origineModule')
      ''';
      await db.connection.connection!.execute(insertMovSql);
    }

    // 2. Créer le règlement
    final movIdSql = movId != null ? "'$movId'" : "NULL";
    final insertRegSql = '''
      INSERT INTO REGLEMENT
      (ID, NUM_REGLEMENT, TYPE_REGLEMENT, TIERS_ID, COMPTE_CAISSE_ID, COMPTE_CONTREPARTIE_ID,
       DATE_REGLEMENT, MONTANT, MODE_PAIEMENT, DEPARTEMENT_ID, NUM_CHEQUE, DATE_CHEQUE,
       OBSERVATION, MOVEMENT_TRISOR_ID, USER_ID)
      VALUES
      ('$reglementId', '$numReglement', '$typeReglement', '$tiersId', '$compteCaisseId', $contrepartieSql,
       '$dateSql', $montant, '$modePaiement', $depIdSql, $numChequeSql, $dateChequeSql,
       '$cleanObs', $movIdSql, '$userId')
    ''';
    await db.connection.connection!.execute(insertRegSql);

    // 3. Insérer les allocations de factures
    String? firstFactureVenteId;
    for (final alloc in allocations) {
      final allocId = Uuid.v4();
      final factId = alloc['factureId'].toString();
      final fType = alloc['factureType'].toString();
      final mAlloc = double.tryParse(alloc['montant'].toString()) ?? 0.0;

      if (fType == 'VENTE' && firstFactureVenteId == null) {
        firstFactureVenteId = factId;
      }

      final insertAllocSql = '''
        INSERT INTO REGLEMENT_FACTURE
        (ID, REGLEMENT_ID, FACTURE_TYPE, FACTURE_ID, MONTANT_APPLIQUE)
        VALUES
        ('$allocId', '$reglementId', '$fType', '$factId', $mAlloc)
      ''';
      await db.connection.connection!.execute(insertAllocSql);
    }

    // 4. Si c'est un chèque client, on l'ajoute en portefeuille (CHEQUES)
    if (isClientCheque) {
      final chqId = Uuid.v4();
      final chqNumber = (numCheque != null && numCheque.trim().isNotEmpty)
          ? numCheque.trim().replaceAll("'", "''")
          : numReglement;
      final firstFactIdSql = firstFactureVenteId != null ? "'$firstFactureVenteId'" : "NULL";

      // Obtenir le libellé de la banque tirée
      final bnkRows = await db.connection.connection!.execute(
        "SELECT LIBELLE FROM COMPTES WHERE ID = '$compteCaisseId'"
      );
      final draweeBankName = bnkRows.isNotEmpty 
          ? (bnkRows.first['LIBELLE']?.toString().trim() ?? '').replaceAll("'", "''")
          : '';

      final insertChequeSql = '''
        INSERT INTO CHEQUES (
          ID, CHEQUE_NUMBER, MONTANT, TIERS_ID, DRAWEE_BANK_COMPTE_ID, DRAWEE_BANK_NAME,
          ISSUE_DATE, DUE_DATE, FACTURE_VENTE_ID, STATUS, NOTES, USER_ID, REGLEMENT_ID
        ) VALUES (
          '$chqId', '$chqNumber', $montant, '$tiersId', '$compteCaisseId', '$draweeBankName',
          '$dateSql', $dateChequeSql, $firstFactIdSql, 'EN_PORTEFEUILLE',
          '$cleanObs', '$userId', '$reglementId'
        )
      ''';
      await db.connection.connection!.execute(insertChequeSql);
    }
    // 5. Appliquer les règles bancaires SEULEMENT si ce n'est pas un chèque client en attente de remise
    if (!isClientCheque && movId != null) {
      await _applyBankRulesIfApplicable(
        caisseOrBanqueId: compteCaisseId,
        modePaiement: modePaiement,
        typeReglement: typeReglement,
        montant: montant,
        date: dateReglement,
        movementId: movId,
        userId: userId,
      );
    }

    return reglementId;
  }

  /// Met à jour un règlement existant (Permis uniquement depuis Vente/Achat, pas depuis Trésorerie)
  Future<void> updateReglement({
    required String reglementId,
    required DateTime dateReglement,
    required double montant,
    required String modePaiement,
    required String compteCaisseId,
    String? departementId,
    String? numCheque,
    DateTime? dateCheque,
    String? observation,
    required List<Map<String, dynamic>> allocations,
  }) async {
    _ensureConnected();

    // 1. Lire le règlement existant
    final rows = await db.connection.connection!.execute(
      "SELECT MOVEMENT_TRISOR_ID, TYPE_REGLEMENT, COMPTE_CONTREPARTIE_ID FROM REGLEMENT WHERE ID = '$reglementId'",
    );
    if (rows.isEmpty) throw Exception('Règlement introuvable.');

    final movId = rows.first['MOVEMENT_TRISOR_ID']?.toString().trim();
    final typeReglement = rows.first['TYPE_REGLEMENT']?.toString().trim() ?? 'CLIENT';
    final contrepartie = rows.first['COMPTE_CONTREPARTIE_ID']?.toString().trim();

    final dateSql = toSqlDateTime(dateReglement);
    final dateChequeSql = dateCheque != null ? "'${toSqlDateTime(dateCheque)}'" : "NULL";
    final numChequeSql = (numCheque != null && numCheque.trim().isNotEmpty) ? "'${numCheque.trim().replaceAll("'", "''")}'" : "NULL";
    final cleanObs = (observation ?? '').replaceAll("'", "''");
    final depIdSql = (departementId != null && departementId.isNotEmpty) ? "'$departementId'" : "NULL";

    // Mettre à jour le REGLEMENT
    final updateRegSql = '''
      UPDATE REGLEMENT
      SET DATE_REGLEMENT = '$dateSql',
          MONTANT = $montant,
          MODE_PAIEMENT = '$modePaiement',
          COMPTE_CAISSE_ID = '$compteCaisseId',
          DEPARTEMENT_ID = $depIdSql,
          NUM_CHEQUE = $numChequeSql,
          DATE_CHEQUE = $dateChequeSql,
          OBSERVATION = '$cleanObs',
          UPDATED_AT = CURRENT_TIMESTAMP
      WHERE ID = '$reglementId'
    ''';
    await db.connection.connection!.execute(updateRegSql);

    // Mettre à jour le mouvement de trésorerie lié (si existant)
    if (movId != null && movId.isNotEmpty) {
      final String movSourceId;
      final String movDestId;

      if (typeReglement == 'CLIENT') {
        movDestId = compteCaisseId;
        movSourceId = (contrepartie != null && contrepartie.isNotEmpty)
            ? contrepartie
            : 'e953f50c-b365-4dd7-a8ce-50972d9c2b39';
      } else {
        movSourceId = compteCaisseId;
        movDestId = (contrepartie != null && contrepartie.isNotEmpty)
            ? contrepartie
            : '3b78186d-3835-46a7-99d7-f2c3a69523f9';
      }

      final updateMovSql = '''
        UPDATE MOVEMENTS_TRISOIR
        SET DATE_MOV = '$dateSql',
            MONTANT = $montant,
            COMPTE_SOURCE_ID = '$movSourceId',
            COMPTE_DEST_ID = '$movDestId',
            DESIGNATION = '$cleanObs',
            MODE_PAIEMENT = '$modePaiement',
            NUM_CHEQUE = $numChequeSql,
            DATE_CHEQUE = $dateChequeSql,
            UPDATED_AT = CURRENT_TIMESTAMP
        WHERE ID = '$movId'
      ''';
      await db.connection.connection!.execute(updateMovSql);
    }

    // Mettre à jour le chèque en portefeuille si c'est un règlement par chèque client
    if (typeReglement == 'CLIENT' && modePaiement == 'Chèque') {
      final chqNumSafe = (numCheque != null && numCheque.trim().isNotEmpty)
          ? "'${numCheque.trim().replaceAll("'", "''")}'"
          : "NULL";
      final updateChqSql = '''
        UPDATE CHEQUES
        SET CHEQUE_NUMBER = COALESCE($chqNumSafe, CHEQUE_NUMBER),
            MONTANT = $montant,
            DRAWEE_BANK_COMPTE_ID = '$compteCaisseId',
            ISSUE_DATE = '$dateSql',
            DUE_DATE = $dateChequeSql,
            NOTES = '$cleanObs'
        WHERE REGLEMENT_ID = '$reglementId' AND STATUS = 'EN_PORTEFEUILLE'
      ''';
      await db.connection.connection!.execute(updateChqSql);
    }
    // Réinitialiser les allocations
    await db.connection.connection!.execute("DELETE FROM REGLEMENT_FACTURE WHERE REGLEMENT_ID = '$reglementId'");
    for (final alloc in allocations) {
      final allocId = Uuid.v4();
      final factId = alloc['factureId'].toString();
      final fType = alloc['factureType'].toString();
      final mAlloc = double.tryParse(alloc['montant'].toString()) ?? 0.0;

      final insertAllocSql = '''
        INSERT INTO REGLEMENT_FACTURE
        (ID, REGLEMENT_ID, FACTURE_TYPE, FACTURE_ID, MONTANT_APPLIQUE)
        VALUES
        ('$allocId', '$reglementId', '$fType', '$factId', $mAlloc)
      ''';
      await db.connection.connection!.execute(insertAllocSql);
    }
  }

  /// Applique les règles de frais bancaires si le compte sélectionné est une banque
  Future<void> _applyBankRulesIfApplicable({
    required String caisseOrBanqueId,
    required String modePaiement,
    required String typeReglement,
    required double montant,
    required DateTime date,
    required String movementId,
    required String userId,
  }) async {
    // Vérifier si le compte est de type banque
    final cRows = await db.connection.connection!.execute(
      "SELECT TYPE_COMPTE, CODE FROM COMPTES WHERE ID = '$caisseOrBanqueId'",
    );
    if (cRows.isEmpty) return;
    final typeCompte = cRows.first['TYPE_COMPTE']?.toString().trim().toLowerCase();
    final code = cRows.first['CODE']?.toString().trim();
    final isBank = typeCompte == 'banque' ;
    if (!isBank) return;

    // Dériver le code d'opération bancaire
    final String txCode;
    switch (modePaiement) {
      case 'Chèque':
        txCode = typeReglement == 'CLIENT' ? 'VERSEMENT_CHEQUE' : 'PAIEMENT_CHEQUE';
        break;
      case 'Virement':
      case 'Virement bancaire':
        txCode = typeReglement == 'CLIENT' ? 'VIREMENT_RECU' : 'VIREMENT_EMIS';
        break;
      case 'Versement bancaire':
      case 'Versement':
        txCode = 'VERSEMENT_ESPECES';
        break;
      default:
        return;
    }

    try {
      // Charger les types et les règles
      final txRows = await db.connection.connection!.execute("SELECT ID, CODE FROM TRANSACTION_TYPES WHERE ACTIVE = 'O'");
      final txMap = {for (final r in txRows) r['CODE'].toString().trim(): r['ID'].toString().trim()};

      final brRows = await db.connection.connection!.execute('''
        SELECT ID, NAME, ACTIVE, PRIORITY, BANK_COMPTE_ID, TRANSACTION_TYPE_ID,
               CHARGE_COMPTE_ID, CALC_METHOD, AMOUNT, PERCENT_VAL, MIN_AMOUNT, MAX_AMOUNT,
               BASE_TYPE, PARENT_RULE_ID, TAX_COMPTE_ID, TAX_RATE_PERCENT, ROUNDING_MODE,
               VALID_FROM, VALID_TO, IS_CUMULATIVE
        FROM BANK_RULES WHERE ACTIVE = 'O'
      ''');
      final allRules = brRows.map((r) => BankRule.fromMap(r)).toList();

      final fees = BankFeeCalculator.computeFees(
        input: FeeCalculationInput(
          bankCompteId: caisseOrBanqueId,
          transactionTypeCode: txCode,
          transactionAmount: montant,
          chequesCount: 1,
          transactionDate: date,
        ),
        allRules: allRules,
        transactionTypeCodeToId: txMap,
        movementTrisorId: movementId,
      );
print('🏦 Compte sélectionné: $caisseOrBanqueId');
print('TYPE_COMPTE: $typeCompte | CODE: $code');
print('Compte reconnu comme banque: $isBank');
print('📏 -------------------------------');
print('📏 Règles bancaires trouvées: ${allRules.length}');
print('📏 -------------------------------');
print('🧮 Frais calculés: ${fees.length}');
      // Enregistrer les frais calculés
      for (final f in fees) {
        final feeId = Uuid.v4();
        final ruleVal = f.ruleId != null ? "'${f.ruleId}'" : "NULL";
        await db.connection.connection!.execute('''
          INSERT INTO BANK_TRANSACTION_FEES (
            ID, MOVEMENT_TRISOR_ID, RULE_ID, CHARGE_COMPTE_ID,
            BASE_AMOUNT, RATE_OR_AMOUNT, COMPUTED_AMOUNT, FINAL_AMOUNT,
            IS_MANUALLY_EDITED
          ) VALUES (
            '$feeId', '$movementId', $ruleVal, '${f.chargeCompteId}',
            ${f.baseAmount}, ${f.rateOrAmount}, ${f.computedAmount}, ${f.finalAmount},
            'N'
          )
        ''');
      }
    } catch (e,stackTrace) {
      print('❌ Erreur application frais bancaires: $e');
      print(stackTrace);
    }
  }
}

