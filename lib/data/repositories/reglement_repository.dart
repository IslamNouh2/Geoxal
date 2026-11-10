import '../datasources/reglement_datasource.dart';
import '../models/client_situation.dart';
import '../models/reglement.dart';

class ReglementRepository {
  final ReglementDataSource _dataSource;

  ReglementRepository(this._dataSource);

  Future<String> generateNextNumReglement(String typeReglement) =>
      _dataSource.generateNextNumReglement(typeReglement);

  Future<List<Reglement>> getReglements({
    String? typeReglement,
    String? tiersId,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  }) =>
      _dataSource.getReglements(
        typeReglement: typeReglement,
        tiersId: tiersId,
        from: from,
        to: to,
        searchQuery: searchQuery,
      );

  Future<List<ReglementFacture>> getFacturesForReglement(String reglementId) =>
      _dataSource.getFacturesForReglement(reglementId);

  Future<ClientSituation> getClientSituation(String tiersId) =>
      _dataSource.getClientSituation(tiersId);

  Future<String> createReglement({
    required String typeReglement,
    required String tiersId,
    required String compteCaisseId,
    String? compteContrepartieId,
    required DateTime dateReglement,
    required double montant,
    required String modePaiement,
    String? departementId,
    String? numCheque,
    DateTime? dateCheque,
    String? observation,
    required String userId,
    required List<Map<String, dynamic>> allocations,
  }) =>
      _dataSource.createReglement(
        typeReglement: typeReglement,
        tiersId: tiersId,
        compteCaisseId: compteCaisseId,
        compteContrepartieId: compteContrepartieId,
        dateReglement: dateReglement,
        montant: montant,
        modePaiement: modePaiement,
        departementId: departementId,
        numCheque: numCheque,
        dateCheque: dateCheque,
        observation: observation,
        userId: userId,
        allocations: allocations,
      );

  Future<void> updateReglement({
    required String reglementId,
    required DateTime dateReglement,
    required double montant,
    required String modePaiement,
    required String compteCaisseId,
    String? departementId,
    String? numCheque,
    DateTime? dateCheque,
    String? observation,
    required List<Map<String, dynamic>> allocations,
  }) =>
      _dataSource.updateReglement(
        reglementId: reglementId,
        dateReglement: dateReglement,
        montant: montant,
        modePaiement: modePaiement,
        compteCaisseId: compteCaisseId,
        departementId: departementId,
        numCheque: numCheque,
        dateCheque: dateCheque,
        observation: observation,
        allocations: allocations,
      );
}

