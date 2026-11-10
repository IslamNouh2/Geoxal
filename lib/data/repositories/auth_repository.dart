import '../../core/security/password_hasher.dart';
import '../datasources/user_datasource.dart';
import '../models/user.dart';

class AuthRepository {
  final UserDataSource _userDataSource;

  AuthRepository(this._userDataSource);

  Future<User?> login(String username, String password) async {
    final hashedPassword = PasswordHasher.hashPassword(password);
    return await _userDataSource.authenticate(username, hashedPassword);
  }

  Future<List<User>> getAllUsers() => _userDataSource.getAllUsers();

  Future<List<String>> getAssignedCaisseIds(String userId) =>
      _userDataSource.getAssignedCaisseIds(userId);

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
    bool canViewCharges = true,
    bool canCreateCharges = true,
    bool canUpdateCharges = true,
    bool canDeleteCharges = false,
    bool canViewRemises = true,
    bool canCreateRemises = true,
    bool canUpdateRemises = true,
    bool canDeleteRemises = false,
    List<String> assignedCaisseIds = const [],
  }) =>
      _userDataSource.createUser(
        username: username,
        password: password,
        role: role,
        canSeeAllCaisses: canSeeAllCaisses,
        canCreateMov: canCreateMov,
        canUpdateMov: canUpdateMov,
        canDeleteMov: canDeleteMov,
        canManageComptes: canManageComptes,
        canViewJournalSuppr: canViewJournalSuppr,
        canViewOldSolde: canViewOldSolde,
        canViewCustomers: canViewCustomers,
        canViewProducts: canViewProducts,
        canViewSales: canViewSales,
        canViewPurchases: canViewPurchases,
        canViewStock: canViewStock,
        canViewAccounting: canViewAccounting,
        canValidateTransfert: canValidateTransfert,
        canDeleteBankRules: canDeleteBankRules,
        canViewCharges: canViewCharges,
        canCreateCharges: canCreateCharges,
        canUpdateCharges: canUpdateCharges,
        canDeleteCharges: canDeleteCharges,
        canViewRemises: canViewRemises,
        canCreateRemises: canCreateRemises,
        canUpdateRemises: canUpdateRemises,
        canDeleteRemises: canDeleteRemises,
        assignedCaisseIds: assignedCaisseIds,
      );

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
    bool canViewCharges = true,
    bool canCreateCharges = true,
    bool canUpdateCharges = true,
    bool canDeleteCharges = false,
    bool canViewRemises = true,
    bool canCreateRemises = true,
    bool canUpdateRemises = true,
    bool canDeleteRemises = false,
    List<String>? assignedCaisseIds,
    String? newPassword,
  }) =>
      _userDataSource.updateUser(
        userId,
        role: role,
        isActive: isActive,
        canSeeAllCaisses: canSeeAllCaisses,
        canCreateMov: canCreateMov,
        canUpdateMov: canUpdateMov,
        canDeleteMov: canDeleteMov,
        canManageComptes: canManageComptes,
        canViewJournalSuppr: canViewJournalSuppr,
        canViewOldSolde: canViewOldSolde,
        canViewCustomers: canViewCustomers,
        canViewProducts: canViewProducts,
        canViewSales: canViewSales,
        canViewPurchases: canViewPurchases,
        canViewStock: canViewStock,
        canViewAccounting: canViewAccounting,
        canValidateTransfert: canValidateTransfert,
        canDeleteBankRules: canDeleteBankRules,
        canViewCharges: canViewCharges,
        canCreateCharges: canCreateCharges,
        canUpdateCharges: canUpdateCharges,
        canDeleteCharges: canDeleteCharges,
        canViewRemises: canViewRemises,
        canCreateRemises: canCreateRemises,
        canUpdateRemises: canUpdateRemises,
        canDeleteRemises: canDeleteRemises,
        assignedCaisseIds: assignedCaisseIds,
        newPassword: newPassword,
      );

  Future<void> deleteUser(String userId) => _userDataSource.deleteUser(userId);
}
