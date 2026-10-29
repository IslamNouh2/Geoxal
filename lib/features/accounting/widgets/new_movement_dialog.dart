import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/bank_fee_calculator.dart';
import '../../../../data/datasources/banking_datasource.dart';
import '../../../../data/datasources/finance_datasource.dart';
import '../../../../data/models/bank_rule.dart';
import '../../../../data/models/cheque_remise.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/repositories/banking_repository.dart';
import '../../../../data/repositories/finance_repository.dart';
import 'account_tree_picker.dart';
import 'new_account_dialog.dart';

Future<bool> showNewMovementDialog(
  BuildContext context, {
  required Compte activeCaisse,
  required List<Compte> allAccounts,
  required Set<String> accountIdsWithMovements,
  required Future<void> Function(
    DateTime date,
    String compteSourceId,
    String compteDestId,
    double montant,
    String designation, {
    List<BankTransactionFee>? fees,
    String? modePaiement,
    String? numCheque,
    DateTime? dateCheque,
    double? tauxChange,
    double? montantDevise,
  }) onSave,
  Future<void> Function(
    String code,
    String libelle,
    String? parentId,
    CompteType? typeCompte, {
    bool isDevise,
    String? codeDevise,
  })? onCreateAccount,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => NewMovementDialog(
      activeCaisse: activeCaisse,
      allAccounts: allAccounts,
      accountIdsWithMovements: accountIdsWithMovements,
      onSave: onSave,
      onCreateAccount: onCreateAccount,
    ),
  ).then((v) => v ?? false);
}

/// Whether a transaction flows into or out of the active caisse, or is a cash-only movement.
enum TransactionType {
  recette('Encaissement', Icons.arrow_downward_rounded, Color(0xFF10B981), Color(0xFFECFDF5), Color(0xFF6EE7B7)),
  depense('Décaissement', Icons.arrow_upward_rounded, Color(0xFFEF4444), Color(0xFFFEF2F2), Color(0xFFFCA5A5));

  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const TransactionType(this.label, this.icon, this.color, this.bgColor, this.borderColor);
}

/// Returns a locked transaction type for the given compte type, or null if switchable.
TransactionType? _inferLockedType(CompteType? type) {
  switch (type) {
    case CompteType.recette:
      return TransactionType.recette;
    case CompteType.depense:
      return TransactionType.depense;
    default:
      return null;
  }
}

class NewMovementDialog extends StatefulWidget {
  const NewMovementDialog({
    super.key,
    required this.activeCaisse,
    required this.allAccounts,
    required this.accountIdsWithMovements,
    required this.onSave,
    this.onCreateAccount,
  });

  final Compte activeCaisse;
  final List<Compte> allAccounts;
  final Set<String> accountIdsWithMovements;
  final Future<void> Function(
    DateTime date,
    String compteSourceId,
    String compteDestId,
    double montant,
    String designation, {
    List<BankTransactionFee>? fees,
    String? modePaiement,
    String? numCheque,
    DateTime? dateCheque,
    double? tauxChange,
    double? montantDevise,
  }) onSave;
  final Future<void> Function(
    String code,
    String libelle,
    String? parentId,
    CompteType? typeCompte, {
    bool isDevise,
    String? codeDevise,
  })? onCreateAccount;

  @override
  State<NewMovementDialog> createState() => _NewMovementDialogState();
}

class _NewMovementDialogState extends State<NewMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _designationController = TextEditingController();
  late final TextEditingController _dateController;

  // Mode de transaction (Espèces, Chèque, Virement bancaire, Versement bancaire)
  String _selectedModePaiement = 'Espèces';
  static const List<String> _modesPaiement = [
    'Espèces',
    'Chèque',
    'Virement bancaire',
    'Versement bancaire',
  ];

  // Chèque fields
  final _numChequeController = TextEditingController();
  DateTime _dateCheque = DateTime.now();
  late final TextEditingController _dateChequeController;

  // Devise & Taux de change fields
  final _tauxChangeController = TextEditingController(text: '1.0');

  late List<Compte> _currentAccounts;
  DateTime _selectedDate = DateTime.now();
  Compte? _otherAccount;
  TransactionType _transactionType = TransactionType.depense;
  TransactionType? _lockedType;
  bool _saving = false;
  String? _errorMessage;

  // Helper getters for devise
  bool get _isDeviseInvolved {
    return widget.activeCaisse.isDevise || (_otherAccount?.isDevise ?? false);
  }

  String get _currencyCodeInvolved {
    if (widget.activeCaisse.isDevise && widget.activeCaisse.codeDevise != null) {
      return widget.activeCaisse.codeDevise!;
    }
    if (_otherAccount?.isDevise == true && _otherAccount?.codeDevise != null) {
      return _otherAccount!.codeDevise!;
    }
    return 'Devise';
  }

  // Mode Bancaire & Règles
  late final BankingRepository _bankingRepo;
  List<BankRule> _bankRules = [];
  List<TransactionTypeCatalog> _txCatalogs = [];
  String _selectedBankOperationCode = 'VERSEMENT_ESPECES';
  List<BankTransactionFee> _computedFees = [];

  /// Derives the correct bank operation code from the current payment mode and transaction type.
  String _bankOpFromMode(String mode, TransactionType type) {
    switch (mode) {
      case 'Chèque':
        return type == TransactionType.depense ? 'PAIEMENT_CHEQUE' : 'VERSEMENT_CHEQUE';
      case 'Virement bancaire':
        return type == TransactionType.depense ? 'VIREMENT_EMIS' : 'VIREMENT_RECU';
      case 'Versement bancaire':
        return 'VERSEMENT_ESPECES';
      case 'Espèces':
      default:
        return 'VERSEMENT_ESPECES';
    }
  }

  void _syncBankOp() {
    final code = _bankOpFromMode(_selectedModePaiement, _transactionType);
    if (_selectedBankOperationCode != code) {
      _selectedBankOperationCode = code;
    }
  }

  bool get _involvesBank {
    final activeIsBank = widget.activeCaisse.typeCompte == CompteType.banque;
    final otherIsBank = _otherAccount != null && _otherAccount!.typeCompte == CompteType.banque;
    return activeIsBank || otherIsBank;
  }

  Compte? get _bankAccountInvolved {
    if (widget.activeCaisse.typeCompte == CompteType.banque) {
      return widget.activeCaisse;
    }
    if (_otherAccount != null && _otherAccount!.typeCompte == CompteType.banque) {
      return _otherAccount;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentAccounts = List<Compte>.from(widget.allAccounts);
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _dateChequeController = TextEditingController(text: _formatDate(_dateCheque));
    _bankingRepo = BankingRepository(BankingDataSource(Database.instance));
    _loadBankingRules();
  }

  Future<void> _loadBankingRules() async {
    try {
      final rules = await _bankingRepo.getBankRules(onlyActive: true);
      final txTypes = await _bankingRepo.getTransactionTypes();
      if (!mounted) return;
      setState(() {
        _bankRules = rules;
        _txCatalogs = txTypes;
      });
      _recalculateFees();
    } catch (_) {}
  }

  void _recalculateFees() {
    if (!_involvesBank || _bankAccountInvolved == null) {
      if (_computedFees.isNotEmpty) setState(() => _computedFees = []);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      if (_computedFees.isNotEmpty) setState(() => _computedFees = []);
      return;
    }

    final txMap = {for (final tx in _txCatalogs) tx.code: tx.id};

    final fees = BankFeeCalculator.computeFees(
      input: FeeCalculationInput(
        bankCompteId: _bankAccountInvolved!.id,
        transactionTypeCode: _selectedBankOperationCode,
        transactionAmount: amount,
        chequesCount: 1,
        transactionDate: _selectedDate,
      ),
      allRules: _bankRules,
      transactionTypeCodeToId: txMap,
    );

    setState(() {
      _computedFees = fees;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _designationController.dispose();
    _dateController.dispose();
    _numChequeController.dispose();
    _dateChequeController.dispose();
    _tauxChangeController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _onAccountSelected(Compte picked) {
    final effectiveType = picked.resolveEffectiveType(_currentAccounts);
    final locked = _inferLockedType(effectiveType);
    setState(() {
      _otherAccount = picked;
      _lockedType = locked;
      if (locked != null) _transactionType = locked;
      _errorMessage = null;
      _syncBankOp();
    });
    _recalculateFees();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
      _recalculateFees();
    }
  }

  Future<void> _pickDateCheque() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateCheque,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _dateCheque = picked;
        _dateChequeController.text = _formatDate(picked);
      });
    }
  }

  /// Whether an account matches the transaction mode rule:
  /// - 'Espèces' -> only show caisses (compteType == CompteType.caisse)
  /// - Other ('Chèque', 'Virement', 'Versement') -> only show banques (compteType == CompteType.banque)
  bool _accountMatchesPaymentMode(Compte a) {
    final effectiveType = a.resolveEffectiveType(_currentAccounts);
    // If selecting financial account (caisse vs banque):
    if (_selectedModePaiement == 'Espèces') {
      // Must NOT be banque. If it's a financial account, it must be caisse.
      // Or general expense/revenue. But if user is transferring/selecting caisse, caisse only.
      if (effectiveType == CompteType.banque) return false;
      return true;
    } else {
      // Non-espèces: Must NOT be caisse. If financial, must be banque.
      if (effectiveType == CompteType.caisse) return false;
      return true;
    }
  }

  Future<void> _openTreePicker() async {
    final picked = await showAccountTreePickerDialog(
      context,
      accounts: _currentAccounts,
      excludeAccountId: widget.activeCaisse.id,
      selectedAccount: _otherAccount,
      filterPredicate: (a) => _accountMatchesPaymentMode(a),
    );
    if (picked != null) _onAccountSelected(picked);
  }

  Future<void> _createNewAccount() async {
    if (widget.onCreateAccount == null) return;
    String? createdCode;

    final saved = await showNewAccountDialog(
      context,
      accounts: _currentAccounts,
      accountIdsWithMovements: widget.accountIdsWithMovements,
      onSave: (code, libelle, parentId, typeCompte, {isDevise = false, codeDevise}) async {
        createdCode = code;
        await widget.onCreateAccount!(code, libelle, parentId, typeCompte, isDevise: isDevise, codeDevise: codeDevise);
      },
    );

    if (saved && mounted) {
      // Auto-reload accounts from database so NewMovementDialog has the latest accounts
      try {
        final repo = FinanceRepository(FinanceDataSource(Database.instance));
        final freshAccounts = await repo.getAccounts();
        if (mounted) {
          setState(() {
            _currentAccounts = freshAccounts;
            // Auto-select the newly created account if found
            if (createdCode != null) {
              final newAccount = freshAccounts.firstWhere(
                (a) => a.code == createdCode,
                orElse: () => freshAccounts.first,
              );
              if (newAccount.code == createdCode) {
                _onAccountSelected(newAccount);
              }
            }
          });
        }
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé et actualisé avec succès.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_otherAccount == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner un compte dans l\'arbre comptable.');
      return;
    }

    if (_otherAccount!.id == widget.activeCaisse.id) {
      setState(() => _errorMessage = 'Le compte ne peut pas être identique à la caisse active.');
      return;
    }

    // Validate payment mode compatibility
    if (!_accountMatchesPaymentMode(_otherAccount!)) {
      final msg = _selectedModePaiement == 'Espèces'
          ? 'En mode Espèces, vous ne pouvez pas sélectionner un compte bancaire.'
          : 'Pour les règlements par $_selectedModePaiement, vous devez sélectionner un compte bancaire.';
      setState(() => _errorMessage = msg);
      return;
    }

    // Validate chèque fields
    if (_selectedModePaiement == 'Chèque') {
      if (_numChequeController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Veuillez saisir le numéro de chèque.');
        return;
      }
    }

    final amountEntered = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amountEntered == null || amountEntered <= 0) {
      setState(() => _errorMessage = 'Le montant doit être supérieur à 0.');
      return;
    }

    // Calculate exchange rate and DZD amount
    double? tauxChange;
    double? montantDevise;
    double amountDZD = amountEntered;

    if (_isDeviseInvolved) {
      tauxChange = double.tryParse(_tauxChangeController.text.trim().replaceAll(',', '.'));
      if (tauxChange == null || tauxChange <= 0) {
        setState(() => _errorMessage = 'Le taux de change doit être supérieur à 0.');
        return;
      }
      montantDevise = amountEntered;
      amountDZD = amountEntered * tauxChange;
    }

    final String sourceId;
    final String destId;
    if (_transactionType == TransactionType.depense) {
      sourceId = widget.activeCaisse.id;
      destId = _otherAccount!.id;
    } else {
      sourceId = _otherAccount!.id;
      destId = widget.activeCaisse.id;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        _selectedDate,
        sourceId,
        destId,
        amountDZD,
        _designationController.text.trim(),
        fees: _involvesBank ? _computedFees : null,
        modePaiement: _selectedModePaiement,
        numCheque: _selectedModePaiement == 'Chèque' ? _numChequeController.text.trim() : null,
        dateCheque: _selectedModePaiement == 'Chèque' ? _dateCheque : null,
        tauxChange: tauxChange,
        montantDevise: montantDevise,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Erreur lors de l\'enregistrement: $e';
      });
    }
  }

  // ── UI helpers ────────────────────────────────────────────────

  Widget _buildTypeToggle() {
    final locked = _lockedType != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Type de transaction *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            if (locked) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 3),
                    Text('Verrouillé par le type du compte', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _typeButton(TransactionType.recette, locked),
            const SizedBox(width: 8),
            _typeButton(TransactionType.depense, locked),
          ],
        ),
      ],
    );
  }

  Widget _typeButton(TransactionType t, bool locked) {
    final isSelected = _transactionType == t;
    final canTap = !locked;
    return Expanded(
      child: GestureDetector(
        onTap: canTap
            ? () => setState(() {
                  _transactionType = t;
                  _syncBankOp();
                })
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? t.bgColor : const Color(0xFFF9FAFB),
            border: Border.all(
              color: isSelected ? t.borderColor : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(t.icon, size: 18,
                  color: isSelected ? t.color : (canTap ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB))),
              const SizedBox(width: 8),
              Text(
                t.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? t.color : (canTap ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle_rounded, size: 14, color: t.color),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaisseRow() {
    final isDepense = _transactionType == TransactionType.depense;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDepense ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
        border: Border.all(color: isDepense ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDepense ? const Color(0xFF2563EB) : const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDepense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 16, color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDepense ? 'Compte Source — Caisse (Sortant)' : 'Compte Destination — Caisse (Entrant)',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: isDepense ? const Color(0xFF1D4ED8) : const Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.activeCaisse.displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
          Chip(
            label: const Text('Caisse Active', style: TextStyle(fontSize: 11)),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(color: isDepense ? const Color(0xFF1D4ED8) : const Color(0xFF047857)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildOtherAccountRow() {
    final isDepense = _transactionType == TransactionType.depense;
    final effectiveType = _otherAccount?.resolveEffectiveType(widget.allAccounts);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDepense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 16,
                color: isDepense ? const Color(0xFF10B981) : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 6),
              Text(
                isDepense ? 'Compte Destination (Entrant) *' : 'Compte Source (Sortant) *',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
              ),
              const Spacer(),
              // Quick create button
              Tooltip(
                message: 'Créer un nouveau compte',
                child: InkWell(
                  onTap: _createNewAccount,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Nouveau', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _openTreePicker,
                icon: const Icon(Icons.account_tree_rounded, size: 14),
                label: Text(
                  _otherAccount == null ? 'Choisir dans l\'arbre' : 'Modifier',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _openTreePicker,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _otherAccount != null ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _otherAccount != null ? Icons.description_rounded : Icons.search_rounded,
                    size: 18,
                    color: _otherAccount != null ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _otherAccount?.displayName ?? 'Cliquez pour sélectionner un compte...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _otherAccount != null ? FontWeight.w600 : FontWeight.w400,
                        color: _otherAccount != null ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  if (_otherAccount != null && effectiveType != null) _buildTypeBadge(effectiveType),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(CompteType type) {
    Color bg; Color fg;
    switch (type) {
      case CompteType.caisse:      bg = const Color(0xFFDCFCE7); fg = const Color(0xFF15803D); break;
      case CompteType.banque:      bg = const Color(0xFFDBEAFE); fg = const Color(0xFF1D4ED8); break;
      case CompteType.recette:     bg = const Color(0xFFEDE9FE); fg = const Color(0xFF6D28D9); break;
      case CompteType.depense:     bg = const Color(0xFFFEE2E2); fg = const Color(0xFFB91C1C); break;
      case CompteType.recetteDepense: bg = const Color(0xFFFEF3C7); fg = const Color(0xFFB45309); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(type.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nouveau Mouvement de Trésorerie',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.deepSpaceBlue),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enregistrer une recette ou une dépense sur la caisse active',
                              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Error
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900, fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Type toggle
                  _buildTypeToggle(),
                  const SizedBox(height: 16),

                  // Caisse row
                  _buildCaisseRow(),
                  const SizedBox(height: 12),

                  // Flow arrow
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _transactionType == TransactionType.depense
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 14, color: const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _transactionType == TransactionType.depense ? 'Sortie vers' : 'Entrée depuis',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Other account
                  _buildOtherAccountRow(),
                  const SizedBox(height: 18),

                  // Mode de transaction / règlement (Espèces, Chèque, Virement bancaire, Versement bancaire)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode de règlement *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedModePaiement,
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            _selectedModePaiement == 'Espèces'
                                ? Icons.payments_rounded
                                : _selectedModePaiement == 'Chèque'
                                    ? Icons.receipt_long_rounded
                                    : Icons.account_balance_rounded,
                            size: 18,
                            color: const Color(0xFF2563EB),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: _modesPaiement.map((mode) {
                          return DropdownMenuItem<String>(
                            value: mode,
                            child: Text(mode, style: const TextStyle(fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (newVal) {
                          if (newVal == null) return;
                          setState(() {
                            _selectedModePaiement = newVal;
                            // Clear account if incompatible with new mode
                            if (_otherAccount != null && !_accountMatchesPaymentMode(_otherAccount!)) {
                              _otherAccount = null;
                              _lockedType = null;
                            }
                            // Keep bank operation in sync with payment mode
                            _syncBankOp();
                          });
                          _recalculateFees();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fields specific to Chèque
                  if (_selectedModePaiement == 'Chèque') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFFB45309)),
                              SizedBox(width: 8),
                              Text(
                                'Détails du Chèque',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Numéro de chèque *',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _numChequeController,
                                      decoration: InputDecoration(
                                        hintText: 'Ex: CHQ-984321',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      validator: (val) {
                                        if (_selectedModePaiement == 'Chèque' && (val == null || val.trim().isEmpty)) {
                                          return 'N° de chèque requis';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Date du chèque *',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _dateChequeController,
                                      readOnly: true,
                                      onTap: _pickDateCheque,
                                      decoration: InputDecoration(
                                        suffixIcon: const Icon(Icons.calendar_today, size: 16),
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Date & Montant
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date du mouvement *',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _dateController,
                              readOnly: true,
                              onTap: _pickDate,
                              decoration: InputDecoration(
                                suffixIcon: const Icon(Icons.calendar_today, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isDeviseInvolved
                                  ? 'Montant ($_currencyCodeInvolved) *'
                                  : 'Montant (DZD) *',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: _isDeviseInvolved ? '$_currencyCodeInvolved ' : 'DA ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _recalculateFees();
                              },
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Montant requis';
                                final n = double.tryParse(val.trim().replaceAll(',', '.'));
                                if (n == null || n <= 0) return 'Montant invalide';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Si compte en Devise étrangère impliqué : afficher Taux de change et calcul direct en DZD
                  if (_isDeviseInvolved) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.currency_exchange_rounded, size: 18, color: Color(0xFF15803D)),
                              const SizedBox(width: 8),
                              Text(
                                'Opération en Devise : $_currencyCodeInvolved',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '1 $_currencyCodeInvolved = ${_tauxChangeController.text.trim()} DZD',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Taux de change (en Dinars Algériens - DZD) *',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _tauxChangeController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        hintText: 'Ex: 240.00',
                                        isDense: true,
                                        suffixText: 'DZD',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'Taux requis';
                                        final n = double.tryParse(val.trim().replaceAll(',', '.'));
                                        if (n == null || n <= 0) return 'Taux invalide';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 3,
                                child: Builder(
                                  builder: (context) {
                                    final amt = double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0.0;
                                    final rate = double.tryParse(_tauxChangeController.text.trim().replaceAll(',', '.')) ?? 1.0;
                                    final totalDzd = amt * rate;
                                    return Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Équivalent converti (Statistiques DA)',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${totalDzd.toStringAsFixed(2)} DZD',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Informations bancaire (opération déduite du mode de règlement)
                  if (_involvesBank) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              const Text(
                                'Opération bancaire déduite :',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                              ),
                              const Spacer(),
                              Text(
                                _bankAccountInvolved?.libelle ?? 'Banque',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Read-only display of the synced bank operation
                          _buildBankOpReadOnly(),

                          // Aperçu des taxes et commissions déduites en temps réel
                          if (_computedFees.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFBFDBFE)),
                            const SizedBox(height: 8),
                            const Text(
                              'Frais bancaires & Taxes appliqués automatiquement :',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(height: 6),
                            ..._computedFees.map((fee) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '• ${fee.ruleName ?? "Frais bancaire"}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                  ),
                                  Text(
                                    '- ${fee.computedAmount.toStringAsFixed(2)} DZD',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            )),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total retenues (Frais + TVA) :',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                                ),
                                Text(
                                  '- ${_computedFees.fold(0.0, (sum, f) => sum + f.computedAmount).toStringAsFixed(2)} DZD',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Désignation
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Désignation / Motif *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _designationController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Ex: Paiement salaire, Achat fournitures, Versement...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Veuillez saisir une désignation';
                          return null;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _transactionType == TransactionType.depense
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(
                                _transactionType == TransactionType.depense
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 18),
                        label: Text(_saving
                            ? 'Enregistrement...'
                            : _transactionType == TransactionType.depense
                                ? 'Enregistrer la Dépense'
                                : 'Enregistrer la Recette'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Maps a bank operation code to a human-readable label and icon.
  static const Map<String, (String, IconData)> _bankOpMeta = {
    'VERSEMENT_ESPECES': ('Versement espèces', Icons.payments_rounded),
    'VERSEMENT_CHEQUE': ('Versement chèque', Icons.receipt_long_rounded),
    'VIREMENT_RECU': ('Virement reçu', Icons.call_received_rounded),
    'VIREMENT_EMIS': ('Virement émis', Icons.send_rounded),
    'PAIEMENT_CHEQUE': ('Paiement chèque (émis)', Icons.edit_note_rounded),
  };

  /// Read-only badge showing the bank operation derived from the payment mode.
  Widget _buildBankOpReadOnly() {
    final meta = _bankOpMeta[_selectedBankOperationCode];
    final label = meta?.$1 ?? _selectedBankOperationCode;
    final icon = meta?.$2 ?? Icons.account_balance_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.link_rounded, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          const Text(
            'Défini par le mode de règlement',
            style: TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

