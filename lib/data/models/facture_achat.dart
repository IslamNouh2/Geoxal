/// Purchase invoice corresponding to Table Facture_achat in database.md.
class FactureAchat {
  final String id;
  final String tiersId;
  final String numFacture;
  final String? numFactureFournisseur; // N° facture du fournisseur (référence externe)
  final DateTime dateFacture;
  final double montant;
  final String? designation;
  final String userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? departementId;
  final String? compteId;
  final String? modePaiement;
  final String typeAchat; // 'ACHAT' ou 'CHARGE'

  // Joined display helpers
  final String? fournisseurNom;
  final String? fournisseurTelephone;
  final String? fournisseurEmail;
  final String? departementNom;
  final String? compteLibelle;
  final double montantRegle;

  const FactureAchat({
    required this.id,
    required this.tiersId,
    required this.numFacture,
    this.numFactureFournisseur,
    required this.dateFacture,
    required this.montant,
    this.designation,
    required this.userId,
    this.createdAt,
    this.updatedAt,
    this.departementId,
    this.compteId,
    this.modePaiement,
    this.typeAchat = 'ACHAT',
    this.fournisseurNom,
    this.fournisseurTelephone,
    this.fournisseurEmail,
    this.departementNom,
    this.compteLibelle,
    this.montantRegle = 0.0,
  });

  bool get isCharge => typeAchat.toUpperCase() == 'CHARGE';
  double get resteAPayer => (montant - montantRegle) > 0.001 ? montant - montantRegle : 0.0;
  bool get isSoldee => resteAPayer <= 0.001;
}
