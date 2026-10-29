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
  }) =>
      _dataSource.getFacturesVente(
        from: from,
        to: to,
        tiersId: tiersId,
        searchQuery: searchQuery,
      );

  Future<String> getNextNumFacture() => _dataSource.generateNextNumFacture();

  Future<FactureVente> createFactureVente({
    required String tiersId,
    required String numFacture,
    required DateTime dateFacture,
    required double montant,
    String? designation,
    required String userId,
  }) async {
    final facture = FactureVente(
      id: Uuid.v4(),
      tiersId: tiersId,
      numFacture: numFacture,
      dateFacture: dateFacture,
      montant: montant,
      designation: designation,
      userId: userId,
    );

    await _dataSource.createFactureVente(facture);
    return facture;
  }
}
