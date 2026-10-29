import '../../../data/models/compte.dart';
import '../../../data/models/demande_transfert.dart';
import '../../../data/models/journal_suppression_entry.dart';
import '../../../data/models/movement.dart';
import '../../../data/repositories/finance_repository.dart';

class AccountingController {
  final FinanceRepository _repository;

  AccountingController(this._repository);

  Future<List<Compte>> loadAccounts() => _repository.getAccounts();

  Future<Set<String>> loadAccountIdsWithMovements() =>
      _repository.getAccountIdsWithMovements();

  Future<List<Movement>> loadMovements({
    String? accountId,
    String? caisseId,
    String? compteId,
    int? compteBg,
    int? compteBd,
    Set<String>? allowedCaisseIds,
    DateTime? from,
    DateTime? to,
  }) =>
      _repository.getMovements(
        accountId: accountId,
        caisseId: caisseId,
        compteId: compteId,
        compteBg: compteBg,
        compteBd: compteBd,
        allowedCaisseIds: allowedCaisseIds,
        from: from,
        to: to,
      );

  Future<FinanceStats> loadStats({
    String? accountId,
    DateTime? from,
    DateTime? to,
  }) =>
      _repository.getStats(accountId: accountId, from: from, to: to);

  Future<Map<String, Map<String, dynamic>>> loadCaissesSummary({
    required List<String> caisseIds,
    DateTime? from,
    DateTime? to,
  }) =>
      _repository.getCaissesSummary(caisseIds: caisseIds, from: from, to: to);

  Future<Map<String, dynamic>> loadChargesStatistics({
    String? caisseId,
    Set<String>? allowedCaisseIds,
    DateTime? from,
    DateTime? to,
  }) =>
      _repository.getChargesStatistics(
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
  }) =>
      _repository.createMovement(
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

  Future<void> updateMovement(
    String id, {
    required DateTime date,
    required double montant,
    required String designation,
  }) =>
      _repository.updateMovement(id, date: date, montant: montant, designation: designation);

  Future<void> deleteMovement(String id, {String? userId}) =>
      _repository.deleteMovement(id, userId: userId);

  Future<List<JournalSuppressionEntry>> loadJournalSuppression({
    String? caisseId,
    DateTime? from,
    DateTime? to,
  }) =>
      _repository.getJournalSuppression(caisseId: caisseId, from: from, to: to);

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
      _repository.createAccount(
        code: code,
        libelle: libelle,
        compteFr: compteFr,
        parentCompte: parentCompte,
        userId: userId,
        typeCompte: typeCompte,
        isDevise: isDevise,
        codeDevise: codeDevise,
      );

  Future<void> updateAccount(Compte account) =>
      _repository.updateAccount(account);

  Future<void> deleteAccount(String accountId, {bool deleteSubtree = false}) =>
      _repository.deleteAccount(accountId, deleteSubtree: deleteSubtree);

  Future<void> moveAccount(String accountId, {String? targetParentId}) =>
      _repository.moveAccount(accountId, targetParentId: targetParentId);

  Future<List<Compte>> getAncestors(String accountId) =>
      _repository.getAncestors(accountId);

  Future<List<Compte>> getDescendants(String accountId) =>
      _repository.getDescendants(accountId);

  Future<List<Compte>> getDirectChildren(String accountId) =>
      _repository.getDirectChildren(accountId);

  Future<bool> canDeleteAccount(String accountId) =>
      _repository.canDeleteAccount(accountId);

  Future<void> createDemandeTransfert({
    required DateTime dateDemande,
    required String userDemandeurId,
    required String compteSourceId,
    required String compteDestId,
    required double montant,
    required String designation,
  }) =>
      _repository.createDemandeTransfert(
        dateDemande: dateDemande,
        userDemandeurId: userDemandeurId,
        compteSourceId: compteSourceId,
        compteDestId: compteDestId,
        montant: montant,
        designation: designation,
      );

  Future<List<DemandeTransfert>> loadDemandesTransfert({
    String? caisseId,
    String? statut,
  }) =>
      _repository.getDemandesTransfert(caisseId: caisseId, statut: statut);

  Future<void> validerDemandeTransfert(
    String demandeId, {
    required String valideurUserId,
  }) =>
      _repository.validerDemandeTransfert(demandeId, valideurUserId: valideurUserId);

  Future<void> refuserDemandeTransfert(
    String demandeId, {
    required String valideurUserId,
    required String motif,
  }) =>
      _repository.refuserDemandeTransfert(demandeId, valideurUserId: valideurUserId, motif: motif);
}
