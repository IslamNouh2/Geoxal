import '../../core/utils/format.dart';

enum CalcMethod {
  fixed('FIXED', 'Montant fixe'),
  percent('PERCENT', 'Pourcentage (%)'),
  percentWithMinMax('PERCENT_WITH_MIN_MAX', 'Pourcentage avec Min/Max'),
  tiered('TIERED', 'Par paliers / tranches'),
  perCheque('PER_CHEQUE', 'Montant fixe par chèque');

  final String code;
  final String label;
  const CalcMethod(this.code, this.label);

  static CalcMethod fromString(String? val) {
    if (val == null) return CalcMethod.fixed;
    final clean = val.trim().toUpperCase();
    for (final m in CalcMethod.values) {
      if (m.code == clean) return m;
    }
    return CalcMethod.fixed;
  }
}

enum FeeBaseType {
  transactionAmount('TRANSACTION_AMOUNT', 'Montant de la transaction'),
  parentRuleAmount('PARENT_RULE_AMOUNT', 'Montant de la règle parente (ex: TVA/Commission)');

  final String code;
  final String label;
  const FeeBaseType(this.code, this.label);

  static FeeBaseType fromString(String? val) {
    if (val == null) return FeeBaseType.transactionAmount;
    final clean = val.trim().toUpperCase();
    for (final b in FeeBaseType.values) {
      if (b.code == clean) return b;
    }
    return FeeBaseType.transactionAmount;
  }
}

class TransactionTypeCatalog {
  final String id;
  final String code;
  final String label;
  final bool active;

  const TransactionTypeCatalog({
    required this.id,
    required this.code,
    required this.label,
    this.active = true,
  });

  factory TransactionTypeCatalog.fromMap(Map<String, dynamic> map) {
    final activeRaw = (map['ACTIVE'] ?? '').toString().trim().toUpperCase();
    return TransactionTypeCatalog(
      id: map['ID'].toString(),
      code: map['CODE'].toString().trim(),
      label: cleanMojibake(map['LABEL'].toString().trim()),
      active: activeRaw.isEmpty || activeRaw == 'O' || activeRaw == '1',
    );
  }
}

class BankRule {
  final String id;
  final String name;
  final bool active;
  final int priority;
  final String? bankCompteId;       // FK COMPTES (compte type 'banque'), NULL = Toutes les banques
  final String? transactionTypeId;  // NULL = Tous les types
  final String chargeCompteId;      // FK COMPTES (compte de charge)
  final CalcMethod calcMethod;
  final double amount;
  final double percentVal;
  final double minAmount;
  final double maxAmount;
  final FeeBaseType baseType;
  final String? parentRuleId;
  final String? taxCompteId;        // FK COMPTES (compte de taxe)
  final double taxRatePercent;
  final String roundingMode;
  final DateTime validFrom;
  final DateTime? validTo;
  final bool isCumulative;

  // Joined display helpers from COMPTES
  final String? bankCompteLabel;
  final String? transactionTypeLabel;
  final String? chargeCompteLabel;
  final String? taxCompteLabel;

  const BankRule({
    required this.id,
    required this.name,
    this.active = true,
    this.priority = 0,
    this.bankCompteId,
    this.transactionTypeId,
    required this.chargeCompteId,
    required this.calcMethod,
    this.amount = 0.0,
    this.percentVal = 0.0,
    this.minAmount = 0.0,
    this.maxAmount = 0.0,
    this.baseType = FeeBaseType.transactionAmount,
    this.parentRuleId,
    this.taxCompteId,
    this.taxRatePercent = 19.0,
    this.roundingMode = 'ROUND_HALF_UP',
    required this.validFrom,
    this.validTo,
    this.isCumulative = false,
    this.bankCompteLabel,
    this.transactionTypeLabel,
    this.chargeCompteLabel,
    this.taxCompteLabel,
  });

  factory BankRule.fromMap(Map<String, dynamic> map) {
    final activeRaw = (map['ACTIVE'] ?? '').toString().trim().toUpperCase();
    final cumulativeRaw = (map['IS_CUMULATIVE'] ?? '').toString().trim().toUpperCase();

    DateTime parseDt(dynamic val) {
      if (val is DateTime) return val;
      final str = val?.toString().trim() ?? '';
      return DateTime.tryParse(str) ?? DateTime(2025, 1, 1);
    }

    return BankRule(
      id: map['ID'].toString(),
      name: cleanMojibake(map['NAME'].toString().trim()),
      active: activeRaw.isEmpty || activeRaw == 'O' || activeRaw == '1',
      priority: int.tryParse(map['PRIORITY']?.toString() ?? '0') ?? 0,
      bankCompteId: map['BANK_COMPTE_ID']?.toString().trim(),
      transactionTypeId: map['TRANSACTION_TYPE_ID']?.toString().trim(),
      chargeCompteId: map['CHARGE_COMPTE_ID'].toString().trim(),
      calcMethod: CalcMethod.fromString(map['CALC_METHOD']?.toString()),
      amount: double.tryParse(map['AMOUNT']?.toString() ?? '0') ?? 0.0,
      percentVal: double.tryParse(map['PERCENT_VAL']?.toString() ?? '0') ?? 0.0,
      minAmount: double.tryParse(map['MIN_AMOUNT']?.toString() ?? '0') ?? 0.0,
      maxAmount: double.tryParse(map['MAX_AMOUNT']?.toString() ?? '0') ?? 0.0,
      baseType: FeeBaseType.fromString(map['BASE_TYPE']?.toString()),
      parentRuleId: map['PARENT_RULE_ID']?.toString().trim(),
      taxCompteId: map['TAX_COMPTE_ID']?.toString().trim(),
      taxRatePercent: double.tryParse(map['TAX_RATE_PERCENT']?.toString() ?? '19') ?? 19.0,
      roundingMode: (map['ROUNDING_MODE'] ?? 'ROUND_HALF_UP').toString().trim(),
      validFrom: parseDt(map['VALID_FROM']),
      validTo: map['VALID_TO'] != null ? parseDt(map['VALID_TO']) : null,
      isCumulative: cumulativeRaw == 'O' || cumulativeRaw == '1' || cumulativeRaw == 'TRUE',
      bankCompteLabel: map['BANK_LABEL'] != null ? cleanMojibake(map['BANK_LABEL'].toString().trim()) : null,
      transactionTypeLabel: map['TX_LABEL'] != null ? cleanMojibake(map['TX_LABEL'].toString().trim()) : null,
      chargeCompteLabel: map['CHARGE_LABEL'] != null ? cleanMojibake(map['CHARGE_LABEL'].toString().trim()) : null,
      taxCompteLabel: map['TAX_LABEL'] != null ? cleanMojibake(map['TAX_LABEL'].toString().trim()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'NAME': name,
      'ACTIVE': active ? 'O' : 'N',
      'PRIORITY': priority,
      'BANK_COMPTE_ID': bankCompteId,
      'TRANSACTION_TYPE_ID': transactionTypeId,
      'CHARGE_COMPTE_ID': chargeCompteId,
      'CALC_METHOD': calcMethod.code,
      'AMOUNT': amount,
      'PERCENT_VAL': percentVal,
      'MIN_AMOUNT': minAmount,
      'MAX_AMOUNT': maxAmount,
      'BASE_TYPE': baseType.code,
      'PARENT_RULE_ID': parentRuleId,
      'TAX_COMPTE_ID': taxCompteId,
      'TAX_RATE_PERCENT': taxRatePercent,
      'ROUNDING_MODE': roundingMode,
      'VALID_FROM': validFrom.toIso8601String(),
      'VALID_TO': validTo?.toIso8601String(),
      'IS_CUMULATIVE': isCumulative ? 'O' : 'N',
    };
  }
}
