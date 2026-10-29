import '../../../core/database/database.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/uuid.dart';
import '../../data/models/compte.dart';
import '../../data/models/demande_transfert.dart';
import '../../data/models/journal_suppression_entry.dart';
import '../../data/models/movement.dart';

class FinanceDataSource {
  final Database db;

  FinanceDataSource(this.db);

  void _ensureConnected() {
    if (!db.connection.isConnected) {
      throw Exception('Database not connected.');
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final s = value.toString().trim();
    return DateTime.tryParse(s) ?? DateTime.parse(s.substring(0, 10));
  }

  Future<List<Compte>> getAccounts() async {
    _ensureConnected();
    final result = await db.connection.connection!.execute(
      'SELECT ID, CODE, LIBELLE, COMPTE_FR, NIVEAU, BG, BD, IS_ACTIVE, USER_ID, TYPE_COMPTE, IS_DEVISE, CODE_DEVISE '
      'FROM COMPTES ORDER BY BG',
    );

    return result.map((row) {
      final activeRaw = (row['IS_ACTIVE'] ?? '').toString().trim().toUpperCase();
      final isDeviseRaw = (row['IS_DEVISE'] ?? '').toString().trim().toUpperCase();
      return Compte(
        id: row['ID'].toString(),
        code: row['CODE'].toString().trim(),
        libelle: row['LIBELLE'].toString().trim(),
        compteFr: row['COMPTE_FR']?.toString().trim(),
        niveau: int.tryParse(row['NIVEAU']?.toString().trim() ?? '1') ?? 1,
        bg: int.tryParse(row['BG']?.toString().trim() ?? '0') ?? 0,
        bd: int.tryParse(row['BD']?.toString().trim() ?? '1') ?? 1,
        active: activeRaw.isEmpty || activeRaw == 'O',
        userId: row['USER_ID']?.toString().trim(),
        typeCompte: CompteType.fromString(row['TYPE_COMPTE']?.toString()),
        isDevise: isDeviseRaw == 'O' || isDeviseRaw == 'Y' || isDeviseRaw == '1' || isDeviseRaw == 'TRUE',
        codeDevise: row['CODE_DEVISE']?.toString().trim(),
      );
    }).toList();
  }

  Future<Set<String>> getAccountIdsWithMovements() async {
    _ensureConnected();
    final rows = await db.connection.connection!.execute(
      'SELECT DISTINCT COMPTE_SOURCE_ID AS CID FROM MOVEMENTS_TRISOIR '
      'UNION '
      'SELECT DISTINCT COMPTE_DEST_ID AS CID FROM MOVEMENTS_TRISOIR',
    );
    return rows
        .map((r) => r['CID']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Movement>> getMovements({
    String? accountId,
    String? caisseId,
    String? compteId,
    int? compteBg,     // BG of selected compte (for sub-account tree filtering)
    int? compteBd,     // BD of selected compte (for sub-account tree filtering)
    Set<String>? allowedCaisseIds,
    DateTime? from,
    DateTime? to,
  }) async {
    _ensureConnected();

    final conditions = <String>[];
    if (from != null) {
      conditions.add("M.DATE_MOV >= '${toSqlDateTime(from)}'");
    }
    if (to != null) {
      conditions.add("M.DATE_MOV <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'");
    }
    if (accountId != null && accountId.isNotEmpty) {
      conditions.add("(M.COMPTE_SOURCE_ID = '$accountId' OR M.COMPTE_DEST_ID = '$accountId')");
    }
    if (caisseId != null && caisseId.isNotEmpty) {
      conditions.add("(M.COMPTE_SOURCE_ID = '$caisseId' OR M.COMPTE_DEST_ID = '$caisseId')");
    }
    if (allowedCaisseIds != null && allowedCaisseIds.isNotEmpty) {
      final idsList = allowedCaisseIds.map((id) => "'$id'").join(',');
      conditions.add("(M.COMPTE_SOURCE_ID IN ($idsList) OR M.COMPTE_DEST_ID IN ($idsList))");
    }

    // BG/BD-based hierarchical filter: include all sub-accounts in the selected compte's subtree
    if (compteBg != null && compteBd != null) {
      conditions.add(
        '(EXISTS (SELECT 1 FROM COMPTES C WHERE C.ID = M.COMPTE_SOURCE_ID AND C.BG >= $compteBg AND C.BD <= $compteBd) '
        'OR EXISTS (SELECT 1 FROM COMPTES C WHERE C.ID = M.COMPTE_DEST_ID AND C.BG >= $compteBg AND C.BD <= $compteBd))',
      );
    } else if (compteId != null && compteId.isNotEmpty) {
      // Fallback: exact match on account ID when no BG/BD available
      conditions.add("(M.COMPTE_SOURCE_ID = '$compteId' OR M.COMPTE_DEST_ID = '$compteId')");
    }

    final whereSql = conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}';
    final query = '''
      SELECT M.ID, M.DATE_MOV, M.COMPTE_SOURCE_ID, M.COMPTE_DEST_ID, M.MONTANT, M.DESIGNATION, M.USER_ID,
             M.MODE_PAIEMENT, M.NUM_CHEQUE, M.DATE_CHEQUE, M.TAUX_CHANGE, M.MONTANT_DEVISE,
             SRC.CODE AS SRC_CODE, SRC.LIBELLE AS SRC_LIBELLE,
             DST.CODE AS DST_CODE, DST.LIBELLE AS DST_LIBELLE
      FROM MOVEMENTS_TRISOIR M
      LEFT JOIN COMPTES SRC ON SRC.ID = M.COMPTE_SOURCE_ID
      LEFT JOIN COMPTES DST ON DST.ID = M.COMPTE_DEST_ID
      $whereSql
      ORDER BY M.DATE_MOV ASC, M.ID ASC
    ''';

    final rows = await db.connection.connection!.execute(query);

    return rows.map((r) {
      return Movement(
        id: r['ID'].toString().trim(),
        date: _parseDate(r['DATE_MOV']),
        compteSourceId: r['COMPTE_SOURCE_ID'].toString().trim(),
        compteDestId: r['COMPTE_DEST_ID'].toString().trim(),
        montant: double.tryParse(r['MONTANT']?.toString().trim() ?? '0') ?? 0.0,
        designation: r['DESIGNATION']?.toString().trim() ?? '',
        userId: r['USER_ID']?.toString().trim(),
        modePaiement: r['MODE_PAIEMENT']?.toString().trim(),
        numCheque: r['NUM_CHEQUE']?.toString().trim(),
        dateCheque: r['DATE_CHEQUE'] != null ? _parseDate(r['DATE_CHEQUE']) : null,
        tauxChange: double.tryParse(r['TAUX_CHANGE']?.toString().trim() ?? ''),
        montantDevise: double.tryParse(r['MONTANT_DEVISE']?.toString().trim() ?? ''),
        sourceCode: r['SRC_CODE']?.toString().trim(),
        sourceLibelle: r['SRC_LIBELLE']?.toString().trim(),
        destCode: r['DST_CODE']?.toString().trim(),
        destLibelle: r['DST_LIBELLE']?.toString().trim(),
      );
    }).toList();
  }

  Future<FinanceStats> getStats({
    String? accountId,
    DateTime? from,
    DateTime? to,
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    // 1. Calculate cumulative initial balance (solde initial) before the 'from' date
    double soldeInitial = 0.0;
    double deviseInitial = 0.0;
    if (accountId != null && accountId.isNotEmpty && from != null) {
      final fromSql = toSqlDateTime(from);
      final initialQuery = '''
        SELECT 
          COALESCE(SUM(CASE WHEN COMPTE_DEST_ID = '$accountId' THEN MONTANT ELSE 0 END), 0) AS INIT_ENTREES,
          COALESCE(SUM(CASE WHEN COMPTE_SOURCE_ID = '$accountId' THEN MONTANT ELSE 0 END), 0) AS INIT_SORTIES,
          COALESCE(SUM(CASE WHEN COMPTE_DEST_ID = '$accountId' AND MONTANT_DEVISE IS NOT NULL THEN MONTANT_DEVISE ELSE 0 END), 0) AS INIT_DEV_IN,
          COALESCE(SUM(CASE WHEN COMPTE_SOURCE_ID = '$accountId' AND MONTANT_DEVISE IS NOT NULL THEN MONTANT_DEVISE ELSE 0 END), 0) AS INIT_DEV_OUT
        FROM MOVEMENTS_TRISOIR
        WHERE DATE_MOV < '$fromSql' 
          AND (COMPTE_SOURCE_ID = '$accountId' OR COMPTE_DEST_ID = '$accountId')
      ''';
      final initRows = await conn.execute(initialQuery);
      if (initRows.isNotEmpty) {
        final r = initRows.first;
        final initEntrees = double.tryParse(r['INIT_ENTREES']?.toString().trim() ?? '0') ?? 0.0;
        final initSorties = double.tryParse(r['INIT_SORTIES']?.toString().trim() ?? '0') ?? 0.0;
        final initDevIn  = double.tryParse(r['INIT_DEV_IN']?.toString().trim()  ?? '0') ?? 0.0;
        final initDevOut = double.tryParse(r['INIT_DEV_OUT']?.toString().trim() ?? '0') ?? 0.0;
        soldeInitial = initEntrees - initSorties;
        deviseInitial = initDevIn - initDevOut;
      }
    }

    // 2. Calculate period statistics
    final conditions = <String>[];
    if (from != null) {
      conditions.add("DATE_MOV >= '${toSqlDateTime(from)}'");
    }
    if (to != null) {
      conditions.add("DATE_MOV <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'");
    }
    if (accountId != null && accountId.isNotEmpty) {
      conditions.add("(COMPTE_SOURCE_ID = '$accountId' OR COMPTE_DEST_ID = '$accountId')");
    }

    final whereSql = conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}';

    String sortiesSql = '0';
    String entreesSql = '0';
    String devEntreesSql = '0';
    String devSortiesSql = '0';
    if (accountId != null && accountId.isNotEmpty) {
      sortiesSql    = "COALESCE(SUM(CASE WHEN COMPTE_SOURCE_ID = '$accountId' THEN MONTANT ELSE 0 END), 0)";
      entreesSql    = "COALESCE(SUM(CASE WHEN COMPTE_DEST_ID = '$accountId' THEN MONTANT ELSE 0 END), 0)";
      devEntreesSql = "COALESCE(SUM(CASE WHEN COMPTE_DEST_ID = '$accountId' AND MONTANT_DEVISE IS NOT NULL THEN MONTANT_DEVISE ELSE 0 END), 0)";
      devSortiesSql = "COALESCE(SUM(CASE WHEN COMPTE_SOURCE_ID = '$accountId' AND MONTANT_DEVISE IS NOT NULL THEN MONTANT_DEVISE ELSE 0 END), 0)";
    }

    final query = '''
      SELECT COUNT(*) AS CNT,
             COALESCE(SUM(MONTANT), 0) AS TOTAL_MONTANT,
             $sortiesSql AS TOTAL_SORTIES,
             $entreesSql AS TOTAL_ENTREES,
             $devEntreesSql AS DEV_ENTREES,
             $devSortiesSql AS DEV_SORTIES
      FROM MOVEMENTS_TRISOIR $whereSql
    ''';

    final rows = await conn.execute(query);
    if (rows.isEmpty) {
      return FinanceStats(soldeInitial: soldeInitial, deviseInitial: deviseInitial);
    }

    final row = rows.first;
    return FinanceStats(
      soldeInitial:   soldeInitial,
      totalMontant:   double.tryParse(row['TOTAL_MONTANT']?.toString().trim() ?? '0') ?? 0.0,
      totalSorties:   double.tryParse(row['TOTAL_SORTIES']?.toString().trim() ?? '0') ?? 0.0,
      totalEntrees:   double.tryParse(row['TOTAL_ENTREES']?.toString().trim() ?? '0') ?? 0.0,
      countMovements: int.tryParse(row['CNT']?.toString().trim() ?? '0') ?? 0,
      deviseInitial:  deviseInitial,
      deviseEntrees:  double.tryParse(row['DEV_ENTREES']?.toString().trim() ?? '0') ?? 0.0,
      deviseSorties:  double.tryParse(row['DEV_SORTIES']?.toString().trim() ?? '0') ?? 0.0,
    );
  }

  /// Returns real-time financial stats for a list of specific caisses (respecting user access).
  Future<Map<String, Map<String, dynamic>>> getCaissesSummary({
    required List<String> caisseIds,
    DateTime? from,
    DateTime? to,
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;
    if (caisseIds.isEmpty) return {};

    final result = <String, Map<String, dynamic>>{};
    for (final cid in caisseIds) {
      // 1. Solde initial before 'from' (DZD + devise)
      double soldeInitial = 0.0;
      double deviseInitial = 0.0;
      if (from != null) {
        final fromSql = toSqlDateTime(from);
        final initRows = await conn.execute('''
          SELECT 
            COALESCE(SUM(CASE WHEN COMPTE_DEST_ID = '$cid' THEN MONTANT ELSE 0 END), 0) AS INIT_IN,
            COALESCE(SUM(CASE WHEN COMPTE_SOURCE_ID = '$cid' THEN MONTANT ELSE 0 END), 0) AS INIT_OUT,
            COALESCE(SUM(CASE WHEN COMPTE_DEST_ID = '$cid' AND MONTANT_DEVISE IS NOT NULL THEN MONTANT_DEVISE ELSE 0 END), 0) AS INIT_DEV_IN,
            COALESCE(SUM(CASE WHEN COMPTE_SOURCE_ID = '$cid' AND MONTANT_DEVISE IS NOT NULL THEN MONTANT_DEVISE ELSE 0 END), 0) AS INIT_DEV_OUT
          FROM MOVEMENTS_TRISOIR
          WHERE DATE_MOV < '$fromSql' AND (COMPTE_SOURCE_ID = '$cid' OR COMPTE_DEST_ID = '$cid')
        ''');
        if (initRows.isNotEmpty) {
          final initIn     = double.tryParse(initRows.first['INIT_IN']?.toString().trim()     ?? '0') ?? 0.0;
          final initOut    = double.tryParse(initRows.first['INIT_OUT']?.toString().trim()    ?? '0') ?? 0.0;
          final initDevIn  = double.tryParse(initRows.first['INIT_DEV_IN']?.toString().trim() ?? '0') ?? 0.0;
          final initDevOut = double.tryParse(initRows.first['INIT_DEV_OUT']?.toString().trim()?? '0') ?? 0.0;
          soldeInitial  = initIn - initOut;
          deviseInitial = initDevIn - initDevOut;
        }
      }

      // 2. Period movements (DZD + devise)
      final conditions = <String>["(COMPTE_SOURCE_ID = '$cid' OR COMPTE_DEST_ID = '$cid')"];
      if (from != null) conditions.add("DATE_MOV >= '${toSqlDateTime(from)}'");
      if (to != null) conditions.add("DATE_MOV <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'");

      final rows = await conn.execute('''
        SELECT 
          COUNT(*) AS CNT,
          COALESCE(SUM(CASE WHEN COMPTE_DEST_ID = '$cid' THEN MONTANT ELSE 0 END), 0) AS TOTAL_IN,
          COALESCE(SUM(CASE WHEN COMPTE_SOURCE_ID = '$cid' THEN MONTANT ELSE 0 END), 0) AS TOTAL_OUT,
          COALESCE(SUM(CASE WHEN COMPTE_DEST_ID = '$cid' AND MONTANT_DEVISE IS NOT NULL THEN MONTANT_DEVISE ELSE 0 END), 0) AS DEV_IN,
          COALESCE(SUM(CASE WHEN COMPTE_SOURCE_ID = '$cid' AND MONTANT_DEVISE IS NOT NULL THEN MONTANT_DEVISE ELSE 0 END), 0) AS DEV_OUT
        FROM MOVEMENTS_TRISOIR
        WHERE ${conditions.join(' AND ')}
      ''');

      final cnt      = int.tryParse(rows.first['CNT']?.toString().trim()        ?? '0') ?? 0;
      final totalIn  = double.tryParse(rows.first['TOTAL_IN']?.toString().trim() ?? '0') ?? 0.0;
      final totalOut = double.tryParse(rows.first['TOTAL_OUT']?.toString().trim()?? '0') ?? 0.0;
      final devIn    = double.tryParse(rows.first['DEV_IN']?.toString().trim()   ?? '0') ?? 0.0;
      final devOut   = double.tryParse(rows.first['DEV_OUT']?.toString().trim()  ?? '0') ?? 0.0;
      final soldeFinal = soldeInitial + (totalIn - totalOut);
      final deviseSoldeFinal = deviseInitial + devIn - devOut;

      result[cid] = {
        'count': cnt,
        'soldeInitial': soldeInitial,
        'entrees': totalIn,
        'sorties': totalOut,
        'soldeFinal': soldeFinal,
        'deviseInitial': deviseInitial,
        'deviseEntrees': devIn,
        'deviseSorties': devOut,
        'deviseSoldeFinal': deviseSoldeFinal,
      };
    }

    return result;
  }

  /// Calculates total charges (expenses belonging to Classe 6 / Charges accounts).
  /// Respects allowed caisses if provided.
  Future<Map<String, dynamic>> getChargesStatistics({
    String? caisseId,
    Set<String>? allowedCaisseIds,
    DateTime? from,
    DateTime? to,
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final conditions = <String>[
      "(C.CODE = '6' OR C.CODE STARTING WITH '6' OR LOWER(C.LIBELLE) LIKE '%charge%' OR LOWER(C.TYPE_COMPTE) = 'depense')"
    ];

    if (from != null) conditions.add("M.DATE_MOV >= '${toSqlDateTime(from)}'");
    if (to != null) conditions.add("M.DATE_MOV <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'");

    if (caisseId != null && caisseId.isNotEmpty) {
      conditions.add("M.COMPTE_SOURCE_ID = '$caisseId'");
    } else if (allowedCaisseIds != null && allowedCaisseIds.isNotEmpty) {
      final idsList = allowedCaisseIds.map((id) => "'$id'").join(',');
      conditions.add("M.COMPTE_SOURCE_ID IN ($idsList)");
    }

    final query = '''
      SELECT 
        COUNT(M.ID) AS CNT,
        COALESCE(SUM(M.MONTANT), 0) AS TOTAL_CHARGES
      FROM MOVEMENTS_TRISOIR M
      JOIN COMPTES C ON C.ID = M.COMPTE_DEST_ID
      WHERE ${conditions.join(' AND ')}
    ''';

    final rows = await conn.execute(query);
    if (rows.isEmpty) {
      return {'count': 0, 'total': 0.0};
    }

    return {
      'count': int.tryParse(rows.first['CNT']?.toString().trim() ?? '0') ?? 0,
      'total': double.tryParse(rows.first['TOTAL_CHARGES']?.toString().trim() ?? '0') ?? 0.0,
    };
  }

  Future<void> createMovement(Movement movement) async {
    _ensureConnected();
    final dateStr = toSqlDateTime(movement.date);
    final designation = movement.designation.replaceAll("'", "''");
    final userId = movement.userId ?? 'SYSTEM';
    final modeSql = movement.modePaiement != null ? "'${movement.modePaiement!.replaceAll("'", "''")}'" : 'NULL';
    final numChequeSql = movement.numCheque != null && movement.numCheque!.trim().isNotEmpty
        ? "'${movement.numCheque!.replaceAll("'", "''")}'"
        : 'NULL';
    final dateChequeSql = movement.dateCheque != null ? "'${toSqlDateTime(movement.dateCheque!)}'" : 'NULL';
    final tauxSql = movement.tauxChange != null ? '${movement.tauxChange}' : 'NULL';
    final montantDeviseSql = movement.montantDevise != null ? '${movement.montantDevise}' : 'NULL';

    await db.connection.connection!.execute(
      "INSERT INTO MOVEMENTS_TRISOIR "
      "(ID, DATE_MOV, COMPTE_SOURCE_ID, COMPTE_DEST_ID, MONTANT, DESIGNATION, USER_ID, "
      "MODE_PAIEMENT, NUM_CHEQUE, DATE_CHEQUE, TAUX_CHANGE, MONTANT_DEVISE) "
      "VALUES ('${movement.id}', '$dateStr', '${movement.compteSourceId}', '${movement.compteDestId}', "
      "${movement.montant}, '$designation', '$userId', "
      "$modeSql, $numChequeSql, $dateChequeSql, $tauxSql, $montantDeviseSql)",
    );
  }

  /// Update editable fields of an existing movement (date, montant, designation).
  Future<void> updateMovement(
    String id, {
    required DateTime date,
    required double montant,
    required String designation,
  }) async {
    _ensureConnected();
    final dateStr = toSqlDateTime(date);
    final des = designation.replaceAll("'", "''");
    await db.connection.connection!.execute(
      "UPDATE MOVEMENTS_TRISOIR "
      "SET DATE_MOV = '$dateStr', MONTANT = $montant, DESIGNATION = '$des' "
      "WHERE ID = '$id'",
    );
  }

  /// Delete a movement by ID, saving its complete details into JOURNAL_SUPPRESSION.
  Future<void> deleteMovement(String id, {String? userId}) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    // 1. Fetch the full movement with joined accounts before deleting
    final query = '''
      SELECT M.ID, M.DATE_MOV, M.COMPTE_SOURCE_ID, M.COMPTE_DEST_ID, M.MONTANT, M.DESIGNATION,
             SRC.CODE AS SRC_CODE, SRC.LIBELLE AS SRC_LIBELLE,
             DST.CODE AS DST_CODE, DST.LIBELLE AS DST_LIBELLE
      FROM MOVEMENTS_TRISOIR M
      LEFT JOIN COMPTES SRC ON SRC.ID = M.COMPTE_SOURCE_ID
      LEFT JOIN COMPTES DST ON DST.ID = M.COMPTE_DEST_ID
      WHERE M.ID = '$id'
    ''';
    final rows = await conn.execute(query);

    if (rows.isNotEmpty) {
      final r = rows.first;
      final suppId = Uuid.v4();
      final dateSuppStr = toSqlDateTime(DateTime.now());
      final movDate = _parseDate(r['DATE_MOV']);
      final movDateStr = toSqlDateTime(movDate);
      final montant = double.tryParse(r['MONTANT']?.toString().trim() ?? '0') ?? 0.0;
      final des = (r['DESIGNATION']?.toString().trim() ?? '').replaceAll("'", "''");
      final srcId = r['COMPTE_SOURCE_ID']?.toString().trim();
      final dstId = r['COMPTE_DEST_ID']?.toString().trim();
      final srcCode = (r['SRC_CODE']?.toString().trim() ?? '').replaceAll("'", "''");
      final srcLib = (r['SRC_LIBELLE']?.toString().trim() ?? '').replaceAll("'", "''");
      final dstCode = (r['DST_CODE']?.toString().trim() ?? '').replaceAll("'", "''");
      final dstLib = (r['DST_LIBELLE']?.toString().trim() ?? '').replaceAll("'", "''");

      final userSql = (userId != null && userId.isNotEmpty) ? "'$userId'" : 'NULL';
      final srcIdSql = (srcId != null && srcId.isNotEmpty) ? "'$srcId'" : 'NULL';
      final dstIdSql = (dstId != null && dstId.isNotEmpty) ? "'$dstId'" : 'NULL';
      final srcCodeSql = srcCode.isNotEmpty ? "'$srcCode'" : 'NULL';
      final srcLibSql = srcLib.isNotEmpty ? "'$srcLib'" : 'NULL';
      final dstCodeSql = dstCode.isNotEmpty ? "'$dstCode'" : 'NULL';
      final dstLibSql = dstLib.isNotEmpty ? "'$dstLib'" : 'NULL';

      // Insert audit record
      await conn.execute('''
        INSERT INTO JOURNAL_SUPPRESSION (
          ID, DATE_SUPPRESSION, USER_SUPPRESSION,
          MOV_ID, MOV_DATE, MOV_MONTANT, MOV_DESIGNATION,
          MOV_SOURCE_ID, MOV_DEST_ID,
          MOV_SOURCE_CODE, MOV_SOURCE_LIB,
          MOV_DEST_CODE, MOV_DEST_LIB
        ) VALUES (
          '$suppId', '$dateSuppStr', $userSql,
          '$id', '$movDateStr', $montant, '$des',
          $srcIdSql, $dstIdSql,
          $srcCodeSql, $srcLibSql,
          $dstCodeSql, $dstLibSql
        )
      ''');
    }

    // 2. Delete the movement
    await conn.execute("DELETE FROM MOVEMENTS_TRISOIR WHERE ID = '$id'");
  }

  /// Retrieve suppressed movement logs from JOURNAL_SUPPRESSION with optional caisse and date range filters.
  Future<List<JournalSuppressionEntry>> getJournalSuppression({
    String? caisseId,
    DateTime? from,
    DateTime? to,
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final conditions = <String>[];
    if (from != null) {
      conditions.add("DATE_SUPPRESSION >= '${toSqlDateTime(from)}'");
    }
    if (to != null) {
      conditions.add("DATE_SUPPRESSION <= '${toSqlDateTime(to.add(const Duration(days: 1)))}'");
    }
    if (caisseId != null && caisseId.isNotEmpty) {
      conditions.add("(MOV_SOURCE_ID = '$caisseId' OR MOV_DEST_ID = '$caisseId')");
    }

    final whereSql = conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}';

    final query = '''
      SELECT ID, DATE_SUPPRESSION, USER_SUPPRESSION,
             MOV_ID, MOV_DATE, MOV_MONTANT, MOV_DESIGNATION,
             MOV_SOURCE_ID, MOV_DEST_ID,
             MOV_SOURCE_CODE, MOV_SOURCE_LIB,
             MOV_DEST_CODE, MOV_DEST_LIB
      FROM JOURNAL_SUPPRESSION
      $whereSql
      ORDER BY DATE_SUPPRESSION ASC, ID ASC
    ''';
    final rows = await conn.execute(query);

    return rows.map((r) {
      return JournalSuppressionEntry(
        id: r['ID'].toString().trim(),
        dateSuppression: _parseDate(r['DATE_SUPPRESSION']),
        userSuppression: r['USER_SUPPRESSION']?.toString().trim(),
        movId: r['MOV_ID']?.toString().trim() ?? '',
        movDate: _parseDate(r['MOV_DATE']),
        movMontant: double.tryParse(r['MOV_MONTANT']?.toString().trim() ?? '0') ?? 0.0,
        movDesignation: r['MOV_DESIGNATION']?.toString().trim() ?? '',
        movSourceId: r['MOV_SOURCE_ID']?.toString().trim(),
        movDestId: r['MOV_DEST_ID']?.toString().trim(),
        movSourceCode: r['MOV_SOURCE_CODE']?.toString().trim(),
        movSourceLib: r['MOV_SOURCE_LIB']?.toString().trim(),
        movDestCode: r['MOV_DEST_CODE']?.toString().trim(),
        movDestLib: r['MOV_DEST_LIB']?.toString().trim(),
      );
    }).toList();
  }

  /// Insert a new account using NSM.
  /// [parentBg] and [parentBd] are the BG/BD of the chosen parent compte.
  /// If null, this is a root-level account inserted at the rightmost position.
  Future<void> createAccount(Compte account, {int? parentBg, int? parentBd}) async {
    _ensureConnected();
    final conn = db.connection.connection!;
    final libelle = account.libelle.replaceAll("'", "''");
    final compteFr = (account.compteFr ?? account.libelle).replaceAll("'", "''");
    final userSql = (account.userId == null || account.userId!.isEmpty) ? 'NULL' : "'${account.userId}'";

    // 1. Determine insert position
    final int insertPos;
    final int newNiveau;
    if (parentBd != null && parentBg != null) {
      // Refresh current parent's BD in case of concurrent updates
      final pRows = await conn.execute(
        'SELECT BD, NIVEAU FROM COMPTES WHERE BG = $parentBg',
      );
      final currentParentBd = pRows.isNotEmpty
          ? (int.tryParse(pRows.first['BD']?.toString().trim() ?? '') ?? parentBd)
          : parentBd;
      final currentParentNiv = pRows.isNotEmpty
          ? (int.tryParse(pRows.first['NIVEAU']?.toString().trim() ?? '') ?? 1)
          : 1;

      insertPos = currentParentBd; // insert at parent's right boundary
      newNiveau = currentParentNiv + 1;
    } else {
      final maxRow = await conn.execute(
        'SELECT COALESCE(MAX(BD), 0) AS MAXBD FROM COMPTES',
      );
      insertPos = (int.tryParse(maxRow.first['MAXBD']?.toString().trim() ?? '0') ?? 0) + 1;
      newNiveau = 1;
    }

    final newBg = insertPos;
    final newBd = insertPos + 1;

    // 2. Make room for new node (shift >= insertPos by +2)
    // Shift BD first, then BG
    await conn.execute('UPDATE COMPTES SET BD = BD + 2 WHERE BD >= $insertPos');
    await conn.execute('UPDATE COMPTES SET BG = BG + 2 WHERE BG >= $insertPos');

    final typeSql = account.typeCompte == null ? 'NULL' : "'${account.typeCompte!.toDbValue()}'";
    final deviseSql = account.isDevise ? "'O'" : "'N'";
    final codeDeviseSql = account.codeDevise != null && account.codeDevise!.trim().isNotEmpty
        ? "'${account.codeDevise!.replaceAll("'", "''").trim().toUpperCase()}'"
        : 'NULL';

    // 3. Insert new leaf node
    await conn.execute(
      "INSERT INTO COMPTES (ID, CODE, LIBELLE, COMPTE_FR, NIVEAU, BG, BD, USER_ID, TYPE_COMPTE, IS_DEVISE, CODE_DEVISE) "
      "VALUES ('${account.id}', '${account.code}', '$libelle', '$compteFr', $newNiveau, $newBg, $newBd, $userSql, $typeSql, $deviseSql, $codeDeviseSql)",
    );
  }

  /// Update basic account fields (code, libelle, compteFr, active, typeCompte, devise).
  /// Note: changing tree position should be done via [moveAccount].
  Future<void> updateAccount(Compte account) async {
    _ensureConnected();
    final conn = db.connection.connection!;
    final libelle = account.libelle.replaceAll("'", "''");
    final compteFr = (account.compteFr ?? account.libelle).replaceAll("'", "''");
    final activeChar = account.active ? 'O' : 'N';
    final typeSql = account.typeCompte == null ? 'NULL' : "'${account.typeCompte!.toDbValue()}'";
    final deviseSql = account.isDevise ? "'O'" : "'N'";
    final codeDeviseSql = account.codeDevise != null && account.codeDevise!.trim().isNotEmpty
        ? "'${account.codeDevise!.replaceAll("'", "''").trim().toUpperCase()}'"
        : 'NULL';

    await conn.execute(
      "UPDATE COMPTES SET "
      "CODE = '${account.code}', "
      "LIBELLE = '$libelle', "
      "COMPTE_FR = '$compteFr', "
      "IS_ACTIVE = '$activeChar', "
      "TYPE_COMPTE = $typeSql, "
      "IS_DEVISE = $deviseSql, "
      "CODE_DEVISE = $codeDeviseSql "
      "WHERE ID = '${account.id}'",
    );
  }

  /// Delete an account (and optionally its sub-tree if [deleteSubtree] is true).
  /// In standard accounting, parent accounts or accounts with movements should not be deleted.
  Future<void> deleteAccount(String accountId, {bool deleteSubtree = false}) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final accRows = await conn.execute(
      "SELECT CODE, BG, BD FROM COMPTES WHERE ID = '$accountId'",
    );
    if (accRows.isEmpty) {
      throw Exception('Compte introuvable (ID: $accountId)');
    }

    final code = accRows.first['CODE']?.toString().trim() ?? '';
    const mandatoryCodes = {'0', '5', '51', '512', '511', '5112', '53', '531', '445', '44566', '6', '7', '70', '71'};
    if (mandatoryCodes.contains(code) || code.startsWith('6')) {
      throw Exception('Le compte "$code" est un compte obligatoire du système et ne peut jamais être supprimé.');
    }

    final bg = int.parse(accRows.first['BG']!.toString().trim());
    final bd = int.parse(accRows.first['BD']!.toString().trim());
    final width = bd - bg + 1;

    if (!deleteSubtree && width > 2) {
      throw Exception('Impossible de supprimer un compte parent qui contient des sous-comptes.');
    }

    // 1. Delete node or subtree
    if (deleteSubtree) {
      // Clean up user access associations for accounts in the subtree
      await conn.execute('''
        DELETE FROM USER_CAISSE_ACCESS 
        WHERE COMPTE_ID IN (SELECT ID FROM COMPTES WHERE BG >= $bg AND BD <= $bd)
      ''');
      await conn.execute("DELETE FROM COMPTES WHERE BG >= $bg AND BD <= $bd");
    } else {
      await conn.execute("DELETE FROM USER_CAISSE_ACCESS WHERE COMPTE_ID = '$accountId'");
      await conn.execute("DELETE FROM COMPTES WHERE ID = '$accountId'");
    }

    // 2. Close the gap created in the tree
    await conn.execute("UPDATE COMPTES SET BD = BD - $width WHERE BD > $bd");
    await conn.execute("UPDATE COMPTES SET BG = BG - $width WHERE BG > $bd");
  }

  /// Move a node (and its entire subtree) to become a child of [targetParentId] (or root if null).
  /// Correctly recalculates BG, BD, and NIVEAU for the entire moved subtree and closes/opens gaps.
  Future<void> moveAccount(String accountId, {String? targetParentId}) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    // 1. Fetch node to move
    final nodeRows = await conn.execute(
      "SELECT CODE, BG, BD, NIVEAU FROM COMPTES WHERE ID = '$accountId'",
    );
    if (nodeRows.isEmpty) throw Exception('Compte source non trouvé.');

    final code = nodeRows.first['CODE']?.toString().trim() ?? '';
    if (code == '0') {
      throw Exception('Le compte racine TOUS LES COMPTES ne peut pas être déplacé.');
    }

    final nodeBg = int.parse(nodeRows.first['BG']!.toString().trim());
    final nodeBd = int.parse(nodeRows.first['BD']!.toString().trim());
    final nodeNiveau = int.parse(nodeRows.first['NIVEAU']!.toString().trim());
    final width = nodeBd - nodeBg + 1;

    // 2. Fetch target parent
    int targetBd;
    int targetNiveau;

    if (targetParentId != null && targetParentId.isNotEmpty) {
      final parentRows = await conn.execute(
        "SELECT BG, BD, NIVEAU FROM COMPTES WHERE ID = '$targetParentId'",
      );
      if (parentRows.isEmpty) throw Exception('Compte parent cible non trouvé.');

      final parentBg = int.parse(parentRows.first['BG']!.toString().trim());
      final parentBdVal = int.parse(parentRows.first['BD']!.toString().trim());
      final parentNiv = int.parse(parentRows.first['NIVEAU']!.toString().trim());

      // Cannot move a node into its own subtree
      if (parentBg >= nodeBg && parentBdVal <= nodeBd) {
        throw Exception('Impossible de déplacer un compte dans son propre sous-arbre.');
      }

      targetBd = parentBdVal;
      targetNiveau = parentNiv;
    } else {
      // Move to root level (end of tree)
      final maxRow = await conn.execute(
        'SELECT COALESCE(MAX(BD), 0) AS MAXBD FROM COMPTES',
      );
      targetBd = (int.tryParse(maxRow.first['MAXBD']?.toString().trim() ?? '0') ?? 0) + 1;
      targetNiveau = 0;
    }

    final int levelDelta = (targetNiveau + 1) - nodeNiveau;

    // 3. Mark the subtree being moved by making its boundaries negative
    // This protects it from the gap adjustments below.
    await conn.execute(
      "UPDATE COMPTES SET BG = 0 - BG, BD = 0 - BD, NIVEAU = NIVEAU + $levelDelta "
      "WHERE BG >= $nodeBg AND BD <= $nodeBd",
    );

    // 4. Close the old gap left by the moved subtree
    await conn.execute("UPDATE COMPTES SET BD = BD - $width WHERE BD > $nodeBd");
    await conn.execute("UPDATE COMPTES SET BG = BG - $width WHERE BG > $nodeBd");

    // 5. Compute the new insertion position in the shifted tree
    // If the target position was to the right of the old position, it was shifted left by width
    int insertPos = targetBd;
    if (targetBd > nodeBd) {
      insertPos = targetBd - width;
    }

    // 6. Make room at the new location
    await conn.execute("UPDATE COMPTES SET BD = BD + $width WHERE BD >= $insertPos");
    await conn.execute("UPDATE COMPTES SET BG = BG + $width WHERE BG >= $insertPos");

    // 7. Move the subtree into the newly opened space
    // Negative nodes now move to: insertPos + (originalBg - nodeBg)
    final int distance = insertPos - nodeBg;
    await conn.execute(
      "UPDATE COMPTES SET "
      "BG = 0 - BG + $distance, "
      "BD = 0 - BD + $distance "
      "WHERE BG < 0",
    );
  }

  /// Query all ancestors of an account (from root down to direct parent).
  Future<List<Compte>> getAncestors(String accountId) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final rows = await conn.execute('''
      SELECT P.ID, P.CODE, P.LIBELLE, P.COMPTE_FR, P.NIVEAU, P.BG, P.BD, P.IS_ACTIVE, P.USER_ID
      FROM COMPTES C
      JOIN COMPTES P ON P.BG < C.BG AND P.BD > C.BD
      WHERE C.ID = '$accountId'
      ORDER BY P.BG
    ''');

    return rows.map((r) => _mapRowToCompte(r)).toList();
  }

  /// Query all descendants of an account (its entire sub-tree).
  Future<List<Compte>> getDescendants(String accountId) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final rows = await conn.execute('''
      SELECT D.ID, D.CODE, D.LIBELLE, D.COMPTE_FR, D.NIVEAU, D.BG, D.BD, D.IS_ACTIVE, D.USER_ID
      FROM COMPTES P
      JOIN COMPTES D ON D.BG > P.BG AND D.BD < P.BD
      WHERE P.ID = '$accountId'
      ORDER BY D.BG
    ''');

    return rows.map((r) => _mapRowToCompte(r)).toList();
  }

  /// Query direct children of an account (niveau = parent.niveau + 1).
  Future<List<Compte>> getDirectChildren(String accountId) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final rows = await conn.execute('''
      SELECT C.ID, C.CODE, C.LIBELLE, C.COMPTE_FR, C.NIVEAU, C.BG, C.BD, C.IS_ACTIVE, C.USER_ID
      FROM COMPTES P
      JOIN COMPTES C ON C.BG > P.BG AND C.BD < P.BD AND C.NIVEAU = P.NIVEAU + 1
      WHERE P.ID = '$accountId'
      ORDER BY C.CODE
    ''');

    return rows.map((r) => _mapRowToCompte(r)).toList();
  }

  Compte _mapRowToCompte(Map<String, dynamic> row) {
    final activeRaw = (row['IS_ACTIVE'] ?? '').toString().trim().toUpperCase();
    return Compte(
      id: row['ID'].toString(),
      code: row['CODE'].toString().trim(),
      libelle: row['LIBELLE'].toString().trim(),
      compteFr: row['COMPTE_FR']?.toString().trim(),
      niveau: int.tryParse(row['NIVEAU']?.toString().trim() ?? '1') ?? 1,
      bg: int.tryParse(row['BG']?.toString().trim() ?? '0') ?? 0,
      bd: int.tryParse(row['BD']?.toString().trim() ?? '1') ?? 1,
      active: activeRaw.isEmpty || activeRaw == 'O',
      userId: row['USER_ID']?.toString().trim(),
      typeCompte: CompteType.fromString(row['TYPE_COMPTE']?.toString()),
    );
  }

  Future<bool> canDeleteAccount(String accountId) async {
    _ensureConnected();

    // 1. Check if this account has children using NSM (BD - BG > 1 means has children)
    final accRows = await db.connection.connection!.execute(
      "SELECT CODE, BG, BD FROM COMPTES WHERE ID = '$accountId'",
    );
    if (accRows.isEmpty) return false;
    final code = accRows.first['CODE']?.toString().trim() ?? '';
    if (code == '0') return false; // Root account cannot ever be deleted
    if (code == '6' || code.startsWith('6')) return false; // Charges accounts cannot ever be deleted
    final bg = int.tryParse(accRows.first['BG']?.toString().trim() ?? '0') ?? 0;
    final bd = int.tryParse(accRows.first['BD']?.toString().trim() ?? '0') ?? 0;
    if (bd - bg > 1) return false; // has children

    // 2. Check if has movements
    final movRows = await db.connection.connection!.execute(
      "SELECT COUNT(*) AS CNT FROM MOVEMENTS_TRISOIR WHERE COMPTE_SOURCE_ID = '$accountId' OR COMPTE_DEST_ID = '$accountId'",
    );
    final movCount = int.tryParse(movRows.first['CNT']?.toString().trim() ?? '0') ?? 0;
    if (movCount > 0) return false;

    return true;
  }

  // ============================================================
  // DEMANDES DE TRANSFERT
  // ============================================================

  Future<void> createDemandeTransfert(DemandeTransfert demande) async {
    _ensureConnected();
    final conn = db.connection.connection!;
    final dateStr = toSqlDateTime(demande.dateDemande);
    final des = demande.designation.replaceAll("'", "''");
    final nowStr = toSqlDateTime(DateTime.now());

    await conn.execute('''
      INSERT INTO DEMANDES_TRANSFERT (
        ID, DATE_DEMANDE, USER_DEMANDEUR_ID,
        COMPTE_SOURCE_ID, COMPTE_DEST_ID, MONTANT,
        DESIGNATION, STATUT, CREATED_AT, UPDATED_AT
      ) VALUES (
        '${demande.id}', '$dateStr', '${demande.userDemandeurId}',
        '${demande.compteSourceId}', '${demande.compteDestId}', ${demande.montant},
        '$des', '${demande.statut}', '$nowStr', '$nowStr'
      )
    ''');
  }

  Future<List<DemandeTransfert>> getDemandesTransfert({
    String? caisseId,
    String? statut,
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final conditions = <String>[];
    if (caisseId != null && caisseId.isNotEmpty) {
      conditions.add("(D.COMPTE_SOURCE_ID = '$caisseId' OR D.COMPTE_DEST_ID = '$caisseId')");
    }
    if (statut != null && statut.isNotEmpty) {
      conditions.add("D.STATUT = '$statut'");
    }

    final whereSql = conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}';
    final query = '''
      SELECT D.ID, D.DATE_DEMANDE, D.USER_DEMANDEUR_ID, D.COMPTE_SOURCE_ID, D.COMPTE_DEST_ID,
             D.MONTANT, D.DESIGNATION, D.STATUT, D.USER_VALIDEUR_ID, D.DATE_VALIDATION,
             D.MOTIF_REFUS, D.MOVEMENT_ID, D.CREATED_AT, D.UPDATED_AT,
             UD.USERNAME AS DEMANDEUR_NAME, UV.USERNAME AS VALIDEUR_NAME,
             SRC.CODE AS SRC_CODE, SRC.LIBELLE AS SRC_LIBELLE,
             DST.CODE AS DST_CODE, DST.LIBELLE AS DST_LIBELLE
      FROM DEMANDES_TRANSFERT D
      LEFT JOIN USERS UD ON UD.ID = D.USER_DEMANDEUR_ID
      LEFT JOIN USERS UV ON UV.ID = D.USER_VALIDEUR_ID
      LEFT JOIN COMPTES SRC ON SRC.ID = D.COMPTE_SOURCE_ID
      LEFT JOIN COMPTES DST ON DST.ID = D.COMPTE_DEST_ID
      $whereSql
      ORDER BY D.DATE_DEMANDE ASC, D.ID ASC
    ''';

    final rows = await conn.execute(query);

    return rows.map((r) {
      return DemandeTransfert(
        id: r['ID'].toString().trim(),
        dateDemande: _parseDate(r['DATE_DEMANDE']),
        userDemandeurId: r['USER_DEMANDEUR_ID'].toString().trim(),
        compteSourceId: r['COMPTE_SOURCE_ID'].toString().trim(),
        compteDestId: r['COMPTE_DEST_ID'].toString().trim(),
        montant: double.tryParse(r['MONTANT']?.toString().trim() ?? '0') ?? 0.0,
        designation: r['DESIGNATION']?.toString().trim() ?? '',
        statut: r['STATUT']?.toString().trim() ?? 'EN_ATTENTE',
        userValideurId: r['USER_VALIDEUR_ID']?.toString().trim(),
        dateValidation: r['DATE_VALIDATION'] != null ? _parseDate(r['DATE_VALIDATION']) : null,
        motifRefus: r['MOTIF_REFUS']?.toString().trim(),
        movementId: r['MOVEMENT_ID']?.toString().trim(),
        createdAt: _parseDate(r['CREATED_AT']),
        updatedAt: _parseDate(r['UPDATED_AT']),
        demandeurUsername: r['DEMANDEUR_NAME']?.toString().trim(),
        valideurUsername: r['VALIDEUR_NAME']?.toString().trim(),
        sourceCode: r['SRC_CODE']?.toString().trim(),
        sourceLibelle: r['SRC_LIBELLE']?.toString().trim(),
        destCode: r['DST_CODE']?.toString().trim(),
        destLibelle: r['DST_LIBELLE']?.toString().trim(),
      );
    }).toList();
  }

  Future<void> validerDemandeTransfert(
    String demandeId, {
    required String valideurUserId,
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    // 1. Get the transfer request
    final rows = await conn.execute("SELECT * FROM DEMANDES_TRANSFERT WHERE ID = '$demandeId'");
    if (rows.isEmpty) throw Exception('Demande de transfert non trouvée.');
    final r = rows.first;
    if (r['STATUT']?.toString().trim() != 'EN_ATTENTE') {
      throw Exception('Cette demande a déjà été traitée.');
    }

    final dateDemande = _parseDate(r['DATE_DEMANDE']);
    final srcId = r['COMPTE_SOURCE_ID'].toString().trim();
    final dstId = r['COMPTE_DEST_ID'].toString().trim();
    final montant = double.tryParse(r['MONTANT']?.toString().trim() ?? '0') ?? 0.0;
    final des = (r['DESIGNATION']?.toString().trim() ?? '').replaceAll("'", "''");

    // 2. Create the real movement in MOVEMENTS_TRISOIR
    final movementId = Uuid.v4();
    final movDateStr = toSqlDateTime(dateDemande);
    final movDesignation = 'Transfert validé: $des';

    await conn.execute('''
      INSERT INTO MOVEMENTS_TRISOIR (
        ID, DATE_MOV, COMPTE_SOURCE_ID, COMPTE_DEST_ID, MONTANT, DESIGNATION, USER_ID
      ) VALUES (
        '$movementId', '$movDateStr', '$srcId', '$dstId', $montant, '$movDesignation', '$valideurUserId'
      )
    ''');

    // 3. Mark request as VALIDEE
    final nowStr = toSqlDateTime(DateTime.now());
    await conn.execute('''
      UPDATE DEMANDES_TRANSFERT
      SET STATUT = 'VALIDEE',
          USER_VALIDEUR_ID = '$valideurUserId',
          DATE_VALIDATION = '$nowStr',
          MOVEMENT_ID = '$movementId',
          UPDATED_AT = '$nowStr'
      WHERE ID = '$demandeId'
    ''');
  }

  Future<void> refuserDemandeTransfert(
    String demandeId, {
    required String valideurUserId,
    required String motif,
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final nowStr = toSqlDateTime(DateTime.now());
    final motifClean = motif.replaceAll("'", "''");

    await conn.execute('''
      UPDATE DEMANDES_TRANSFERT
      SET STATUT = 'REFUSEE',
          USER_VALIDEUR_ID = '$valideurUserId',
          DATE_VALIDATION = '$nowStr',
          MOTIF_REFUS = '$motifClean',
          UPDATED_AT = '$nowStr'
      WHERE ID = '$demandeId' AND STATUT = 'EN_ATTENTE'
    ''');
  }
}
