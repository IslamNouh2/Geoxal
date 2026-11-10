import '../../../data/models/charge.dart';
import '../../../data/models/compte.dart';
import '../../../data/repositories/charges_repository.dart';

class ChargesController {
  final ChargesRepository _repository;

  ChargesController(this._repository);

  Future<List<Charge>> loadCharges({
    String? compteId,
    String? categorie,
    DateTime? dateDebut,
    DateTime? dateFin,
    bool? reglee,
    String? searchQuery,
  }) =>
      _repository.getCharges(
        compteId: compteId,
        categorie: categorie,
        dateDebut: dateDebut,
        dateFin: dateFin,
        reglee: reglee,
        searchQuery: searchQuery,
      );

  Future<Charge?> getChargeById(String id) => _repository.getChargeById(id);

  Future<String> getNextReference() => _repository.generateNextRefCharge();

  Future<List<Compte>> loadExpenseAccounts() => _repository.getExpenseAccounts();

  Future<List<Compte>> loadTreasuryPaymentAccounts() =>
      _repository.getTreasuryPaymentAccounts();

  Future<void> saveCharge(Charge charge, {required bool isNew}) {
    if (isNew) {
      return _repository.createCharge(charge);
    } else {
      return _repository.updateCharge(charge);
    }
  }

  Future<void> deleteCharge(String chargeId) => _repository.deleteCharge(chargeId);

  /// Returns the MOVEMENTS_TRISOIR ID linked to this auto-charge, or null.
  Future<String?> getAutoLinkedMovementId(String chargeId) =>
      _repository.getAutoLinkedMovementId(chargeId);

  /// Returns the auto-charge linked to a trésorerie movement, or null.
  Future<({String chargeId, String detailId})?> getAutoChargeForMovement(String mvtId) =>
      _repository.getAutoChargeForMovement(mvtId);

  /// Deletes a DETAIL_MVT_CHARGES entry by its ID.
  Future<void> deleteDetailMvtCharge(String detailId) =>
      _repository.deleteDetailMvtCharge(detailId);

  /// Deletes a MOVEMENTS_TRISOIR entry (cascade from charge deletion).
  Future<void> deleteMovement(String mvtId) =>
      _repository.deleteMovement(mvtId);

  Future<List<Map<String, dynamic>>> loadChargePaymentDetails(String chargeId) =>
      _repository.getChargePaymentDetails(chargeId);

  Future<void> payCharge({
    required Charge charge,
    required String sourceCaisseId,
    required double montant,
    required DateTime datePaiement,
    required String modePaiement,
    String? numCheque,
    DateTime? dateCheque,
    String? observation,
    required String userId,
  }) =>
      _repository.addPayment(
        charge: charge,
        sourceCaisseId: sourceCaisseId,
        montant: montant,
        datePaiement: datePaiement,
        modePaiement: modePaiement,
        numCheque: numCheque,
        dateCheque: dateCheque,
        observation: observation,
        userId: userId,
      );
}


