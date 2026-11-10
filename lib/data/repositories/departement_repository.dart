import '../datasources/departement_datasource.dart';
import '../models/departement.dart';

class DepartementRepository {
  final DepartementDataSource _dataSource;

  DepartementRepository(this._dataSource);

  Future<List<Departement>> getDepartements({bool onlyActive = false}) =>
      _dataSource.getDepartements(onlyActive: onlyActive);

  Future<void> createDepartement({
    required String code,
    required String nom,
    String? description,
    bool isActive = true,
  }) =>
      _dataSource.createDepartement(
        code: code,
        nom: nom,
        description: description,
        isActive: isActive,
      );

  Future<void> updateDepartement({
    required String id,
    required String code,
    required String nom,
    String? description,
    bool isActive = true,
  }) =>
      _dataSource.updateDepartement(
        id: id,
        code: code,
        nom: nom,
        description: description,
        isActive: isActive,
      );

  Future<void> deleteDepartement(String id) => _dataSource.deleteDepartement(id);
}

