import 'package:flutter_test/flutter_test.dart';
import 'package:geoxal/core/services/bank_fee_calculator.dart';
import 'package:geoxal/data/models/bank_rule.dart';

void main() {
  group('BankFeeCalculator Tests (Based purely on COMPTES)', () {
    const String specificBankCompteId = 'c0000000-0000-4000-8000-000000000051'; // 512 Banque principale
    const String txVersementCheque = 'tt_versement_chq';
    const String chargeCompteCommission = 'c0000000-0000-4000-8000-000000000018'; // Charges
    const String chargeCompteTva = 'c0000000-0000-4000-8000-000000000019'; // TVA

    final txMap = {'VERSEMENT_CHEQUE': txVersementCheque};

    test('1. Spécificité: Règle spécifique à un compte banque override une règle globale', () {
      final globalRule = BankRule(
        id: 'rule_global',
        name: 'Commission Globale',
        bankCompteId: null, // S'applique à toutes les banques
        transactionTypeId: txVersementCheque,
        chargeCompteId: chargeCompteCommission,
        calcMethod: CalcMethod.perCheque,
        amount: 150.0,
        validFrom: DateTime(2025, 1, 1),
      );

      final specificRule = BankRule(
        id: 'rule_specific',
        name: 'Commission Housing Bank',
        bankCompteId: specificBankCompteId,
        transactionTypeId: txVersementCheque,
        chargeCompteId: chargeCompteCommission,
        calcMethod: CalcMethod.perCheque,
        amount: 300.0,
        validFrom: DateTime(2025, 1, 1),
      );

      final fees = BankFeeCalculator.computeFees(
        input: FeeCalculationInput(
          bankCompteId: specificBankCompteId,
          transactionTypeCode: 'VERSEMENT_CHEQUE',
          transactionAmount: 50000.0,
          chequesCount: 1,
        ),
        allRules: [globalRule, specificRule],
        transactionTypeCodeToId: txMap,
      );

      expect(fees.length, 1);
      expect(fees.first.ruleId, 'rule_specific');
      expect(fees.first.computedAmount, 300.0);
    });

    test('2. TVA calculée sur le montant de la commission (parent_rule) et non sur le montant de la transaction', () {
      final comRule = BankRule(
        id: 'rule_com',
        name: 'Com Remise',
        bankCompteId: specificBankCompteId,
        transactionTypeId: txVersementCheque,
        chargeCompteId: chargeCompteCommission,
        calcMethod: CalcMethod.perCheque,
        amount: 300.0,
        baseType: FeeBaseType.transactionAmount,
        validFrom: DateTime(2025, 1, 1),
      );

      final tvaRule = BankRule(
        id: 'rule_tva',
        name: 'TVA s/ Com',
        bankCompteId: specificBankCompteId,
        transactionTypeId: txVersementCheque,
        chargeCompteId: chargeCompteTva,
        calcMethod: CalcMethod.percent,
        percentVal: 19.0,
        baseType: FeeBaseType.parentRuleAmount,
        parentRuleId: 'rule_com',
        validFrom: DateTime(2025, 1, 1),
      );

      final fees = BankFeeCalculator.computeFees(
        input: FeeCalculationInput(
          bankCompteId: specificBankCompteId,
          transactionTypeCode: 'VERSEMENT_CHEQUE',
          transactionAmount: 325230.61, // Montant chèque relevé
          chequesCount: 1,
        ),
        allRules: [comRule, tvaRule],
        transactionTypeCodeToId: txMap,
      );

      expect(fees.length, 2);
      final comFee = fees.firstWhere((f) => f.ruleId == 'rule_com');
      final tvaFee = fees.firstWhere((f) => f.ruleId == 'rule_tva');

      expect(comFee.computedAmount, 300.0);
      expect(tvaFee.baseAmount, 300.0);
      expect(tvaFee.computedAmount, 57.0); // Exactement les 57 DZD constatés sur le relevé
    });

    test('3. Remise de 4 chèques: Frais au prorata du nombre de chèques', () {
      final comRule = BankRule(
        id: 'rule_com',
        name: 'Com Remise',
        bankCompteId: specificBankCompteId,
        transactionTypeId: txVersementCheque,
        chargeCompteId: chargeCompteCommission,
        calcMethod: CalcMethod.perCheque,
        amount: 300.0,
        baseType: FeeBaseType.transactionAmount,
        validFrom: DateTime(2025, 1, 1),
      );

      final tvaRule = BankRule(
        id: 'rule_tva',
        name: 'TVA s/ Com',
        bankCompteId: specificBankCompteId,
        transactionTypeId: txVersementCheque,
        chargeCompteId: chargeCompteTva,
        calcMethod: CalcMethod.percent,
        percentVal: 19.0,
        baseType: FeeBaseType.parentRuleAmount,
        parentRuleId: 'rule_com',
        validFrom: DateTime(2025, 1, 1),
      );

      final fees = BankFeeCalculator.computeFees(
        input: FeeCalculationInput(
          bankCompteId: specificBankCompteId,
          transactionTypeCode: 'VERSEMENT_CHEQUE',
          transactionAmount: 850000.0,
          chequesCount: 4,
        ),
        allRules: [comRule, tvaRule],
        transactionTypeCodeToId: txMap,
      );

      final comFee = fees.firstWhere((f) => f.ruleId == 'rule_com');
      final tvaFee = fees.firstWhere((f) => f.ruleId == 'rule_tva');

      expect(comFee.computedAmount, 1200.0); // 4 * 300
      expect(tvaFee.baseAmount, 1200.0);
      expect(tvaFee.computedAmount, 228.0); // 1200 * 19% = 4 * 57
    });

    test('4. Exact Statement Match: Paiement cheque retour (COM: 100 DZD, TVA: 19 DZD on nominal 78,000 DZD)', () {
      const txPaiementCheque = 'tt_paiement_chq';
      final testTxMap = {
        'PAIEMENT_CHEQUE': txPaiementCheque,
      };

      final comRule = BankRule(
        id: 'rule_paiement_com',
        name: 'Housing Bank - Commission Compensation Cheque emis',
        bankCompteId: specificBankCompteId,
        transactionTypeId: txPaiementCheque,
        chargeCompteId: chargeCompteCommission,
        calcMethod: CalcMethod.fixed,
        amount: 100.0,
        baseType: FeeBaseType.transactionAmount,
        validFrom: DateTime(2025, 1, 1),
      );

      final tvaRule = BankRule(
        id: 'rule_paiement_tva',
        name: 'Housing Bank - TVA s/ Compensation Cheque emis',
        bankCompteId: specificBankCompteId,
        transactionTypeId: txPaiementCheque,
        chargeCompteId: chargeCompteCommission, // Can be same charge compte!
        calcMethod: CalcMethod.percent,
        percentVal: 19.0,
        baseType: FeeBaseType.parentRuleAmount,
        parentRuleId: 'rule_paiement_com',
        validFrom: DateTime(2025, 1, 1),
      );

      final fees = BankFeeCalculator.computeFees(
        input: FeeCalculationInput(
          bankCompteId: specificBankCompteId,
          transactionTypeCode: 'PAIEMENT_CHEQUE',
          transactionAmount: 78000.0, // Exact amount from statement screenshot
        ),
        allRules: [comRule, tvaRule],
        transactionTypeCodeToId: testTxMap,
      );

      expect(fees.length, 2);
      final comFee = fees.firstWhere((f) => f.ruleId == 'rule_paiement_com');
      final tvaFee = fees.firstWhere((f) => f.ruleId == 'rule_paiement_tva');

      expect(comFee.computedAmount, 100.0);
      expect(tvaFee.baseAmount, 100.0); // Base is 100 DZD commission, NOT 78,000 DZD
      expect(tvaFee.computedAmount, 19.0); // 19% of 100 = 19.00 DZD
    });
  });
}
