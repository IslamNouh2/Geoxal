/// Tiers entity corresponding to Table Tiers in database.md.
class Tiers {
  final String id;
  final int idTypeClient; // 1 = Client, 2 = Fournisseur
  final String nom;
  final String? rc;
  final String? nif;
  final String? ai;
  final String? nis;
  final String? adresse;
  final String? telephone;
  final String? email;
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? typeLibelle; // 'Client' or 'Fournisseur'

  const Tiers({
    required this.id,
    required this.idTypeClient,
    required this.nom,
    this.rc,
    this.nif,
    this.ai,
    this.nis,
    this.adresse,
    this.telephone,
    this.email,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.typeLibelle,
  });

  bool get isClient => idTypeClient == 1;
  bool get isFournisseur => idTypeClient == 2;
}
