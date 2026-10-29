import '../../../core/utils/uuid.dart';
import '../datasources/tiers_datasource.dart';
import '../models/tiers.dart';

class TiersRepository {
  final TiersDataSource _dataSource;

  TiersRepository(this._dataSource);

  Future<List<Tiers>> getClients() => _dataSource.getTiers(typeId: 1);

  Future<List<Tiers>> getFournisseurs() => _dataSource.getTiers(typeId: 2);

  Future<List<Tiers>> getAllTiers() => _dataSource.getTiers();

  Future<Tiers> createTiers({
    required int idTypeClient,
    required String nom,
    String? rc,
    String? nif,
    String? ai,
    String? nis,
    String? adresse,
    String? telephone,
    String? email,
    String? userId,
  }) async {
    final tiers = Tiers(
      id: Uuid.v4(),
      idTypeClient: idTypeClient,
      nom: nom,
      rc: rc,
      nif: nif,
      ai: ai,
      nis: nis,
      adresse: adresse,
      telephone: telephone,
      email: email,
      userId: userId,
      typeLibelle: idTypeClient == 1 ? 'Client' : 'Fournisseur',
    );

    await _dataSource.createTiers(tiers);
    return tiers;
  }

  Future<void> updateTiers(Tiers tiers) => _dataSource.updateTiers(tiers);
}
