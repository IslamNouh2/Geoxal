import '../../../core/utils/uuid.dart';
import '../../data/datasources/finance_datasource.dart';
import '../../data/models/compte.dart';
import '../../data/models/demande_transfert.dart';
import '../../data/models/journal_suppression_entry.dart';
import '../../data/models/movement.dart';

class FinanceRepository {
  final FinanceDataSource _dataSource;

  FinanceRepository(this._dataSource);

  Future<List<Compte>> getAccounts() => _dataSource.getAccounts();

  Future<Set<String>> getAccountIdsWithMovements() =>
      _dataSource.getAccountIdsWithMovements();

  Future<List<Movement>> getMovements({
    String? accountId,
    String? caisseId,
    String? compteId,
    int? compteBg,
    int? compteBd,
    Set<String>? allowedCaisseIds,
    DateTime? from,
    DateTime? to,
  }) =>
      _dataSource.getMovements(
        accountId: accountId,
        caisseId: caisseId,
        compteId: compteId,
        compteBg: compteBg,
        compteBd: compteBd,
        allowedCaisseIds: allowedCaisseIds,
        from: from,
        to: to,
      );

  Future<FinanceStats> getStats({
    String? accountId,
    DateTime? from,
    DateTime? to,
  }) =>
      _dataSource.getStats(accountId: accountId, from: from, to: to);

  Future<Map<String, Map<String, dynamic>>> getCaissesSummary({
    required List<String> caisseIds,
    DateTime? from,
    DateTime? to,
  }) =>
      _dataSource.getCaissesSummary(caisseIds: caisseIds, from: from, to: to);

  Future<Map<String, dynamic>> getChargesStatistics({
    String? caisseId,
    Set<String>? allowedCaisseIds,
    DateTime? from,
    DateTime? to,
  }) =>
      _dataSource.getChargesStatistics(
        caisseId: caisseId,
        allowedCaisseIds: allowedCaisseIds,
        from: from,
        to: to,
      );

  Future<void> createMovement({
    required DateTime date,
    required String compteSourceId,
    required String compteDestId,
    required double montant,
    required String designation,
    String? userId,
    String? modePaiement,
    String? numCheque,
    DateTime? dateCheque,
    double? tauxChange,
    double? montantDevise,
  }) async {
    final movement = Movement(
      id: Uuid.v4(),
      date: date,
      compteSourceId: compteSourceId,
      compteDestId: compteDestId,
      montant: montant,
      designation: designation,
      userId: userId,
      modePaiement: modePaiement,
      numCheque: numCheque,
      dateCheque: dateCheque,
      tauxChange: tauxChange,
      montantDevise: montantDevise,
    );
    await _dataSource.createMovement(movement);
  }

  Future<void> updateMovement(
    String id, {
    required DateTime date,
    required double montant,
    required String designation,
  }) =>
    _dataSource.updateMovement(id, date: date, montant: montant, designation: designation);

  Future<void> deleteMovement(String id, {String? userId}) =>
      _dataSource.deleteMovement(id, userId: userId);

  Future<List<JournalSuppressionEntry>> getJournalSuppression({
    String? caisseId,
    DateTime? from,
    DateTime? to,
  }) =>
      _dataSource.getJournalSuppression(caisseId: caisseId, from: from, to: to);

  /// Create a new account as a child of [parentCompte] (or root if null).
  /// Uses NSM: passes parent's BG/BD so the datasource can shift existing nodes.
  Future<void> createAccount({
    required String code,
    required String libelle,
    String? compteFr,
    Compte? parentCompte,
    String? userId,
    CompteType? typeCompte,
    bool isDevise = false,
    String? codeDevise,
  }) =>
      _dataSource.createAccount(
        Compte(
          id: Uuid.v4(),
          code: code,
          libelle: libelle,
          compteFr: compteFr ?? libelle,
          niveau: parentCompte == null ? 1 : parentCompte.niveau + 1,
          bg: 0, // will be computed by datasource
          bd: 1, // will be computed by datasource
          userId: userId,
          typeCompte: typeCompte,
          isDevise: isDevise,
          codeDevise: codeDevise,
        ),
        parentBg: parentCompte?.bg,
        parentBd: parentCompte?.bd,
      );

  Future<void> updateAccount(Compte account) =>
      _dataSource.updateAccount(account);

  Future<void> deleteAccount(String accountId, {bool deleteSubtree = false}) =>
      _dataSource.deleteAccount(accountId, deleteSubtree: deleteSubtree);

  Future<void> moveAccount(String accountId, {String? targetParentId}) =>
      _dataSource.moveAccount(accountId, targetParentId: targetParentId);

  Future<List<Compte>> getAncestors(String accountId) =>
      _dataSource.getAncestors(accountId);

  Future<List<Compte>> getDescendants(String accountId) =>
      _dataSource.getDescendants(accountId);

  Future<List<Compte>> getDirectChildren(String accountId) =>
      _dataSource.getDirectChildren(accountId);

  Future<bool> canDeleteAccount(String accountId) =>
      _dataSource.canDeleteAccount(accountId);

  // Demandes de transfert
  Future<void> createDemandeTransfert({
    required DateTime dateDemande,
    required String userDemandeurId,
    required String compteSourceId,
    required String compteDestId,
    required double montant,
    required String designation,
  }) {
    final now = DateTime.now();
    final demande = DemandeTransfert(
      id: Uuid.v4(),
      dateDemande: dateDemande,
      userDemandeurId: userDemandeurId,
      compteSourceId: compteSourceId,
      compteDestId: compteDestId,
      montant: montant,
      designation: designation,
      statut: 'EN_ATTENTE',
      createdAt: now,
      updatedAt: now,
    );
    return _dataSource.createDemandeTransfert(demande);
  }

  Future<List<DemandeTransfert>> getDemandesTransfert({
    String? caisseId,
    String? statut,
  }) =>
      _dataSource.getDemandesTransfert(caisseId: caisseId, statut: statut);

  Future<void> validerDemandeTransfert(
    String demandeId, {
    required String valideurUserId,
  }) =>
      _dataSource.validerDemandeTransfert(demandeId, valideurUserId: valideurUserId);

  Future<void> refuserDemandeTransfert(
    String demandeId, {
    required String valideurUserId,
    required String motif,
  }) =>
      _dataSource.refuserDemandeTransfert(demandeId, valideurUserId: valideurUserId, motif: motif);
}
