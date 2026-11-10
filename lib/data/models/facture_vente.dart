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
  final String? departementId;
  final String? compteId;
  final String? modePaiement;

  // Joined display helpers
  final String? clientNom;
  final String? clientTelephone;
  final String? clientEmail;
  final String? departementNom;
  final String? compteLibelle;
  final double montantRegle;

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
    this.departementId,
    this.compteId,
    this.modePaiement,
    this.clientNom,
    this.clientTelephone,
    this.clientEmail,
    this.departementNom,
    this.compteLibelle,
    this.montantRegle = 0.0,
  });

  double get resteAPayer => (montant - montantRegle) > 0.001 ? montant - montantRegle : 0.0;
  bool get isSoldee => resteAPayer <= 0.001;
}
