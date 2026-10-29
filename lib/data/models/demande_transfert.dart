class DemandeTransfert {
  final String id;
  final DateTime dateDemande;
  final String userDemandeurId;
  final String compteSourceId;
  final String compteDestId;
  final double montant;
  final String designation;
  final String statut; // 'EN_ATTENTE', 'VALIDEE', 'REFUSEE'
  final String? userValideurId;
  final DateTime? dateValidation;
  final String? motifRefus;
  final String? movementId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields for display
  final String? demandeurUsername;
  final String? valideurUsername;
  final String? sourceCode;
  final String? sourceLibelle;
  final String? destCode;
  final String? destLibelle;

  const DemandeTransfert({
    required this.id,
    required this.dateDemande,
    required this.userDemandeurId,
    required this.compteSourceId,
    required this.compteDestId,
    required this.montant,
    required this.designation,
    this.statut = 'EN_ATTENTE',
    this.userValideurId,
    this.dateValidation,
    this.motifRefus,
    this.movementId,
    required this.createdAt,
    required this.updatedAt,
    this.demandeurUsername,
    this.valideurUsername,
    this.sourceCode,
    this.sourceLibelle,
    this.destCode,
    this.destLibelle,
  });

  bool get isEnAttente => statut == 'EN_ATTENTE';
  bool get isValidee => statut == 'VALIDEE';
  bool get isRefusee => statut == 'REFUSEE';

  String get sourceDisplayName =>
      sourceCode != null ? '$sourceCode - ${sourceLibelle ?? ''}' : compteSourceId;
  String get destDisplayName =>
      destCode != null ? '$destCode - ${destLibelle ?? ''}' : compteDestId;
}
