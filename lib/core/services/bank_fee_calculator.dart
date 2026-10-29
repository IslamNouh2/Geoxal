import 'dart:math' as math;
import '../../data/models/bank_rule.dart';
import '../../data/models/cheque_remise.dart';
import '../utils/uuid.dart';

class FeeCalculationInput {
  final String? bankCompteId;       // ID du compte banque dans COMPTES (NULL = Toutes)
  final String transactionTypeCode;
  final double transactionAmount;
  final int chequesCount;
  final DateTime transactionDate;

  FeeCalculationInput({
    this.bankCompteId,
    required this.transactionTypeCode,
    required this.transactionAmount,
    this.chequesCount = 1,
    DateTime? transactionDate,
  }) : transactionDate = transactionDate ?? DateTime.now();
}

class BankFeeCalculator {
  /// Calcule les frais bancaires selon les règles configurables.
  /// Respecte:
  /// 1. Filtrage date de validité [valid_from, valid_to]
  /// 2. Spécificité: bankCompte + type > bankCompte only > type only > global
  /// 3. Exception règles cumulatives (is_cumulative)
  /// 4. Dépendances parent-child (TVA sur commission)
  /// 5. Méthodes de calcul (FIXED, PERCENT, PERCENT_WITH_MIN_MAX, PER_CHEQUE)
  static List<BankTransactionFee> computeFees({
    required FeeCalculationInput input,
    required List<BankRule> allRules,
    required Map<String, String> transactionTypeCodeToId,
    String? remiseId,
    String? movementTrisorId,
  }) {
    final txTypeId = transactionTypeCodeToId[input.transactionTypeCode];

    // 1. Filtrer les règles applicables à la date et aux critères
    final eligibleRules = allRules.where((r) {
      if (!r.active) return false;
      // Date de validité
      if (input.transactionDate.isBefore(r.validFrom)) return false;
      if (r.validTo != null && input.transactionDate.isAfter(r.validTo!)) return false;

      // Correspondance banque (compte bancaire dans COMPTES)
      if (r.bankCompteId != null && r.bankCompteId != input.bankCompteId) {
        return false;
      }

      // Correspondance type de transaction
      if (r.transactionTypeId != null && r.transactionTypeId != txTypeId) {
        return false;
      }

      return true;
    }).toList();

    // 2. Résoudre la priorité et la spécificité par chargeCompteId
    // 2. Résoudre la priorité et la spécificité par chargeCompteId pour les règles parentes (BASE = TRANSACTION_AMOUNT)
    int specificityScore(BankRule r) {
      int score = r.priority;
      if (r.bankCompteId != null) score += 400;
      if (r.transactionTypeId != null) score += 200;
      return score;
    }

    // Séparer règles directes et règles TVA / subordonnées
    final eligibleParentCandidates = eligibleRules.where((r) => r.baseType != FeeBaseType.parentRuleAmount).toList();
    final eligibleChildCandidates = eligibleRules.where((r) => r.baseType == FeeBaseType.parentRuleAmount).toList();

    // Grouper les règles parentes par chargeCompteId pour retenir la meilleure ou les cumulatives
    final Map<String, List<BankRule>> byChargeCompte = {};
    for (final r in eligibleParentCandidates) {
      byChargeCompte.putIfAbsent(r.chargeCompteId, () => []).add(r);
    }

    final List<BankRule> parentRules = [];
    for (final entries in byChargeCompte.entries) {
      final rulesForCharge = entries.value;
      final cumulative = rulesForCharge.where((r) => r.isCumulative).toList();
      final nonCumulative = rulesForCharge.where((r) => !r.isCumulative).toList();

      parentRules.addAll(cumulative);

      if (nonCumulative.isNotEmpty) {
        nonCumulative.sort((a, b) => specificityScore(b).compareTo(specificityScore(a)));
        parentRules.add(nonCumulative.first);
      }
    }

    // Les règles enfants (TVA s/ Commission) s'appliquent aux commissions calculées
    final childRules = eligibleChildCandidates;

    final List<BankTransactionFee> resultFees = [];
    final Map<String, double> computedAmountByRuleId = {};

    // 4. Calculer d'abord les règles parentes
    for (final rule in parentRules) {
      final fee = _calculateSingleRule(
        rule: rule,
        baseAmount: input.transactionAmount,
        chequesCount: input.chequesCount,
        remiseId: remiseId,
        movementTrisorId: movementTrisorId,
      );
      computedAmountByRuleId[rule.id] = fee.computedAmount;
      resultFees.add(fee);
    }

    // 5. Calculer les règles enfants (TVA sur commission)
    for (final rule in childRules) {
      double base = 0.0;
      if (rule.parentRuleId != null && computedAmountByRuleId.containsKey(rule.parentRuleId)) {
        base = computedAmountByRuleId[rule.parentRuleId]!;
      } else {
        base = parentRules
            .map((r) => computedAmountByRuleId[r.id] ?? 0.0)
            .fold(0.0, (sum, val) => sum + val);
      }

      final fee = _calculateSingleRule(
        rule: rule,
        baseAmount: base,
        chequesCount: input.chequesCount,
        remiseId: remiseId,
        movementTrisorId: movementTrisorId,
      );
      computedAmountByRuleId[rule.id] = fee.computedAmount;
      resultFees.add(fee);
    }

    return resultFees;
  }

  static BankTransactionFee _calculateSingleRule({
    required BankRule rule,
    required double baseAmount,
    required int chequesCount,
    String? remiseId,
    String? movementTrisorId,
  }) {
    double computed = 0.0;
    double rateOrUnit = 0.0;

    switch (rule.calcMethod) {
      case CalcMethod.fixed:
        computed = rule.amount;
        rateOrUnit = rule.amount;
        break;

      case CalcMethod.perCheque:
        final count = math.max(1, chequesCount);
        computed = rule.amount * count;
        rateOrUnit = rule.amount;
        break;

      case CalcMethod.percent:
        rateOrUnit = rule.percentVal;
        computed = baseAmount * (rule.percentVal / 100.0);
        break;

      case CalcMethod.percentWithMinMax:
        rateOrUnit = rule.percentVal;
        computed = baseAmount * (rule.percentVal / 100.0);
        if (rule.minAmount > 0 && computed < rule.minAmount) {
          computed = rule.minAmount;
        }
        if (rule.maxAmount > 0 && computed > rule.maxAmount) {
          computed = rule.maxAmount;
        }
        break;

      case CalcMethod.tiered:
        rateOrUnit = rule.amount > 0 ? rule.amount : rule.percentVal;
        computed = rule.amount;
        break;
    }

    // Arrondi monétaire 2 décimales
    computed = (computed * 100).round() / 100.0;

    return BankTransactionFee(
      id: Uuid.v4(),
      remiseId: remiseId,
      movementTrisorId: movementTrisorId,
      ruleId: rule.id,
      chargeCompteId: rule.chargeCompteId,
      baseAmount: baseAmount,
      rateOrAmount: rateOrUnit,
      computedAmount: computed,
      finalAmount: computed,
      isManuallyEdited: false,
      chargeCompteLabel: rule.chargeCompteLabel,
      ruleName: rule.name,
    );
  }
}
