import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../data/models/compte.dart';

Future<bool> showNewAccountDialog(
  BuildContext context, {
  required List<Compte> accounts,
  required Set<String> accountIdsWithMovements,
  String? defaultParentId,
  required Future<void> Function(
    String code,
    String libelle,
    String? parentId,
    CompteType? typeCompte, {
    bool isDevise,
    String? codeDevise,
  }) onSave,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => NewAccountDialog(
      accounts: accounts,
      accountIdsWithMovements: accountIdsWithMovements,
      defaultParentId: defaultParentId,
      onSave: onSave,
    ),
  ).then((v) => v ?? false);
}

class NewAccountDialog extends StatefulWidget {
  const NewAccountDialog({
    super.key,
    required this.accounts,
    required this.accountIdsWithMovements,
    this.defaultParentId,
    required this.onSave,
  });

  final List<Compte> accounts;
  final Set<String> accountIdsWithMovements;
  final String? defaultParentId;
  final Future<void> Function(
    String code,
    String libelle,
    String? parentId,
    CompteType? typeCompte, {
    bool isDevise,
    String? codeDevise,
  }) onSave;

  @override
  State<NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<NewAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _libelleController = TextEditingController();
  final _codeDeviseController = TextEditingController(text: 'EUR');
  bool _isDevise = false;
  String? _parentId;
  CompteType? _selectedType;
  bool _typeManuallySet = false; // true once user explicitly picks a type
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    // Default parent is TOUS LES COMPTES (code '0') if not specified
    if (widget.defaultParentId != null) {
      _parentId = widget.defaultParentId;
    } else {
      final rootAccount = widget.accounts.where((a) => a.code == '0').firstOrNull;
      _parentId = rootAccount?.id ?? (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
    }
    _updateTypeFromParent(_parentId);
  }

  void _updateTypeFromParent(String? parentId) {
    // Never auto-override a type the user explicitly chose
    if (_typeManuallySet) return;
    if (parentId == null) {
      _selectedType ??= CompteType.recetteDepense;
      return;
    }
    final parent = widget.accounts.firstWhere((a) => a.id == parentId, orElse: () => widget.accounts.first);
    // Auto-detect from NSM position — only if user hasn't set it manually
    final parentType = parent.resolveEffectiveType(widget.accounts);
    _selectedType = parentType;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _libelleController.dispose();
    _codeDeviseController.dispose();
    super.dispose();
  }

  List<Compte> get _eligibleParentAccounts {
    return widget.accounts.where((account) {
      // Rule: if an account already has movements in MovementsTrisor table, it cannot be a parent!
      return !widget.accountIdsWithMovements.contains(account.id);
    }).toList();
  }

  bool get _isCaisseOrBanque =>
      _selectedType == CompteType.caisse || _selectedType == CompteType.banque;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await widget.onSave(
        _codeController.text.trim(),
        _libelleController.text.trim(),
        _parentId,
        _selectedType,
        isDevise: _isCaisseOrBanque && _isDevise,
        codeDevise: (_isCaisseOrBanque && _isDevise)
            ? _codeDeviseController.text.trim().toUpperCase()
            : null,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Impossible de créer le compte: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibleParents = _eligibleParentAccounts;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_tree_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nouveau Compte',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Ajouter un sous-compte dans le plan comptable',
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

                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Code de compte *',
                    hintText: 'Ex: 611, 533...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le code est obligatoire';
                    }
                    if (value.trim().length > 20) {
                      return 'Code trop long (max 20 caractères)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _libelleController,
                  decoration: InputDecoration(
                    labelText: 'Nom / Libellé du compte *',
                    hintText: 'Ex: Achats consommables, Caisse chantier...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est obligatoire';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _parentId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Compte Parent *',
                    helperText: 'Chaque compte doit avoir un parent (défaut: TOUS LES COMPTES)',
                    helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: [
                    for (final account in eligibleParents)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  validator: (v) => v == null ? 'Veuillez sélectionner un compte parent' : null,
                  onChanged: (value) {
                    setState(() {
                      _parentId = value;
                      _updateTypeFromParent(value);
                    });
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<CompteType>(
                  value: _selectedType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Type de compte *',
                    helperText: 'Auto-déterminé par la position dans l\'arborescence (ou personnalisé)',
                    helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: [
                    for (final t in CompteType.values)
                      DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedType = value;
                    _typeManuallySet = true;
                  }),
                ),

                if (_isCaisseOrBanque) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDevise ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isDevise ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _isDevise,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) => setState(() => _isDevise = val ?? false),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isDevise = !_isDevise),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Compte en Devise étrangère (EUR, USD, etc.)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: _isDevise ? const Color(0xFF065F46) : const Color(0xFF374151),
                                      ),
                                    ),
                                    const Text(
                                      'Toutes les opérations nécessiteront un taux de change en DZD',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isDevise) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const SizedBox(width: 44),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: ['EUR', 'USD', 'GBP', 'CAD', 'CHF', 'SAR', 'AED', 'TRY']
                                          .contains(_codeDeviseController.text.trim().toUpperCase())
                                      ? _codeDeviseController.text.trim().toUpperCase()
                                      : 'EUR',
                                  decoration: InputDecoration(
                                    labelText: 'Symbole / Code Devise',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'EUR', child: Text('EUR (€) - Euro')),
                                    DropdownMenuItem(value: 'USD', child: Text('USD (\$) - Dollar américain')),
                                    DropdownMenuItem(value: 'GBP', child: Text('GBP (£) - Livre sterling')),
                                    DropdownMenuItem(value: 'CAD', child: Text('CAD - Dollar canadien')),
                                    DropdownMenuItem(value: 'CHF', child: Text('CHF - Franc suisse')),
                                    DropdownMenuItem(value: 'SAR', child: Text('SAR - Riyal saoudien')),
                                    DropdownMenuItem(value: 'AED', child: Text('AED - Dirham EAU')),
                                    DropdownMenuItem(value: 'TRY', child: Text('TRY - Livre turque')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _codeDeviseController.text = val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _saveError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.brickEmber),
                    ),
                  ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Créer le compte'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
