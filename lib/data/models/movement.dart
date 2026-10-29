/// Treasury movement corresponding to Table MovementsTrisor in database.md.
class Movement {
  final String id;
  final DateTime date;
  final String compteSourceId; // Compte sortant (origin account)
  final String compteDestId; // Compte entrant (destination account)
  final double montant;
  final String designation;
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Payment mode, cheque and foreign currency fields
  final String? modePaiement; // 'Espèces', 'Chèque', 'Virement bancaire', 'Versement bancaire'
  final String? numCheque;
  final DateTime? dateCheque;
  final double? tauxChange;
  final double? montantDevise;

  // Joined/resolved helper fields for display
  final String? sourceCode;
  final String? sourceLibelle;
  final String? destCode;
  final String? destLibelle;

  const Movement({
    required this.id,
    required this.date,
    required this.compteSourceId,
    required this.compteDestId,
    required this.montant,
    required this.designation,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.modePaiement,
    this.numCheque,
    this.dateCheque,
    this.tauxChange,
    this.montantDevise,
    this.sourceCode,
    this.sourceLibelle,
    this.destCode,
    this.destLibelle,
  });

  String get sourceDisplayName =>
      sourceCode != null ? '$sourceCode - ${sourceLibelle ?? ''}' : compteSourceId;

  String get destDisplayName =>
      destCode != null ? '$destCode - ${destLibelle ?? ''}' : compteDestId;
}

/// Aggregated stats for treasury (cash/bank session) with initial cumulative balance
class FinanceStats {
  final double soldeInitial; // Cumul des mouvements avant la date de début sélectionnée
  final double totalSorties; // Dépenses / Sorties de la période
  final double totalEntrees; // Versements / Entrées de la période
  final double totalMontant;
  final int countMovements;

  // Devise equivalents (sum of MONTANT_DEVISE for movements that have it)
  final double deviseInitial;
  final double deviseEntrees;
  final double deviseSorties;

  const FinanceStats({
    this.soldeInitial = 0,
    this.totalSorties = 0,
    this.totalEntrees = 0,
    this.totalMontant = 0,
    this.countMovements = 0,
    this.deviseInitial = 0,
    this.deviseEntrees = 0,
    this.deviseSorties = 0,
  });

  /// Variation nette des flux sur la période choisie (Entrées - Sorties)
  double get variationPeriode => totalEntrees - totalSorties;

  /// Solde final = Solde Initial + Entrées de la période - Sorties de la période
  double get soldeFinal => soldeInitial + variationPeriode;

  /// Solde final en devise
  double get deviseSoldeFinal => deviseInitial + deviseEntrees - deviseSorties;

  /// Legacy alias
  double get soldeNet => variationPeriode;

  static const zero = FinanceStats();
}
