import '../../core/database/database.dart';
import '../../core/security/password_hasher.dart';
import '../../core/utils/uuid.dart';
import '../models/user.dart';

class UserDataSource {
  final Database db;

  UserDataSource(this.db);

  void _ensureConnected() {
    if (!db.connection.isConnected || db.connection.connection == null) {
      throw Exception('Database not connected.');
    }
  }

  Future<User?> authenticate(String username, String passwordHash) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final safeUsername = username.replaceAll("'", "''");
    final safeHash = passwordHash.replaceAll("'", "''");
    final result = await conn.execute(
      "SELECT ID, USERNAME, ROLE, IS_ACTIVE, CAN_SEE_ALL_CAISSES, "
      "CAN_CREATE_MOV, CAN_UPDATE_MOV, CAN_DELETE_MOV, CAN_MANAGE_COMPTES, CAN_VIEW_JOURNAL_SUPPR, CAN_VIEW_OLD_SOLDE, "
      "CAN_VIEW_CUSTOMERS, CAN_VIEW_PRODUCTS, CAN_VIEW_SALES, CAN_VIEW_PURCHASES, CAN_VIEW_STOCK, CAN_VIEW_ACCOUNTING, "
      "CAN_VALIDATE_TRANSFERT, CAN_DELETE_BANK_RULES "
      "FROM USERS WHERE USERNAME = '$safeUsername' AND PASSWORD_HASH = '$safeHash' AND IS_ACTIVE = 'O'",
    );

    if (result.isNotEmpty) {
      final row = result.first;
      final userId = row['ID'].toString().trim();
      final assignedCaisses = await getAssignedCaisseIds(userId);

      return User(
        id: userId,
        username: row['USERNAME'].toString().trim(),
        role: row['ROLE'].toString().trim(),
        isActive: (row['IS_ACTIVE']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canSeeAllCaisses: (row['CAN_SEE_ALL_CAISSES']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canCreateMov: (row['CAN_CREATE_MOV']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canUpdateMov: (row['CAN_UPDATE_MOV']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canDeleteMov: (row['CAN_DELETE_MOV']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canManageComptes: (row['CAN_MANAGE_COMPTES']?.toString().trim().toUpperCase() ?? 'N') == 'O',
        canViewJournalSuppr: (row['CAN_VIEW_JOURNAL_SUPPR']?.toString().trim().toUpperCase() ?? 'N') == 'O',
        canViewOldSolde: (row['CAN_VIEW_OLD_SOLDE']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canViewCustomers: (row['CAN_VIEW_CUSTOMERS']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canViewProducts: (row['CAN_VIEW_PRODUCTS']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canViewSales: (row['CAN_VIEW_SALES']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canViewPurchases: (row['CAN_VIEW_PURCHASES']?.toString().trim().toUpperCase() ?? 'O') == 'O',
        canViewStock: rowVal(row['CAN_VIEW_STOCK']) != 'N',
        canViewAccounting: rowVal(row['CAN_VIEW_ACCOUNTING']) != 'N',
        canValidateTransfert: rowVal(row['CAN_VALIDATE_TRANSFERT']) == 'O',
        canDeleteBankRules: rowVal(row['CAN_DELETE_BANK_RULES']) == 'O',
        assignedCaisseIds: assignedCaisses,
      );
    }

    return null;
  }

  Future<List<User>> getAllUsers() async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final rows = await conn.execute(
      "SELECT ID, USERNAME, ROLE, IS_ACTIVE, CAN_SEE_ALL_CAISSES, "
      "CAN_CREATE_MOV, CAN_UPDATE_MOV, CAN_DELETE_MOV, CAN_MANAGE_COMPTES, CAN_VIEW_JOURNAL_SUPPR, CAN_VIEW_OLD_SOLDE, "
      "CAN_VIEW_CUSTOMERS, CAN_VIEW_PRODUCTS, CAN_VIEW_SALES, CAN_VIEW_PURCHASES, CAN_VIEW_STOCK, CAN_VIEW_ACCOUNTING, "
      "CAN_VALIDATE_TRANSFERT, CAN_DELETE_BANK_RULES "
      "FROM USERS ORDER BY USERNAME ASC",
    );

    final users = <User>[];
    for (final r in rows) {
      final userId = r['ID'].toString().trim();
      final assignedCaisses = await getAssignedCaisseIds(userId);
      users.add(
        User(
          id: userId,
          username: r['USERNAME'].toString().trim(),
          role: r['ROLE'].toString().trim(),
          isActive: (r['IS_ACTIVE']?.toString().trim().toUpperCase() ?? 'O') == 'O',
          canSeeAllCaisses: (r['CAN_SEE_ALL_CAISSES']?.toString().trim().toUpperCase() ?? 'O') == 'O',
          canCreateMov: (r['CAN_CREATE_MOV']?.toString().trim().toUpperCase() ?? 'O') == 'O',
          canUpdateMov: (r['CAN_UPDATE_MOV']?.toString().trim().toUpperCase() ?? 'O') == 'O',
          canDeleteMov: (r['CAN_DELETE_MOV']?.toString().trim().toUpperCase() ?? 'O') == 'O',
          canManageComptes: (rowVal(r['CAN_MANAGE_COMPTES']) == 'O'),
          canViewJournalSuppr: (rowVal(r['CAN_VIEW_JOURNAL_SUPPR']) == 'O'),
          canViewOldSolde: (rowVal(r['CAN_VIEW_OLD_SOLDE']) != 'N'),
          canViewCustomers: (rowVal(r['CAN_VIEW_CUSTOMERS']) != 'N'),
          canViewProducts: (rowVal(r['CAN_VIEW_PRODUCTS']) != 'N'),
          canViewSales: (rowVal(r['CAN_VIEW_SALES']) != 'N'),
          canViewPurchases: (rowVal(r['CAN_VIEW_PURCHASES']) != 'N'),
          canViewStock: (rowVal(r['CAN_VIEW_STOCK']) != 'N'),
          canViewAccounting: (rowVal(r['CAN_VIEW_ACCOUNTING']) != 'N'),
          canValidateTransfert: (rowVal(r['CAN_VALIDATE_TRANSFERT']) == 'O'),
          canDeleteBankRules: (rowVal(r['CAN_DELETE_BANK_RULES']) == 'O'),
          assignedCaisseIds: assignedCaisses,
        ),
      );
    }
    return users;
  }

  static String rowVal(dynamic v) => (v?.toString().trim().toUpperCase() ?? 'N');

  Future<List<String>> getAssignedCaisseIds(String userId) async {
    _ensureConnected();
    final conn = db.connection.connection!;
    final rows = await conn.execute(
      "SELECT COMPTE_ID FROM USER_CAISSE_ACCESS WHERE USER_ID = '$userId'",
    );
    return rows.map((r) => r['COMPTE_ID'].toString().trim()).toList();
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String role,
    bool canSeeAllCaisses = true,
    bool canCreateMov = true,
    bool canUpdateMov = true,
    bool canDeleteMov = true,
    bool canManageComptes = false,
    bool canViewJournalSuppr = false,
    bool canViewOldSolde = true,
    bool canViewCustomers = true,
    bool canViewProducts = true,
    bool canViewSales = true,
    bool canViewPurchases = true,
    bool canViewStock = true,
    bool canViewAccounting = true,
    bool canValidateTransfert = true,
    bool canDeleteBankRules = false,
    List<String> assignedCaisseIds = const [],
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final id = Uuid.v4();
    final safeUsername = username.replaceAll("'", "''");
    final passwordHash = PasswordHasher.hashPassword(password);
    final seeAll = canSeeAllCaisses ? 'O' : 'N';
    final crtMov = canCreateMov ? 'O' : 'N';
    final updMov = canUpdateMov ? 'O' : 'N';
    final delMov = canDeleteMov ? 'O' : 'N';
    final mngCmp = canManageComptes ? 'O' : 'N';
    final viewJrn = canViewJournalSuppr ? 'O' : 'N';
    final viewOld = canViewOldSolde ? 'O' : 'N';
    final viewCust = canViewCustomers ? 'O' : 'N';
    final viewProd = canViewProducts ? 'O' : 'N';
    final viewSale = canViewSales ? 'O' : 'N';
    final viewPurc = canViewPurchases ? 'O' : 'N';
    final viewStk = canViewStock ? 'O' : 'N';
    final viewAcct = canViewAccounting ? 'O' : 'N';
    final valTrans = canValidateTransfert ? 'O' : 'N';
    final delRules = canDeleteBankRules ? 'O' : 'N';

    await conn.execute('''
      INSERT INTO USERS (
        ID, USERNAME, PASSWORD_HASH, ROLE, IS_ACTIVE,
        CAN_SEE_ALL_CAISSES, CAN_CREATE_MOV, CAN_UPDATE_MOV, CAN_DELETE_MOV, CAN_MANAGE_COMPTES, CAN_VIEW_JOURNAL_SUPPR, CAN_VIEW_OLD_SOLDE,
        CAN_VIEW_CUSTOMERS, CAN_VIEW_PRODUCTS, CAN_VIEW_SALES, CAN_VIEW_PURCHASES, CAN_VIEW_STOCK, CAN_VIEW_ACCOUNTING,
        CAN_VALIDATE_TRANSFERT, CAN_DELETE_BANK_RULES
      ) VALUES (
        '$id', '$safeUsername', '$passwordHash', '$role', 'O',
        '$seeAll', '$crtMov', '$updMov', '$delMov', '$mngCmp', '$viewJrn', '$viewOld',
        '$viewCust', '$viewProd', '$viewSale', '$viewPurc', '$viewStk', '$viewAcct',
        '$valTrans', '$delRules'
      )
    ''');

    // Assign caisses if restricted
    if (!canSeeAllCaisses && assignedCaisseIds.isNotEmpty) {
      for (final cid in assignedCaisseIds) {
        final accessId = Uuid.v4();
        await conn.execute(
          "INSERT INTO USER_CAISSE_ACCESS (ID, USER_ID, COMPTE_ID) VALUES ('$accessId', '$id', '$cid')",
        );
      }
    }
  }

  Future<void> updateUser(
    String userId, {
    required String role,
    required bool isActive,
    required bool canSeeAllCaisses,
    required bool canCreateMov,
    required bool canUpdateMov,
    required bool canDeleteMov,
    required bool canManageComptes,
    required bool canViewJournalSuppr,
    required bool canViewOldSolde,
    bool canViewCustomers = true,
    bool canViewProducts = true,
    bool canViewSales = true,
    bool canViewPurchases = true,
    bool canViewStock = true,
    bool canViewAccounting = true,
    bool canValidateTransfert = true,
    bool canDeleteBankRules = false,
    List<String>? assignedCaisseIds,
    String? newPassword,
  }) async {
    _ensureConnected();
    final conn = db.connection.connection!;

    final activeSql = isActive ? 'O' : 'N';
    final seeAllSql = canSeeAllCaisses ? 'O' : 'N';
    final crtMovSql = canCreateMov ? 'O' : 'N';
    final updMovSql = canUpdateMov ? 'O' : 'N';
    final delMovSql = canDeleteMov ? 'O' : 'N';
    final mngCmpSql = canManageComptes ? 'O' : 'N';
    final viewJrnSql = canViewJournalSuppr ? 'O' : 'N';
    final viewOldSql = canViewOldSolde ? 'O' : 'N';
    final viewCustSql = canViewCustomers ? 'O' : 'N';
    final viewProdSql = canViewProducts ? 'O' : 'N';
    final viewSaleSql = canViewSales ? 'O' : 'N';
    final viewPurcSql = canViewPurchases ? 'O' : 'N';
    final viewStkSql = canViewStock ? 'O' : 'N';
    final viewAcctSql = canViewAccounting ? 'O' : 'N';
    final valTransSql = canValidateTransfert ? 'O' : 'N';
    final delRulesSql = canDeleteBankRules ? 'O' : 'N';

    final updateFields = '''
      ROLE = '$role',
      IS_ACTIVE = '$activeSql',
      CAN_SEE_ALL_CAISSES = '$seeAllSql',
      CAN_CREATE_MOV = '$crtMovSql',
      CAN_UPDATE_MOV = '$updMovSql',
      CAN_DELETE_MOV = '$delMovSql',
      CAN_MANAGE_COMPTES = '$mngCmpSql',
      CAN_VIEW_JOURNAL_SUPPR = '$viewJrnSql',
      CAN_VIEW_OLD_SOLDE = '$viewOldSql',
      CAN_VIEW_CUSTOMERS = '$viewCustSql',
      CAN_VIEW_PRODUCTS = '$viewProdSql',
      CAN_VIEW_SALES = '$viewSaleSql',
      CAN_VIEW_PURCHASES = '$viewPurcSql',
      CAN_VIEW_STOCK = '$viewStkSql',
      CAN_VIEW_ACCOUNTING = '$viewAcctSql',
      CAN_VALIDATE_TRANSFERT = '$valTransSql',
      CAN_DELETE_BANK_RULES = '$delRulesSql',
      UPDATED_AT = CURRENT_TIMESTAMP
    ''';

    if (newPassword != null && newPassword.trim().isNotEmpty) {
      final newHash = PasswordHasher.hashPassword(newPassword.trim());
      await conn.execute('''
        UPDATE USERS SET
          $updateFields,
          PASSWORD_HASH = '$newHash'
        WHERE ID = '$userId'
      ''');
    } else {
      await conn.execute('''
        UPDATE USERS SET
          $updateFields
        WHERE ID = '$userId'
      ''');
    }

    if (assignedCaisseIds != null) {
      await conn.execute("DELETE FROM USER_CAISSE_ACCESS WHERE USER_ID = '$userId'");
      if (!canSeeAllCaisses) {
        for (final cid in assignedCaisseIds) {
          final accessId = Uuid.v4();
          await conn.execute(
            "INSERT INTO USER_CAISSE_ACCESS (ID, USER_ID, COMPTE_ID) VALUES ('$accessId', '$userId', '$cid')",
          );
        }
      }
    }
  }

  Future<void> deleteUser(String userId) async {
    _ensureConnected();
    final conn = db.connection.connection!;
    await conn.execute("DELETE FROM USER_CAISSE_ACCESS WHERE USER_ID = '$userId'");
    await conn.execute("DELETE FROM USERS WHERE ID = '$userId'");
  }
}
