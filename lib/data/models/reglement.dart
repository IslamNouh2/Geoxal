class ReglementFacture {
  final String id;
  final String reglementId;
  final String factureType; // 'VENTE' ou 'ACHAT'
  final String factureId;
  final double montantApplique;
  final DateTime? createdAt;

  // Joined fields for display
  final String? numFacture;
  final DateTime? dateFacture;
  final double? montantFacture;

  const ReglementFacture({
    required this.id,
    required this.reglementId,
    required this.factureType,
    required this.factureId,
    required this.montantApplique,
    this.createdAt,
    this.numFacture,
    this.dateFacture,
    this.montantFacture,
  });

  factory ReglementFacture.fromMap(Map<String, dynamic> map) {
    return ReglementFacture(
      id: map['ID'].toString().trim(),
      reglementId: map['REGLEMENT_ID'].toString().trim(),
      factureType: map['FACTURE_TYPE'].toString().trim(),
      factureId: map['FACTURE_ID'].toString().trim(),
      montantApplique: double.tryParse(map['MONTANT_APPLIQUE']?.toString() ?? '0') ?? 0.0,
      createdAt: map['CREATED_AT'] == null ? null : DateTime.tryParse(map['CREATED_AT'].toString()),
      numFacture: map['NUM_FACTURE']?.toString().trim(),
      dateFacture: map['DATE_FACTURE'] == null ? null : DateTime.tryParse(map['DATE_FACTURE'].toString()),
      montantFacture: double.tryParse(map['MONTANT_FACTURE']?.toString() ?? '0'),
    );
  }
}

class Reglement {
  final String id;
  final String numReglement;
  final String typeReglement; // 'CLIENT' ou 'FOURNISSEUR'
  final String tiersId;
  final String compteCaisseId;
  final String? compteContrepartieId;
  final DateTime dateReglement;
  final double montant;
  final String modePaiement;
  final String? departementId;
  final String? numCheque;
  final DateTime? dateCheque;
  final String? observation;
  final String? movementTrisorId;
  final String userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined display fields
  final String? tiersNom;
  final String? caisseLibelle;
  final String? departementNom;
  final List<ReglementFacture> facturesLiees;

  const Reglement({
    required this.id,
    required this.numReglement,
    required this.typeReglement,
    required this.tiersId,
    required this.compteCaisseId,
    this.compteContrepartieId,
    required this.dateReglement,
    required this.montant,
    required this.modePaiement,
    this.departementId,
    this.numCheque,
    this.dateCheque,
    this.observation,
    this.movementTrisorId,
    required this.userId,
    this.createdAt,
    this.updatedAt,
    this.tiersNom,
    this.caisseLibelle,
    this.departementNom,
    this.facturesLiees = const [],
  });

  bool get isClient => typeReglement == 'CLIENT';
  bool get isFournisseur => typeReglement == 'FOURNISSEUR';

  factory Reglement.fromMap(Map<String, dynamic> map, {List<ReglementFacture> factures = const []}) {
    return Reglement(
      id: map['ID'].toString().trim(),
      numReglement: map['NUM_REGLEMENT'].toString().trim(),
      typeReglement: map['TYPE_REGLEMENT'].toString().trim(),
      tiersId: map['TIERS_ID'].toString().trim(),
      compteCaisseId: map['COMPTE_CAISSE_ID'].toString().trim(),
      compteContrepartieId: map['COMPTE_CONTREPARTIE_ID']?.toString().trim(),
      dateReglement: DateTime.tryParse(map['DATE_REGLEMENT'].toString()) ?? DateTime.now(),
      montant: double.tryParse(map['MONTANT']?.toString() ?? '0') ?? 0.0,
      modePaiement: map['MODE_PAIEMENT']?.toString().trim() ?? 'Espèces',
      departementId: map['DEPARTEMENT_ID']?.toString().trim(),
      numCheque: map['NUM_CHEQUE']?.toString().trim(),
      dateCheque: map['DATE_CHEQUE'] == null ? null : DateTime.tryParse(map['DATE_CHEQUE'].toString()),
      observation: map['OBSERVATION']?.toString().trim(),
      movementTrisorId: map['MOVEMENT_TRISOR_ID']?.toString().trim(),
      userId: map['USER_ID']?.toString().trim() ?? 'SYSTEM',
      createdAt: map['CREATED_AT'] == null ? null : DateTime.tryParse(map['CREATED_AT'].toString()),
      updatedAt: map['UPDATED_AT'] == null ? null : DateTime.tryParse(map['UPDATED_AT'].toString()),
      tiersNom: map['TIERS_NOM']?.toString().trim(),
      caisseLibelle: map['CAISSE_LIBELLE']?.toString().trim(),
      departementNom: map['DEPARTEMENT_NOM']?.toString().trim(),
      facturesLiees: factures,
    );
  }
}

