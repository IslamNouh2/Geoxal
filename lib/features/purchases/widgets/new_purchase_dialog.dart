import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/security/session.dart';
import '../../../../data/datasources/departement_datasource.dart';
import '../../../../data/datasources/finance_datasource.dart';
import '../../../../data/datasources/settings_datasource.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/models/departement.dart';
import '../../../../data/models/tiers.dart';
import '../../../../data/repositories/achat_repository.dart';
import '../../../../data/repositories/departement_repository.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/tiers_repository.dart';
import '../../accounting/widgets/account_tree_picker.dart';
import '../../customers/widgets/new_tiers_dialog.dart';

Future<bool> showNewPurchaseDialog(
  BuildContext context, {
  required AchatRepository achatRepository,
  required TiersRepository tiersRepository,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => NewPurchaseDialog(
      achatRepository: achatRepository,
      tiersRepository: tiersRepository,
    ),
  ).then((v) => v ?? false);
}

class NewPurchaseDialog extends StatefulWidget {
  const NewPurchaseDialog({
    super.key,
    required this.achatRepository,
    required this.tiersRepository,
  });

  final AchatRepository achatRepository;
  final TiersRepository tiersRepository;

  @override
  State<NewPurchaseDialog> createState() => _NewPurchaseDialogState();
}

class _NewPurchaseDialogState extends State<NewPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numFactureController = TextEditingController();
  final _numFactureFournisseurController = TextEditingController();
  final _montantController = TextEditingController();
  final _observationController = TextEditingController();
  late final TextEditingController _dateController;

  DateTime _selectedDate = DateTime.now();
  String? _selectedFournisseurId;
  List<Tiers> _fournisseurs = [];

  // Type: Achat vs Charge
  String _selectedType = 'achat'; // 'achat' ou 'charge'

  // Mode de paiement
  String _selectedModePaiement = 'Espèces';
  static const List<String> _modesPaiement = [
    'Espèces',
    'Chèque',
    'Virement bancaire',
    'Versement bancaire',
  ];

  // Départements
  late final DepartementRepository _departementRepo;
  List<Departement> _departements = [];
  String? _selectedDepartementId;

  // Paramètres & Compte
  late final SettingsRepository _settingsRepo;
  late final FinanceRepository _financeRepo;
  bool _allowSelectCompte = false;
  String? _selectedCompteId;
  Compte? _selectedCompte;
  List<Compte> _allAccounts = [];

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
    );
    final db = Database.instance;
    _departementRepo = DepartementRepository(DepartementDataSource(db));
    _settingsRepo = SettingsRepository(SettingsDataSource(db));
    _financeRepo = FinanceRepository(FinanceDataSource(db));
    _initData();
  }

  @override
  void dispose() {
    _numFactureController.dispose();
    _numFactureFournisseurController.dispose();
    _montantController.dispose();
    _observationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final nextNum = await widget.achatRepository.getNextNumFacture();
      final suppliers = await widget.tiersRepository.getFournisseurs();
      final deps = await _departementRepo.getDepartements(onlyActive: true);
      final accounts = await _financeRepo.getAccounts();
      final allowCompte = await _settingsRepo.getBoolSetting('ACHAT_ALLOW_SELECT_COMPTE');
      final defCompteId = await _settingsRepo.getSettingValue('ACHAT_DEFAULT_COMPTE_ID') ?? '3b78186d-3835-46a7-99d7-f2c3a69523f9';

      Compte? initialCompte;
      try {
        initialCompte = accounts.firstWhere((a) => a.id == defCompteId);
      } catch (_) {
        if (accounts.isNotEmpty) initialCompte = accounts.first;
      }

      if (!mounted) return;
      setState(() {
        _numFactureController.text = nextNum;
        _fournisseurs = suppliers;
        _departements = deps;
        _allAccounts = accounts;
        _allowSelectCompte = allowCompte;
        _selectedCompteId = initialCompte?.id;
        _selectedCompte = initialCompte;
        if (deps.isNotEmpty) _selectedDepartementId = deps.first.id;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
        _dateController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  /// Prédicat pour filtrer uniquement les sous-comptes de Charges (Classe 6)
  bool _isChargeCompte(Compte compte) {
    if (compte.code.startsWith('6')) return true;
    final parentCharges = _allAccounts.cast<Compte?>().firstWhere(
      (a) => a?.code == '60' || a?.code == '6' || (a?.libelle.toLowerCase().contains('charge') ?? false),
      orElse: () => null,
    );
    if (parentCharges != null && parentCharges.isAncestorOf(compte)) return true;
    return false;
  }

  Future<void> _pickCompte() async {
    final isCharge = _selectedType == 'charge';
    final picked = await showAccountTreePickerDialog(
      context,
      accounts: _allAccounts,
      selectedAccount: _selectedCompte,
      filterPredicate: isCharge ? _isChargeCompte : null,
    );
    if (picked != null) {
      setState(() {
        _selectedCompte = picked;
        _selectedCompteId = picked.id;
      });
    }
  }

  Future<void> _quickAddFournisseur() async {
    final newSupplier = await showNewTiersDialog(
      context,
      repository: widget.tiersRepository,
      defaultTypeId: 2, // Fournisseur
    );
    if (newSupplier != null) {
      setState(() {
        _fournisseurs = [..._fournisseurs, newSupplier];
        _selectedFournisseurId = newSupplier.id;
      });
    }
  }

  void _onTypeChanged(String? newType) {
    if (newType == null) return;
    setState(() {
      _selectedType = newType;
      if (newType == 'charge') {
        // Find first charge sub-account if current is not charge
        if (_selectedCompte == null || !_isChargeCompte(_selectedCompte!)) {
          final firstChargeLeaf = _allAccounts.cast<Compte?>().firstWhere(
            (a) => a != null && a.isLeaf && _isChargeCompte(a),
            orElse: () => null,
          );
          _selectedCompte = firstChargeLeaf;
          _selectedCompteId = firstChargeLeaf?.id;
        }
      } else {
        // Reset to default achat compte if needed
        final defCompte = _allAccounts.cast<Compte?>().firstWhere(
          (a) => a?.id == '3b78186d-3835-46a7-99d7-f2c3a69523f9',
          orElse: () => _allAccounts.isNotEmpty ? _allAccounts.first : null,
        );
        _selectedCompte = defCompte;
        _selectedCompteId = defCompte?.id;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedFournisseurId == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner un fournisseur.');
      return;
    }

    final montant = double.tryParse(
      _montantController.text.trim().replaceAll(',', '.'),
    );
    if (montant == null || montant <= 0) {
      setState(() => _errorMessage = 'Le montant doit être supérieur à 0.');
      return;
    }

    if (_selectedType == 'charge' && _selectedCompteId == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner le compte de charge correspondant.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final isAdmin = Session.user?.isAdmin ?? false;
      // Admin: use the (possibly edited) field; non-admin: pass null → auto-generated
      final numToSave = isAdmin ? _numFactureController.text.trim() : null;

      final savedNum = await widget.achatRepository.createFactureAchat(
        tiersId: _selectedFournisseurId!,
        numFacture: numToSave,
        numFactureFournisseur: _numFactureFournisseurController.text.trim().isEmpty
            ? null
            : _numFactureFournisseurController.text.trim(),
        dateFacture: _selectedDate,
        montant: montant,
        designation: _observationController.text.trim().isEmpty
            ? null
            : _observationController.text.trim(),
        userId: Session.user?.id ?? 'SYSTEM',
        departementId: _selectedDepartementId,
        compteId: _selectedCompteId,
        modePaiement: _selectedModePaiement,
        typeAchat: _selectedType.toUpperCase(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      if (isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facture $savedNum créée avec succès'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Erreur lors de la création de la facture: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCompteSection = _selectedType == 'charge' || _allowSelectCompte;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _loading
              ? const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()))
              : Form(
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
                              child: const Icon(
                                Icons.shopping_cart_rounded,
                                color: Color(0xFF2563EB),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nouvelle Facture Achat / Charge',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.deepSpaceBlue,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Enregistrer un achat fournisseur ou une charge avec arborescence comptable',
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
                                Expanded(
                                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Type selector: Achat vs Charge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Text('Type d\'opération :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(width: 16),
                              ChoiceChip(
                                label: const Text('Achat Standard'),
                                selected: _selectedType == 'achat',
                                selectedColor: const Color(0xFF2563EB),
                                labelStyle: TextStyle(
                                  color: _selectedType == 'achat' ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) => _onTypeChanged('achat'),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                label: const Text('Charge d\'exploitation (Classe 6)'),
                                selected: _selectedType == 'charge',
                                selectedColor: const Color(0xFFE11D48),
                                labelStyle: TextStyle(
                                  color: _selectedType == 'charge' ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) => _onTypeChanged('charge'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Date & N° Facture
                        Builder(builder: (context) {
                          final isAdmin = Session.user?.isAdmin ?? false;
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Date Facture *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _dateController,
                                      readOnly: true,
                                      onTap: _pickDate,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    Row(
                                      children: [
                                        const Text('N° Facture', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 6),
                                        if (isAdmin)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('Admin', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.lock_outline, size: 10, color: Colors.grey.shade600),
                                                const SizedBox(width: 3),
                                                Text('Auto', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _numFactureController,
                                      readOnly: !isAdmin,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isAdmin ? Colors.black87 : Colors.grey.shade700,
                                      ),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(
                                          isAdmin ? Icons.edit_outlined : Icons.lock_outline,
                                          size: 16,
                                          color: isAdmin ? const Color(0xFF2563EB) : Colors.grey,
                                        ),
                                        filled: !isAdmin,
                                        fillColor: isAdmin ? null : Colors.grey.shade100,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        hintText: isAdmin ? 'N° modifiable' : null,
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),

                        const SizedBox(height: 16),

                        // N° Facture Fournisseur (référence externe)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('N° Facture Fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Facultatif', style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _numFactureFournisseurController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF2563EB)),
                                hintText: 'Ex: 2026/FAC-00123',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                helperText: 'Numéro imprimé sur la facture physique du fournisseur',
                                helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Fournisseur
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Fournisseur *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                TextButton.icon(
                                  onPressed: _quickAddFournisseur,
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                                  label: const Text('Nouveau Fournisseur', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _selectedFournisseurId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.business_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: 'Sélectionner un fournisseur',
                              ),
                              items: _fournisseurs.map((s) {
                                return DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Text(s.nom, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedFournisseurId = val),
                              validator: (v) => v == null ? 'Veuillez sélectionner un fournisseur' : null,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Montant & Mode de Paiement
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Montant *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _montantController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      prefixText: 'DA ',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Requis';
                                      final n = double.tryParse(v.trim().replaceAll(',', '.'));
                                      if (n == null || n <= 0) return 'Montant invalide';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Mode de Paiement *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedModePaiement,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.payment_rounded, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    items: _modesPaiement.map((m) {
                                      return DropdownMenuItem<String>(
                                        value: m,
                                        child: Text(m),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedModePaiement = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Département
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Département', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedDepartementId,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.apartment_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: _departements.isEmpty ? 'Aucun département configuré' : 'Sélectionner un département',
                              ),
                              items: _departements.map((d) {
                                return DropdownMenuItem<String>(
                                  value: d.id,
                                  child: Text('${d.code} - ${d.nom}'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedDepartementId = val),
                            ),
                          ],
                        ),

                        // Compte sélectionné (Auto pour charge, ou selon paramètre pour achat)
                        if (showCompteSection) ...[
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _selectedType == 'charge'
                                        ? 'Sous-compte de Charge * (Arborescence Classe 6)'
                                        : 'Compte d\'Achat (Option activée dans Paramètres)',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  if (_selectedType == 'charge')
                                    const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _pickCompte,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _selectedType == 'charge' ? const Color(0xFFE11D48) : const Color(0xFFD1D5DB),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: _selectedType == 'charge' ? const Color(0xFFFFF1F2) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.account_tree_outlined,
                                        size: 18,
                                        color: _selectedType == 'charge' ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _selectedCompte != null
                                              ? '${_selectedCompte!.code} - ${_selectedCompte!.libelle}'
                                              : (_selectedType == 'charge'
                                                  ? 'Cliquer pour choisir dans l\'arborescence des charges'
                                                  : 'Sélectionner un compte'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: _selectedType == 'charge' ? FontWeight.w600 : FontWeight.normal,
                                            color: _selectedCompte != null ? Colors.black87 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Observation (Facultatif)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Observation (facultatif)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _observationController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Notes ou observations sur cet achat / charge...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                              child: const Text('Annuler'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedType == 'charge' ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _saving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check, size: 18),
                              label: Text(_saving ? 'Enregistrement...' : 'Créer la Facture'),
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
}

