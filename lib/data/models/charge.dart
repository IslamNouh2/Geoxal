enum CategorieCharge {
  simple,
  amortisable;

  String toDbValue() {
    switch (this) {
      case CategorieCharge.simple:
        return 'SIMPLE';
      case CategorieCharge.amortisable:
        return 'AMORTISSABLE';
    }
  }

  static CategorieCharge fromDbValue(String? value) {
    switch (value?.trim().toUpperCase()) {
      case 'SIMPLE':
        return CategorieCharge.simple;
      case 'AMORTISSABLE':
        return CategorieCharge.amortisable;
      default:
        throw FormatException('Categorie Charge inconnue: $value');
    }
  }
}

enum ChargePaymentStatus {
  unpaid,
  partiallyPaid,
  paid;

  static ChargePaymentStatus fromAmounts(double total, double paid) {
    if (paid <= 0.001) return ChargePaymentStatus.unpaid;
    if (paid >= total - 0.001) return ChargePaymentStatus.paid;
    return ChargePaymentStatus.partiallyPaid;
  }

  String get label {
    switch (this) {
      case ChargePaymentStatus.unpaid:
        return 'Non payée';
      case ChargePaymentStatus.partiallyPaid:
        return 'Partiellement payée';
      case ChargePaymentStatus.paid:
        return 'Payée';
    }
  }

  // Backwards compatibility alias
  String get lable => label;
}

class Charge {
  final String id;
  final String userId;
  final DateTime dateCreation;
  final DateTime? dateModification;

  final String referance;
  final DateTime dateCharge;

  final String compteId;
  final String? compteCode;
  final String? compteLibelle;

  final CategorieCharge categorie;
  final String currencyCode;
  final double? tauxChange;

  final bool amortissable;

  // SIMPLE: consumption period.
  final DateTime? dateDebutConsommation;
  final DateTime? dateFinConsommation;

  // AMORTISSABLE: amortization period.
  final DateTime? dateDebutAmortissement;
  final DateTime? dateFinAmortissement;

  /// Legacy/optional treasury movement reference.
  /// Multi-payment relationship is stored in DETAIL_MVT_CHARGES.
  final String? mouvementTresorerieId;

  final String? observation;
  final double montantCharge;
  final double montantRegle;
  final String designation;

  const Charge({
    required this.id,
    required this.userId,
    required this.dateCreation,
    this.dateModification,
    required this.referance,
    required this.dateCharge,
    required this.compteId,
    this.compteCode,
    this.compteLibelle,
    required this.categorie,
    this.currencyCode = 'DZD',
    this.tauxChange,
    required this.amortissable,
    this.dateDebutConsommation,
    this.dateFinConsommation,
    this.dateDebutAmortissement,
    this.dateFinAmortissement,
    this.mouvementTresorerieId,
    this.observation,
    required this.montantCharge,
    this.montantRegle = 0,
    required this.designation,
  });

  double get netAPayer => montantCharge;
  double get netAPyer => netAPayer;

  double get resteARegler {
    final remaining = montantCharge - montantRegle;
    return remaining > 0 ? remaining : 0;
  }
  double get restARegle => resteARegler;

  ChargePaymentStatus get paymentStatus =>
      ChargePaymentStatus.fromAmounts(montantCharge, montantRegle);

  bool get isPaid => resteARegler <= 0.001;

  // Backward compatibility aliases
  String get idCharge => id;
  String get refCharge => referance;
  bool get isSimple => categorie == CategorieCharge.simple;
  bool get isAmortissable => categorie == CategorieCharge.amortisable;
  String get categorieCharge => categorie.toDbValue();


  Charge copyWith({
    String? id,
    String? userId,
    DateTime? dateCreation,
    DateTime? dateModification,
    String? referance,
    DateTime? dateCharge,
    String? compteId,
    String? compteCode,
    String? compteLibelle,
    CategorieCharge? categorie,
    String? currencyCode,
    double? tauxChange,
    bool? amortissable,
    DateTime? dateDebutConsommation,
    DateTime? dateFinConsommation,
    DateTime? dateDebutAmortissement,
    DateTime? dateFinAmortissement,
    String? mouvementTresorerieId,
    String? observation,
    double? montantCharge,
    double? montantRegle,
    String? designation,
  }) {
    return Charge(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dateCreation: dateCreation ?? this.dateCreation,
      dateModification: dateModification ?? this.dateModification,
      referance: referance ?? this.referance,
      dateCharge: dateCharge ?? this.dateCharge,
      compteId: compteId ?? this.compteId,
      compteCode: compteCode ?? this.compteCode,
      compteLibelle: compteLibelle ?? this.compteLibelle,
      categorie: categorie ?? this.categorie,
      currencyCode: currencyCode ?? this.currencyCode,
      tauxChange: tauxChange ?? this.tauxChange,
      amortissable: amortissable ?? this.amortissable,
      dateDebutConsommation: dateDebutConsommation ?? this.dateDebutConsommation,
      dateFinConsommation: dateFinConsommation ?? this.dateFinConsommation,
      dateDebutAmortissement: dateDebutAmortissement ?? this.dateDebutAmortissement,
      dateFinAmortissement: dateFinAmortissement ?? this.dateFinAmortissement,
      mouvementTresorerieId: mouvementTresorerieId ?? this.mouvementTresorerieId,
      observation: observation ?? this.observation,
      montantCharge: montantCharge ?? this.montantCharge,
      montantRegle: montantRegle ?? this.montantRegle,
      designation: designation ?? this.designation,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static double _number(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? fallback;
  }

  factory Charge.forMap(Map<String, dynamic> row) {
    final category = CategorieCharge.fromDbValue(
      row['CATEGORIE_CHARGE']?.toString(),
    );

    return Charge(
      id: row['ID_CHARGE'].toString().trim(),
      userId: row['USER_ID'].toString().trim(),
      dateCreation: _date(row['DATE_CREAT']) ?? DateTime.now(),
      dateModification: _date(row['DATE_MODIF']),
      referance: row['REF_CHARGE']?.toString().trim() ?? '',
      dateCharge: _date(row['DATE_CHARGE']) ?? DateTime.now(),
      compteId: row['COMPTE_ID'].toString().trim(),
      compteCode: row['COMPTE_CODE']?.toString().trim(),
      compteLibelle: row['COMPTE_LIBELLE']?.toString().trim(),
      categorie: category,
      currencyCode: row['CURRENCY_CODE']?.toString().trim() ?? 'DZD',
      tauxChange: row['TAUX_CHANGE'] == null
          ? null
          : _number(row['TAUX_CHANGE']),
      amortissable: category == CategorieCharge.amortisable,
      dateDebutConsommation: _date(row['DATE_DEBUT_CONSOMMATION']),
      dateFinConsommation: _date(row['DATE_FIN_CONSOMMATION']),
      dateDebutAmortissement: _date(row['DATE_DEBUT_AMORTISSEMENT']),
      dateFinAmortissement: _date(row['DATE_FIN_AMORTISSEMENT']),
      mouvementTresorerieId: row['ID_MVT_TRESOR']?.toString().trim(),
      observation: row['OBSERVATION']?.toString().trim(),
      montantCharge: _number(row['MONTANT_CHARGE']),
      montantRegle: _number(row['MONTANT_REGLE']),
      designation: row['DESIGNATION']?.toString().trim() ?? '',
    );
  }

  factory Charge.fromMap(Map<String, dynamic> row) => Charge.forMap(row);
}
