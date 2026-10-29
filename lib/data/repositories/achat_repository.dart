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
  }) =>
      _dataSource.getFacturesAchat(
        from: from,
        to: to,
        tiersId: tiersId,
        searchQuery: searchQuery,
      );

  Future<String> getNextNumFacture() => _dataSource.generateNextNumFacture();

  Future<FactureAchat> createFactureAchat({
    required String tiersId,
    required String numFacture,
    required DateTime dateFacture,
    required double montant,
    String? designation,
    required String userId,
  }) async {
    final facture = FactureAchat(
      id: Uuid.v4(),
      tiersId: tiersId,
      numFacture: numFacture,
      dateFacture: dateFacture,
      montant: montant,
      designation: designation,
      userId: userId,
    );

    await _dataSource.createFactureAchat(facture);
    return facture;
  }
}
