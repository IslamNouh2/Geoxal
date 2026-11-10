import '../../../core/utils/uuid.dart';
import '../datasources/achat_datasource.dart';
import '../models/facture_achat.dart';

class AchatRepository {
  final AchatDataSource _dataSource;

  AchatRepository(this._dataSource);

  Future<List<FactureAchat>> getFacturesAchat({
    DateTime? from,
    DateTime? to,
    String? tiersId,
    String? searchQuery,
  }) {
    return _dataSource.getFacturesAchat(
      from: from,
      to: to,
      tiersId: tiersId,
      searchQuery: searchQuery,
    );
  }

  Future<String> getNextNumFacture() {
    return _dataSource.generateNextNumFacture();
  }

  /// Creates a new Facture Achat.
  ///
  /// If [numFacture] is null or empty the number is auto-generated via
  /// [generateNextNumFacture] (used when a non-admin saves the form).
  /// Admin users may supply a custom [numFacture].
  ///
  /// Returns the actual invoice number that was saved.
  Future<String> createFactureAchat({
    required String tiersId,
    String? numFacture,
    String? numFactureFournisseur,
    required DateTime dateFacture,
    required double montant,
    String? designation,
    required String userId,
    String? departementId,
    String? compteId,
    String? modePaiement,
    String typeAchat = 'ACHAT',
  }) async {
    // Auto-generate when not provided or blank (non-admin path)
    final resolvedNum = (numFacture == null || numFacture.trim().isEmpty)
        ? await _dataSource.generateNextNumFacture()
        : numFacture.trim();

    final fa = FactureAchat(
      id: Uuid.v4(),
      tiersId: tiersId,
      numFacture: resolvedNum,
      numFactureFournisseur: numFactureFournisseur?.trim().isEmpty == true ? null : numFactureFournisseur?.trim(),
      dateFacture: dateFacture,
      montant: montant,
      designation: designation,
      userId: userId,
      departementId: departementId,
      compteId: compteId,
      modePaiement: modePaiement,
      typeAchat: typeAchat,
    );
    await _dataSource.createFactureAchat(fa);
    return resolvedNum;
  }
}
