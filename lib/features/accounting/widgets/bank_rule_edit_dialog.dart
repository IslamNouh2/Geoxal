import 'package:flutter/material.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/uuid.dart';
import '../../../../data/models/bank_rule.dart';
import '../../../../data/models/compte.dart';

class BankRuleEditDialog extends StatefulWidget {
  final BankRule? rule;
  final List<Compte> bankAccounts;
  final List<Compte> expenseAccounts;
  final List<TransactionTypeCatalog> transactionTypes;
  final List<BankRule> existingRules;
  final Future<void> Function(BankRule rule) onSave;

  const BankRuleEditDialog({
    super.key,
    this.rule,
    required this.bankAccounts,
    required this.expenseAccounts,
    required this.transactionTypes,
    required this.existingRules,
    required this.onSave,
  });

  @override
  State<BankRuleEditDialog> createState() => _BankRuleEditDialogState();
}

class _BankRuleEditDialogState extends State<BankRuleEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _percentController;
  late TextEditingController _minAmountController;
  late TextEditingController _maxAmountController;
  late TextEditingController _priorityController;
  late TextEditingController _taxRatePercentController;

  String? _selectedBankCompteId;
  String? _selectedTxTypeId;
  late String _selectedChargeCompteId;
  String? _selectedTaxCompteId;
  late CalcMethod _calcMethod;
  late FeeBaseType _baseType;
  String? _parentRuleId;
  late bool _active;
  late bool _isCumulative;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameController = TextEditingController(text: r != null ? cleanMojibake(r.name) : '');
    _amountController = TextEditingController(text: (r?.amount ?? 0.0).toString());
    _percentController = TextEditingController(text: (r?.percentVal ?? 0.0).toString());
    _minAmountController = TextEditingController(text: (r?.minAmount ?? 0.0).toString());
    _maxAmountController = TextEditingController(text: (r?.maxAmount ?? 0.0).toString());
    _priorityController = TextEditingController(text: (r?.priority ?? 0).toString());
    _taxRatePercentController = TextEditingController(text: (r?.taxRatePercent ?? 19.0).toString());

    _selectedBankCompteId = r?.bankCompteId;
    _selectedTxTypeId = r?.transactionTypeId;
    _selectedChargeCompteId = r?.chargeCompteId ?? (widget.expenseAccounts.isNotEmpty ? widget.expenseAccounts.first.id : '');
    _selectedTaxCompteId = r?.taxCompteId;
    _calcMethod = r?.calcMethod ?? CalcMethod.fixed;
    _baseType = r?.baseType ?? FeeBaseType.transactionAmount;
    _parentRuleId = r?.parentRuleId;
    _active = r?.active ?? true;
    _isCumulative = r?.isCumulative ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _percentController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _priorityController.dispose();
    _taxRatePercentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final updated = BankRule(
        id: widget.rule?.id ?? Uuid.v4(),
        name: cleanMojibake(_nameController.text.trim()),
        active: _active,
        priority: int.tryParse(_priorityController.text.trim()) ?? 0,
        bankCompteId: _selectedBankCompteId,
        transactionTypeId: _selectedTxTypeId,
        chargeCompteId: _selectedChargeCompteId,
        calcMethod: _calcMethod,
        amount: double.tryParse(_amountController.text.trim()) ?? 0.0,
        percentVal: double.tryParse(_percentController.text.trim()) ?? 0.0,
        minAmount: double.tryParse(_minAmountController.text.trim()) ?? 0.0,
        maxAmount: double.tryParse(_maxAmountController.text.trim()) ?? 0.0,
        baseType: _baseType,
        parentRuleId: _parentRuleId,
        taxCompteId: _selectedTaxCompteId,
        taxRatePercent: double.tryParse(_taxRatePercentController.text.trim()) ?? 19.0,
        roundingMode: 'ROUND_HALF_UP',
        validFrom: widget.rule?.validFrom ?? DateTime.now(),
        validTo: widget.rule?.validTo,
        isCumulative: _isCumulative,
      );

      await widget.onSave(updated);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.rule != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 820,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E4E7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF4F4F5))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Modifier la Règle Bancaire' : 'Nouvelle Règle Bancaire',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF09090B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Paramétrez le barème, les comptes comptables et l\'application de la TVA',
                            style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF71717A), size: 20),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Form Scrollable Body
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Identification & Priorité
                        _buildSectionHeader('1. Identification & Priorité'),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _nameController,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF09090B)),
                                decoration: _inputDecoration(
                                  label: 'Nom de la règle *',
                                  hint: 'Ex: Housing Bank - Commission Remise Chèque',
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire' : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _priorityController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF09090B)),
                                decoration: _inputDecoration(
                                  label: 'Priorité',
                                  hint: '10',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Portée d'application
                        _buildSectionHeader('2. Portée d\'application'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: widget.bankAccounts.any((b) => b.id == _selectedBankCompteId) ? _selectedBankCompteId : null,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
                                decoration: _inputDecoration(label: 'Compte Banque'),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Toutes banques (Règle globale)', overflow: TextOverflow.ellipsis),
                                  ),
                                  ...widget.bankAccounts.map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text('${b.code} - ${b.libelle}', overflow: TextOverflow.ellipsis),
                                  )),
                                ],
                                onChanged: (val) => setState(() => _selectedBankCompteId = val),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: _selectedTxTypeId,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
                                decoration: _inputDecoration(label: 'Type d\'opération bancaire'),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Tous types d\'opérations', overflow: TextOverflow.ellipsis),
                                  ),
                                  ...widget.transactionTypes.map((t) => DropdownMenuItem(
                                    value: t.id,
                                    child: Text(t.label, overflow: TextOverflow.ellipsis),
                                  )),
                                ],
                                onChanged: (val) => setState(() => _selectedTxTypeId = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Compte de Charge
                        DropdownButtonFormField<String>(
                          value: widget.expenseAccounts.any((c) => c.id == _selectedChargeCompteId)
                              ? _selectedChargeCompteId
                              : (widget.expenseAccounts.isNotEmpty ? widget.expenseAccounts.first.id : null),
                          isExpanded: true,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
                          decoration: _inputDecoration(label: 'Compte de Frais / Charge (COMPTES) *'),
                          items: widget.expenseAccounts.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.code} - ${c.libelle} (${c.typeCompte?.label ?? "Charge"})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedChargeCompteId = val);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Section 3: Calcul & Barème
                        _buildSectionHeader('3. Barème & Méthode de Calcul'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<CalcMethod>(
                                value: _calcMethod,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
                                decoration: _inputDecoration(label: 'Méthode de calcul'),
                                items: CalcMethod.values.map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.label, overflow: TextOverflow.ellipsis),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _calcMethod = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: DropdownButtonFormField<FeeBaseType>(
                                value: _baseType,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
                                decoration: _inputDecoration(label: 'Assiette de calcul'),
                                items: FeeBaseType.values.map((b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(b.label, overflow: TextOverflow.ellipsis),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _baseType = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Montants selon méthode
                        if (_calcMethod == CalcMethod.fixed || _calcMethod == CalcMethod.perCheque)
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF09090B)),
                            decoration: _inputDecoration(
                              label: _calcMethod == CalcMethod.perCheque
                                  ? 'Montant fixe par chèque (DZD)'
                                  : 'Montant fixe de la commission (DZD)',
                              suffix: 'DZD',
                            ),
                          ),
                        if (_calcMethod == CalcMethod.percent || _calcMethod == CalcMethod.percentWithMinMax) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _percentController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF09090B)),
                                  decoration: _inputDecoration(label: 'Pourcentage (%)', suffix: '%'),
                                ),
                              ),
                              if (_calcMethod == CalcMethod.percentWithMinMax) ...[
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _minAmountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF09090B)),
                                    decoration: _inputDecoration(label: 'Min (DZD)', suffix: 'DZD'),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _maxAmountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF09090B)),
                                    decoration: _inputDecoration(label: 'Max (DZD)', suffix: 'DZD'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        // Règle parente & TVA
                        if (_baseType == FeeBaseType.parentRuleAmount) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Cascade TVA / Règle Parente',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String?>(
                                        value: _parentRuleId,
                                        isExpanded: true,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF09090B)),
                                        decoration: _inputDecoration(label: 'Règle parente déclenchante'),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('Somme de toutes les commissions', overflow: TextOverflow.ellipsis),
                                          ),
                                          ...widget.existingRules.where((r) => r.id != widget.rule?.id).map((r) => DropdownMenuItem(
                                            value: r.id,
                                            child: Text(cleanMojibake(r.name), overflow: TextOverflow.ellipsis),
                                          )),
                                        ],
                                        onChanged: (val) => setState(() => _parentRuleId = val),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _taxRatePercentController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 14, color: Color(0xFF09090B)),
                                        decoration: _inputDecoration(label: 'Taux TVA (%)', suffix: '%'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Section 4: Options
                        _buildSectionHeader('4. Options & Statut'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE4E4E7)),
                                ),
                                child: SwitchListTile(
                                  title: const Text('Règle active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF18181B))),
                                  subtitle: const Text('S\'applique automatiquement aux opérations', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                                  value: _active,
                                  activeThumbColor: const Color(0xFF2563EB),
                                  onChanged: (val) => setState(() => _active = val),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE4E4E7)),
                                ),
                                child: SwitchListTile(
                                  title: const Text('Cumulatif', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF18181B))),
                                  subtitle: const Text('S\'ajoute en sus des autres règles applicables', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                                  value: _isCumulative,
                                  activeThumbColor: const Color(0xFF2563EB),
                                  onChanged: (val) => setState(() => _isCumulative = val),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(top: BorderSide(color: Color(0xFFF4F4F5))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF52525B),
                        side: const BorderSide(color: Color(0xFFE4E4E7)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _saving ? 'Enregistrement...' : (isEdit ? 'Enregistrer les modifications' : 'Créer la règle'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.3,
      ),
    );
  }

  InputDecoration _inputDecoration({String? label, String? hint, String? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)),
      suffixText: suffix,
      suffixStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E4E7))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E4E7))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
    );
  }
}
