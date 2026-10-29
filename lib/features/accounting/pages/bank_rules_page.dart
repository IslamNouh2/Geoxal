import 'package:flutter/material.dart';
import '../../../../core/database/database.dart';
import '../../../../core/security/session.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/datasources/banking_datasource.dart';
import '../../../../data/models/bank_rule.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/repositories/banking_repository.dart';
import '../widgets/bank_fee_simulator_dialog.dart';
import '../widgets/bank_rule_edit_dialog.dart';

class BankRulesPage extends StatefulWidget {
  const BankRulesPage({super.key});

  @override
  State<BankRulesPage> createState() => _BankRulesPageState();
}

class _BankRulesPageState extends State<BankRulesPage> {
  late final BankingRepository _repository;

  List<BankRule> _rules = [];
  List<Compte> _bankAccounts = [];
  List<Compte> _expenseAccounts = [];
  List<TransactionTypeCatalog> _txTypes = [];

  String? _selectedBankFilter;
  String? _selectedTxFilter;
  bool _onlyActiveFilter = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = BankingRepository(BankingDataSource(Database.instance));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bankAccounts = await _repository.getBankAccounts();
      final expenseAccounts = await _repository.getExpenseAccounts();
      final txTypes = await _repository.getTransactionTypes();
      final rules = await _repository.getBankRules(
        bankCompteId: _selectedBankFilter,
        transactionTypeId: _selectedTxFilter,
        onlyActive: _onlyActiveFilter ? true : null,
      );

      if (!mounted) return;
      setState(() {
        _bankAccounts = bankAccounts;
        _expenseAccounts = expenseAccounts;
        _txTypes = txTypes;
        _rules = rules;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les règles bancaires: $e';
      });
    }
  }

  Future<void> _openCreateOrEdit({BankRule? rule}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => BankRuleEditDialog(
        rule: rule,
        bankAccounts: _bankAccounts,
        expenseAccounts: _expenseAccounts,
        transactionTypes: _txTypes,
        existingRules: _rules,
        onSave: (updated) => _repository.saveBankRule(updated),
      ),
    );

    if (saved == true) {
      _load();
    }
  }

  Future<void> _duplicateRule(BankRule rule) async {
    Compte? targetBankCompte;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF18181B)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Dupliquer la règle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dupliquer "${cleanMojibake(rule.name)}" vers un autre compte bancaire :',
                style: const TextStyle(fontSize: 13, color: Color(0xFF52525B)),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<Compte>(
                isExpanded: true,
                value: targetBankCompte,
                hint: const Text('Sélectionner la banque cible', style: TextStyle(fontSize: 13)),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E4E7))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E4E7))),
                ),
                items: _bankAccounts.map((b) => DropdownMenuItem(
                  value: b,
                  child: Text('${b.code} - ${b.libelle}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (val) => setModalState(() => targetBankCompte = val),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF52525B),
                side: const BorderSide(color: Color(0xFFE4E4E7)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: targetBankCompte == null ? null : () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Dupliquer', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && targetBankCompte != null) {
      final copy = BankRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${cleanMojibake(rule.name)} (${targetBankCompte!.libelle})',
        bankCompteId: targetBankCompte!.id,
        transactionTypeId: rule.transactionTypeId,
        chargeCompteId: rule.chargeCompteId,
        calcMethod: rule.calcMethod,
        amount: rule.amount,
        percentVal: rule.percentVal,
        minAmount: rule.minAmount,
        maxAmount: rule.maxAmount,
        baseType: rule.baseType,
        taxCompteId: rule.taxCompteId,
        taxRatePercent: rule.taxRatePercent,
        roundingMode: rule.roundingMode,
        validFrom: DateTime.now(),
        isCumulative: rule.isCumulative,
      );

      await _repository.saveBankRule(copy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Règle dupliquée pour ${targetBankCompte!.libelle}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _load();
      }
    }
  }

  void _openSimulator() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => BankFeeSimulatorDialog(
        bankAccounts: _bankAccounts,
        transactionTypes: _txTypes,
        rules: _rules,
      ),
    );
  }

  Future<void> _deleteRule(BankRule rule) async {
    final ruleName = cleanMojibake(rule.name);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFDC2626)),
            ),
            const SizedBox(width: 12),
            const Text(
              'Supprimer la règle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Color(0xFF52525B)),
            children: [
              const TextSpan(text: 'Voulez-vous supprimer définitivement la règle\n'),
              TextSpan(
                text: '"$ruleName"',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
              ),
              const TextSpan(text: ' ?\nCette action est irréversible.'),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF52525B),
              side: const BorderSide(color: Color(0xFFE4E4E7)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteBankRule(rule.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Règle "$ruleName" supprimée'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression : $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.rule_folder_rounded, color: Color(0xFF2563EB), size: 26),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Règles Bancaires & Commissions',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF09090B),
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Gestion automatisée des commissions bancaires, barèmes et TVA déductible',
                          style: TextStyle(fontSize: 13, color: Color(0xFF71717A)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openSimulator,
                      icon: const Icon(Icons.calculate_rounded, color: Color(0xFF2563EB), size: 18),
                      label: const Text('Simulateur de Frais', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openCreateOrEdit(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nouvelle Règle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar with Clean Zinc Cards
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E4E7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Filtre Banque
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedBankFilter,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
                      decoration: InputDecoration(
                        labelText: 'Filtrer par Banque',
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                        prefixIcon: const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF71717A)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E4E7))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E4E7))),
                        fillColor: const Color(0xFFFAFAFA),
                        filled: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Toutes les banques', overflow: TextOverflow.ellipsis)),
                        ..._bankAccounts.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text('${b.code} - ${b.libelle}', overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedBankFilter = val);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Filtre Opération
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedTxFilter,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
                      decoration: InputDecoration(
                        labelText: 'Filtrer par Type d\'opération',
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                        prefixIcon: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF71717A)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E4E7))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E4E7))),
                        fillColor: const Color(0xFFFAFAFA),
                        filled: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Toutes opérations', overflow: TextOverflow.ellipsis)),
                        ..._txTypes.map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.label, overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedTxFilter = val);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Toggle Actives
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE4E4E7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _onlyActiveFilter,
                          activeColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) {
                            setState(() => _onlyActiveFilter = v ?? false);
                            _load();
                          },
                        ),
                        const Text(
                          'Actives uniquement',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF27272A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14)),
                            ],
                          ),
                        )
                      : _rules.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: const Color(0xFF71717A).withValues(alpha: 0.4)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Aucune règle bancaire configurée',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF52525B)),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Cliquez sur "Nouvelle Règle" pour créer une commission ou TVA bancaire',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF71717A)),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE4E4E7)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: _rules.length,
                                  separatorBuilder: (_, index) => const Divider(height: 1, color: Color(0xFFF4F4F5), indent: 16, endIndent: 16),
                                  itemBuilder: (context, index) {
                                    final rule = _rules[index];
                                    return _buildRuleTile(rule);
                                  },
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleTile(BankRule rule) {
    String formula = '';
    switch (rule.calcMethod) {
      case CalcMethod.fixed:
        formula = '${rule.amount.toStringAsFixed(2)} DZD fixe';
        break;
      case CalcMethod.perCheque:
        formula = '${rule.amount.toStringAsFixed(2)} DZD / chèque';
        break;
      case CalcMethod.percent:
        formula = '${rule.percentVal}% (${rule.baseType == FeeBaseType.parentRuleAmount ? "s/ Commission" : "s/ Montant"})';
        break;
      case CalcMethod.percentWithMinMax:
        formula = '${rule.percentVal}% (Min ${rule.minAmount} / Max ${rule.maxAmount})';
        break;
      case CalcMethod.tiered:
        formula = 'Paliers configurés';
        break;
    }

    final ruleName = cleanMojibake(rule.name);
    final bankLabel = cleanMojibake(rule.bankCompteLabel ?? 'Toutes banques (Globale)');
    final txLabel = cleanMojibake(rule.transactionTypeLabel ?? 'Toutes opérations');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon indicator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rule.active
                  ? (rule.isCumulative ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF))
                  : const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              rule.baseType == FeeBaseType.parentRuleAmount
                  ? Icons.percent_rounded
                  : (rule.calcMethod == CalcMethod.perCheque ? Icons.receipt_rounded : Icons.account_balance_wallet_rounded),
              color: rule.active
                  ? (rule.isCumulative ? const Color(0xFFD97706) : const Color(0xFF2563EB))
                  : const Color(0xFF71717A),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Main info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ruleName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF09090B)),
                    ),
                    const SizedBox(width: 10),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: rule.active ? const Color(0xFFDCFCE7) : const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rule.active ? 'Active' : 'Désactivée',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: rule.active ? const Color(0xFF15803D) : const Color(0xFF71717A),
                        ),
                      ),
                    ),
                    if (rule.isCumulative) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Cumulatif',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 18,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 14, color: Color(0xFF71717A)),
                        const SizedBox(width: 5),
                        Text(bankLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF52525B))),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF71717A)),
                        const SizedBox(width: 5),
                        Text(txLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF52525B))),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calculate_outlined, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 5),
                        Text('Barème : $formula', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Dupliquer vers une autre banque',
                icon: const Icon(Icons.copy_rounded, color: Color(0xFF71717A), size: 18),
                splashRadius: 18,
                onPressed: () => _duplicateRule(rule),
              ),
              IconButton(
                tooltip: 'Modifier la règle',
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 18),
                splashRadius: 18,
                onPressed: () => _openCreateOrEdit(rule: rule),
              ),
              if (Session.user?.hasDeleteBankRulesPermission ?? false)
                IconButton(
                  tooltip: 'Supprimer la règle',
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  splashRadius: 18,
                  onPressed: () => _deleteRule(rule),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
