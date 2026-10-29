/// Sales invoice corresponding to Table Facture_vente in database.md.
class FactureVente {
  final String id;
  final String tiersId;
  final String numFacture;
  final DateTime dateFacture;
  final double montant;
  final String? designation;
  final String userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined display helpers
  final String? clientNom;
  final String? clientTelephone;
  final String? clientEmail;

  const FactureVente({
    required this.id,
    required this.tiersId,
    required this.numFacture,
    required this.dateFacture,
    required this.montant,
    this.designation,
    required this.userId,
    this.createdAt,
    this.updatedAt,
    this.clientNom,
    this.clientTelephone,
    this.clientEmail,
  });
}
