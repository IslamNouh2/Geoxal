import '../models/bank_rule.dart';
import '../models/cheque_remise.dart';
import '../models/compte.dart';
import '../datasources/banking_datasource.dart';

class BankingRepository {
  final BankingDataSource _dataSource;

  BankingRepository(this._dataSource);

  // Accounts
  Future<List<Compte>> getBankAccounts() => _dataSource.getBankAccounts();
  Future<List<Compte>> getExpenseAccounts() => _dataSource.getExpenseAccounts();

  // Catalogs
  Future<List<TransactionTypeCatalog>> getTransactionTypes() => _dataSource.getTransactionTypes();

  // Rules
  Future<List<BankRule>> getBankRules({String? bankCompteId, String? transactionTypeId, bool? onlyActive}) =>
      _dataSource.getBankRules(
        bankCompteId: bankCompteId,
        transactionTypeId: transactionTypeId,
        onlyActive: onlyActive,
      );

  Future<void> saveBankRule(BankRule rule) => _dataSource.saveBankRule(rule);
  Future<void> deleteBankRule(String ruleId) => _dataSource.deleteBankRule(ruleId);

  // Cheques & Remises
  Future<List<Cheque>> getChequesInPortfolio() => _dataSource.getChequesInPortfolio();
  Future<List<Cheque>> getChequesByRemiseId(String remiseId) => _dataSource.getChequesByRemiseId(remiseId);
  Future<List<BankTransactionFee>> getFeesByRemiseId(String remiseId) => _dataSource.getFeesByRemiseId(remiseId);
  Future<List<RemiseCheque>> getRemises() => _dataSource.getRemises();

  Future<void> createRemiseDraft({
    required RemiseCheque remise,
    required List<String> chequeIds,
    required List<BankTransactionFee> fees,
  }) =>
      _dataSource.createRemiseDraft(
        remise: remise,
        chequeIds: chequeIds,
        fees: fees,
      );

  Future<void> validateRemise({
    required String remiseId,
    required String validatedByUserId,
    required String bankCompteId,
    required double totalAmount,
    required String bordereauNumber,
    required List<BankTransactionFee> fees,
  }) =>
      _dataSource.validateRemise(
        remiseId: remiseId,
        validatedByUserId: validatedByUserId,
        bankCompteId: bankCompteId,
        totalAmount: totalAmount,
        bordereauNumber: bordereauNumber,
        fees: fees,
      );

  Future<void> cancelRemise({
    required String remiseId,
    required String cancelledByUserId,
    required String reason,
  }) =>
      _dataSource.cancelRemise(
        remiseId: remiseId,
        cancelledByUserId: cancelledByUserId,
        reason: reason,
      );
}
