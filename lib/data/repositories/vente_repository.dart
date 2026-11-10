import '../../../core/utils/uuid.dart';
import '../datasources/vente_datasource.dart';
import '../models/facture_vente.dart';

class VenteRepository {
  final VenteDataSource _dataSource;

  VenteRepository(this._dataSource);

  Future<List<FactureVente>> getFacturesVente({
    DateTime? from,
    DateTime? to,
    String? tiersId,
    String? searchQuery,
  }) {
    return _dataSource.getFacturesVente(
      from: from,
      to: to,
      tiersId: tiersId,
      searchQuery: searchQuery,
    );
  }

  Future<String> getNextNumFacture() {
    return _dataSource.generateNextNumFacture();
  }

  /// Creates a new Facture Vente.
  ///
  /// If [numFacture] is null or empty the number is auto-generated via
  /// [generateNextNumFacture] (used when a non-admin saves the form).
  /// Admin users may supply a custom [numFacture].
  ///
  /// Returns the actual invoice number that was saved.
  Future<String> createFactureVente({
    required String tiersId,
    String? numFacture,
    required DateTime dateFacture,
    required double montant,
    String? designation,
    required String userId,
    String? departementId,
    String? compteId,
    String? modePaiement,
  }) async {
    // Auto-generate when not provided or blank (non-admin path)
    final resolvedNum = (numFacture == null || numFacture.trim().isEmpty)
        ? await _dataSource.generateNextNumFacture()
        : numFacture.trim();

    final fv = FactureVente(
      id: Uuid.v4(),
      tiersId: tiersId,
      numFacture: resolvedNum,
      dateFacture: dateFacture,
      montant: montant,
      designation: designation,
      userId: userId,
      departementId: departementId,
      compteId: compteId,
      modePaiement: modePaiement,
    );
    await _dataSource.createFactureVente(fv);
    return resolvedNum;
  }
}
