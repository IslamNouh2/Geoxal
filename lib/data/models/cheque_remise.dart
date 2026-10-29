enum ChequeStatus {
  enPortefeuille('EN_PORTEFEUILLE', 'En portefeuille'),
  dansRemise('DANS_REMISE', 'Dans remise (brouillon)'),
  remisEnBanque('REMIS_EN_BANQUE', 'Remis en banque'),
  encaisse('ENCAISSE', 'Encaissé'),
  impaye('IMPAYE', 'Impayé'),
  annule('ANNULE', 'Annulé');

  final String code;
  final String label;
  const ChequeStatus(this.code, this.label);

  static ChequeStatus fromString(String? val) {
    if (val == null) return ChequeStatus.enPortefeuille;
    final clean = val.trim().toUpperCase();
    for (final s in ChequeStatus.values) {
      if (s.code == clean) return s;
    }
    return ChequeStatus.enPortefeuille;
  }
}

class Cheque {
  final String id;
  final String chequeNumber;
  final double montant;
  final String tiersId;
  final String? draweeBankCompteId; // FK COMPTES si dans le plan comptable
  final String draweeBankName;     // Nom / code banque (BNA, BADR, Housing, etc.)
  final DateTime issueDate;
  final DateTime? dueDate;         // Échéance si postdaté
  final String? factureVenteId;
  final String? remiseId;
  final ChequeStatus status;
  final String? notes;
  final String userId;

  // Joined display helpers
  final String? clientNom;
  final String? draweeBankCompteLibelle;
  final String? numFacture;

  const Cheque({
    required this.id,
    required this.chequeNumber,
    required this.montant,
    required this.tiersId,
    this.draweeBankCompteId,
    required this.draweeBankName,
    required this.issueDate,
    this.dueDate,
    this.factureVenteId,
    this.remiseId,
    this.status = ChequeStatus.enPortefeuille,
    this.notes,
    required this.userId,
    this.clientNom,
    this.draweeBankCompteLibelle,
    this.numFacture,
  });

  bool get isPostDated => dueDate != null && dueDate!.isAfter(DateTime.now());

  factory Cheque.fromMap(Map<String, dynamic> map) {
    DateTime parseDt(dynamic val) {
      if (val is DateTime) return val;
      final str = val?.toString().trim() ?? '';
      return DateTime.tryParse(str) ?? DateTime.now();
    }

    return Cheque(
      id: map['ID'].toString(),
      chequeNumber: map['CHEQUE_NUMBER'].toString().trim(),
      montant: double.tryParse(map['MONTANT']?.toString() ?? '0') ?? 0.0,
      tiersId: map['TIERS_ID'].toString().trim(),
      draweeBankCompteId: map['DRAWEE_BANK_COMPTE_ID']?.toString().trim(),
      draweeBankName: (map['DRAWEE_BANK_NAME'] ?? '').toString().trim(),
      issueDate: parseDt(map['ISSUE_DATE']),
      dueDate: map['DUE_DATE'] != null ? parseDt(map['DUE_DATE']) : null,
      factureVenteId: map['FACTURE_VENTE_ID']?.toString().trim(),
      remiseId: map['REMISE_ID']?.toString().trim(),
      status: ChequeStatus.fromString(map['STATUS']?.toString()),
      notes: map['NOTES']?.toString().trim(),
      userId: map['USER_ID'].toString().trim(),
      clientNom: map['CLIENT_NOM']?.toString().trim(),
      draweeBankCompteLibelle: map['DRAWEE_BANK_LIBELLE']?.toString().trim(),
      numFacture: map['NUM_FACTURE']?.toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'CHEQUE_NUMBER': chequeNumber,
      'MONTANT': montant,
      'TIERS_ID': tiersId,
      'DRAWEE_BANK_COMPTE_ID': draweeBankCompteId,
      'DRAWEE_BANK_NAME': draweeBankName,
      'ISSUE_DATE': issueDate.toIso8601String(),
      'DUE_DATE': dueDate?.toIso8601String(),
      'FACTURE_VENTE_ID': factureVenteId,
      'REMISE_ID': remiseId,
      'STATUS': status.code,
      'NOTES': notes,
      'USER_ID': userId,
    };
  }
}

enum RemiseStatus {
  brouillon('BROUILLON', 'Brouillon'),
  validee('VALIDEE', 'Validée'),
  annulee('ANNULEE', 'Annulée');

  final String code;
  final String label;
  const RemiseStatus(this.code, this.label);

  static RemiseStatus fromString(String? val) {
    if (val == null) return RemiseStatus.brouillon;
    final clean = val.trim().toUpperCase();
    for (final s in RemiseStatus.values) {
      if (s.code == clean) return s;
    }
    return RemiseStatus.brouillon;
  }
}

class RemiseCheque {
  final String id;
  final String bordereauNumber;
  final DateTime dateRemise;
  final String bankCompteId;       // FK COMPTES (compte banque)
  final double totalAmount;
  final int chequesCount;
  final RemiseStatus status;
  final String? notes;
  final String? movementTrisorId;
  final String createdBy;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  // Joined display
  final String? bankCompteCode;
  final String? bankCompteLabel;
  final List<Cheque>? cheques;
  final List<BankTransactionFee>? fees;

  const RemiseCheque({
    required this.id,
    required this.bordereauNumber,
    required this.dateRemise,
    required this.bankCompteId,
    this.totalAmount = 0.0,
    this.chequesCount = 0,
    this.status = RemiseStatus.brouillon,
    this.notes,
    this.movementTrisorId,
    required this.createdBy,
    this.validatedBy,
    this.validatedAt,
    this.cancelledBy,
    this.cancelledAt,
    this.bankCompteCode,
    this.bankCompteLabel,
    this.cheques,
    this.fees,
  });

  bool get isLocked => status != RemiseStatus.brouillon;

  factory RemiseCheque.fromMap(Map<String, dynamic> map) {
    DateTime parseDt(dynamic val) {
      if (val is DateTime) return val;
      final str = val?.toString().trim() ?? '';
      return DateTime.tryParse(str) ?? DateTime.now();
    }

    return RemiseCheque(
      id: map['ID'].toString(),
      bordereauNumber: map['BORDEREAU_NUMBER'].toString().trim(),
      dateRemise: parseDt(map['DATE_REMISE']),
      bankCompteId: map['BANK_COMPTE_ID'].toString().trim(),
      totalAmount: double.tryParse(map['TOTAL_AMOUNT']?.toString() ?? '0') ?? 0.0,
      chequesCount: int.tryParse(map['CHEQUES_COUNT']?.toString() ?? '0') ?? 0,
      status: RemiseStatus.fromString(map['STATUS']?.toString()),
      notes: map['NOTES']?.toString().trim(),
      movementTrisorId: map['MOVEMENT_TRISOR_ID']?.toString().trim(),
      createdBy: map['CREATED_BY'].toString().trim(),
      validatedBy: map['VALIDATED_BY']?.toString().trim(),
      validatedAt: map['VALIDATED_AT'] != null ? parseDt(map['VALIDATED_AT']) : null,
      cancelledBy: map['CANCELLED_BY']?.toString().trim(),
      cancelledAt: map['CANCELLED_AT'] != null ? parseDt(map['CANCELLED_AT']) : null,
      bankCompteCode: map['BANK_CODE']?.toString().trim(),
      bankCompteLabel: map['BANK_LABEL']?.toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'BORDEREAU_NUMBER': bordereauNumber,
      'DATE_REMISE': dateRemise.toIso8601String(),
      'BANK_COMPTE_ID': bankCompteId,
      'TOTAL_AMOUNT': totalAmount,
      'CHEQUES_COUNT': chequesCount,
      'STATUS': status.code,
      'NOTES': notes,
      'MOVEMENT_TRISOR_ID': movementTrisorId,
      'CREATED_BY': createdBy,
      'VALIDATED_BY': validatedBy,
      'VALIDATED_AT': validatedAt?.toIso8601String(),
      'CANCELLED_BY': cancelledBy,
      'CANCELLED_AT': cancelledAt?.toIso8601String(),
    };
  }
}

class BankTransactionFee {
  final String id;
  final String? remiseId;
  final String? movementTrisorId;
  final String? ruleId;
  final String chargeCompteId;     // FK COMPTES
  final double baseAmount;
  final double rateOrAmount;
  final double computedAmount;
  double finalAmount;
  final bool isManuallyEdited;
  final String? editedBy;
  final DateTime? editedAt;
  final String? editReason;

  // Joined
  final String? chargeCompteCode;
  final String? chargeCompteLabel;
  final String? ruleName;

  BankTransactionFee({
    required this.id,
    this.remiseId,
    this.movementTrisorId,
    this.ruleId,
    required this.chargeCompteId,
    required this.baseAmount,
    required this.rateOrAmount,
    required this.computedAmount,
    required this.finalAmount,
    this.isManuallyEdited = false,
    this.editedBy,
    this.editedAt,
    this.editReason,
    this.chargeCompteCode,
    this.chargeCompteLabel,
    this.ruleName,
  });

  factory BankTransactionFee.fromMap(Map<String, dynamic> map) {
    final editedRaw = (map['IS_MANUALLY_EDITED'] ?? '').toString().trim().toUpperCase();
    return BankTransactionFee(
      id: map['ID'].toString(),
      remiseId: map['REMISE_ID']?.toString().trim(),
      movementTrisorId: map['MOVEMENT_TRISOR_ID']?.toString().trim(),
      ruleId: map['RULE_ID']?.toString().trim(),
      chargeCompteId: map['CHARGE_COMPTE_ID'].toString().trim(),
      baseAmount: double.tryParse(map['BASE_AMOUNT']?.toString() ?? '0') ?? 0.0,
      rateOrAmount: double.tryParse(map['RATE_OR_AMOUNT']?.toString() ?? '0') ?? 0.0,
      computedAmount: double.tryParse(map['COMPUTED_AMOUNT']?.toString() ?? '0') ?? 0.0,
      finalAmount: double.tryParse(map['FINAL_AMOUNT']?.toString() ?? '0') ?? 0.0,
      isManuallyEdited: editedRaw == 'O' || editedRaw == '1' || editedRaw == 'TRUE',
      editedBy: map['EDITED_BY']?.toString().trim(),
      editReason: map['EDIT_REASON']?.toString().trim(),
      chargeCompteCode: map['CHARGE_CODE']?.toString().trim(),
      chargeCompteLabel: map['CHARGE_LABEL']?.toString().trim(),
      ruleName: map['RULE_NAME']?.toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'REMISE_ID': remiseId,
      'MOVEMENT_TRISOR_ID': movementTrisorId,
      'RULE_ID': ruleId,
      'CHARGE_COMPTE_ID': chargeCompteId,
      'BASE_AMOUNT': baseAmount,
      'RATE_OR_AMOUNT': rateOrAmount,
      'COMPUTED_AMOUNT': computedAmount,
      'FINAL_AMOUNT': finalAmount,
      'IS_MANUALLY_EDITED': isManuallyEdited ? 'O' : 'N',
      'EDITED_BY': editedBy,
      'EDITED_AT': editedAt?.toIso8601String(),
      'EDIT_REASON': editReason,
    };
  }
}
