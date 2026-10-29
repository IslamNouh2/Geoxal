/// Purchase invoice corresponding to Table Facture_achat in database.md.
class FactureAchat {
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
  final String? fournisseurNom;
  final String? fournisseurTelephone;
  final String? fournisseurEmail;

  const FactureAchat({
    required this.id,
    required this.tiersId,
    required this.numFacture,
    required this.dateFacture,
    required this.montant,
    this.designation,
    required this.userId,
    this.createdAt,
    this.updatedAt,
    this.fournisseurNom,
    this.fournisseurTelephone,
    this.fournisseurEmail,
  });
}
