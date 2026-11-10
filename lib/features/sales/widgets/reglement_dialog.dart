import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/security/session.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/datasources/departement_datasource.dart';
import '../../../../data/datasources/finance_datasource.dart';
import '../../../../data/datasources/reglement_datasource.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/models/departement.dart';
import '../../../../data/models/facture_achat.dart';
import '../../../../data/models/facture_vente.dart';
import '../../../../data/models/reglement.dart';
import '../../../../data/models/tiers.dart';
import '../../../../data/repositories/departement_repository.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../data/repositories/reglement_repository.dart';

enum ReglementDialogMode {
  versement, // Distribute across unpaid invoices (Auto from oldest to newest or manual selection)
  regle,     // Pay against one specific invoice
  edit,      // Update existing reglement
}

Future<bool> showReglementDialog(
  BuildContext context, {
  required Tiers tiers,
  required String typeReglement, // 'CLIENT' ou 'FOURNISSEUR'
  required ReglementDialogMode mode,
  FactureVente? specificFactureVente,
  FactureAchat? specificFactureAchat,
  Reglement? existingReglement,
  required List<FactureVente> allClientFactures,
  required List<FactureAchat> allFournisseurFactures,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ReglementDialog(
      tiers: tiers,
      typeReglement: typeReglement,
      mode: mode,
      specificFactureVente: specificFactureVente,
      specificFactureAchat: specificFactureAchat,
      existingReglement: existingReglement,
      allClientFactures: allClientFactures,
      allFournisseurFactures: allFournisseurFactures,
    ),
  ).then((v) => v ?? false);
}

class ReglementDialog extends StatefulWidget {
  final Tiers tiers;
  final String typeReglement; // 'CLIENT' ou 'FOURNISSEUR'
  final ReglementDialogMode mode;
  final FactureVente? specificFactureVente;
  final FactureAchat? specificFactureAchat;
  final Reglement? existingReglement;
  final List<FactureVente> allClientFactures;
  final List<FactureAchat> allFournisseurFactures;

  const ReglementDialog({
    super.key,
    required this.tiers,
    required this.typeReglement,
    required this.mode,
    this.specificFactureVente,
    this.specificFactureAchat,
    this.existingReglement,
    required this.allClientFactures,
    required this.allFournisseurFactures,
  });

  @override
  State<ReglementDialog> createState() => _ReglementDialogState();
}

class _ReglementDialogState extends State<ReglementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _observationController = TextEditingController();
  final _numChequeController = TextEditingController();
  late final TextEditingController _dateController;
  late final TextEditingController _dateChequeController;

  DateTime _selectedDate = DateTime.now();
  DateTime _dateCheque = DateTime.now();

  late final ReglementRepository _reglementRepo;
  late final FinanceRepository _financeRepo;
  late final DepartementRepository _departementRepo;

  String _selectedModePaiement = 'Espèces';
  static const List<String> _modes = [
    'Espèces',
    'Chèque',
    'Virement bancaire',
    'Versement bancaire',
  ];

  List<Compte> _allAccounts = [];
  List<Compte> _caissesOrBanques = [];
  String? _selectedCaisseId;

  List<Departement> _departements = [];
  String? _selectedDepartementId;

  bool _isAutoDistribution = true; // Auto vs Manual selection in versement mode
  final Map<String, double> _manualAllocations = {};

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final db = Database.instance;
    _reglementRepo = ReglementRepository(ReglementDataSource(db));
    _financeRepo = FinanceRepository(FinanceDataSource(db));
    _departementRepo = DepartementRepository(DepartementDataSource(db));

    if (widget.existingReglement != null) {
      _selectedDate = widget.existingReglement!.dateReglement;
      _montantController.text = widget.existingReglement!.montant.toStringAsFixed(2);
      _selectedModePaiement = widget.existingReglement!.modePaiement;
      _selectedDepartementId = widget.existingReglement!.departementId;
      _selectedCaisseId = widget.existingReglement!.compteCaisseId;
      _observationController.text = widget.existingReglement!.observation ?? '';
      _numChequeController.text = widget.existingReglement!.numCheque ?? '';
      if (widget.existingReglement!.dateCheque != null) {
        _dateCheque = widget.existingReglement!.dateCheque!;
      }
    } else if (widget.mode == ReglementDialogMode.regle) {
      final targetAmount = widget.specificFactureVente?.resteAPayer ?? widget.specificFactureAchat?.resteAPayer ?? 0.0;
      _montantController.text = targetAmount > 0 ? targetAmount.toStringAsFixed(2) : '';
    }

    _dateController = TextEditingController(
      text: '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
    );
    _dateChequeController = TextEditingController(
      text: '${_dateCheque.year.toString().padLeft(4, '0')}-${_dateCheque.month.toString().padLeft(2, '0')}-${_dateCheque.day.toString().padLeft(2, '0')}',
    );

    _initData();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _observationController.dispose();
    _numChequeController.dispose();
    _dateController.dispose();
    _dateChequeController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final accounts = await _financeRepo.getAccounts();
      final deps = await _departementRepo.getDepartements(onlyActive: true);

      if (!mounted) return;
      setState(() {
        _allAccounts = accounts;
        _departements = deps;
        _updateFilteredAccounts();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateFilteredAccounts() {
    final isEspeces = _selectedModePaiement == 'Espèces';
    List<Compte> filtered;

    if (isEspeces) {
      // Afficher uniquement les caisses
      filtered = _allAccounts.where((a) {
        if (!a.isLeaf) return false;
        final type = a.resolveEffectiveType(_allAccounts);
        return type == CompteType.caisse;
      }).toList();
    } else {
      // Chèque, Virement bancaire, Versement bancaire -> Afficher uniquement les banques
      filtered = _allAccounts.where((a) {
        if (!a.isLeaf) return false;
        final type = a.resolveEffectiveType(_allAccounts);
        return type == CompteType.banque || a.code.startsWith('51');
      }).toList();
    }

    _caissesOrBanques = filtered;
    if (_caissesOrBanques.isNotEmpty) {
      if (_selectedCaisseId == null || !_caissesOrBanques.any((a) => a.id == _selectedCaisseId)) {
        _selectedCaisseId = _caissesOrBanques.first.id;
      }
    } else {
      _selectedCaisseId = null;
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
        _dateChequeController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  /// Calcule les factures non soldées du client ou fournisseur
  List<dynamic> get _unpaidInvoices {
    if (widget.typeReglement == 'CLIENT') {
      return widget.allClientFactures
          .where((f) => f.tiersId == widget.tiers.id && !f.isSoldee)
          .toList()
        ..sort((a, b) => a.dateFacture.compareTo(b.dateFacture)); // Ancien -> Récent
    } else {
      return widget.allFournisseurFactures
          .where((f) => f.tiersId == widget.tiers.id && !f.isSoldee)
          .toList()
        ..sort((a, b) => a.dateFacture.compareTo(b.dateFacture));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedCaisseId == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner une caisse ou une banque.');
      return;
    }

    final montant = double.tryParse(_montantController.text.trim().replaceAll(',', '.'));
    if (montant == null || montant <= 0) {
      setState(() => _errorMessage = 'Le montant doit être supérieur à 0.');
      return;
    }

    final allocations = <Map<String, dynamic>>[];

    // 1. Règle spécifique (Bouton Règle sur une facture précise)
    if (widget.mode == ReglementDialogMode.regle) {
      final fv = widget.specificFactureVente;
      final fa = widget.specificFactureAchat;
      final reste = fv?.resteAPayer ?? fa?.resteAPayer ?? 0.0;
      final factId = fv?.id ?? fa?.id ?? '';
      final factType = fv != null ? 'VENTE' : 'ACHAT';

      if (montant > reste) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Montant supérieur au reste'),
              ],
            ),
            content: Text(
              'Le montant saisi (${formatMoney(montant)}) est supérieur au reste à payer de la facture (${formatMoney(reste)}).\n\n'
              'Voulez-vous affecter ${formatMoney(reste)} à cette facture et créer le règlement complet sous forme de versement pour imputer le reste sur les autres factures ?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmer en Versement'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        // Imputer le montant: reste sur la facture ciblée, et le reliquat sur les autres plus anciennes
        allocations.add({'factureId': factId, 'factureType': factType, 'montant': reste});
        double reliquat = montant - reste;

        for (final inv in _unpaidInvoices) {
          final id = inv.id as String;
          if (id == factId) continue;
          if (reliquat <= 0.001) break;
          final r = inv.resteAPayer as double;
          final alloc = reliquat >= r ? r : reliquat;
          allocations.add({
            'factureId': id,
            'factureType': inv is FactureVente ? 'VENTE' : 'ACHAT',
            'montant': alloc,
          });
          reliquat -= alloc;
        }
      } else {
        allocations.add({'factureId': factId, 'factureType': factType, 'montant': montant});
      }
    } else if (widget.mode == ReglementDialogMode.versement) {
      // 2. Mode Versement (Auto ancien -> récent, ou manuel)
      if (_isAutoDistribution) {
        double restantADistribuer = montant;
        for (final inv in _unpaidInvoices) {
          if (restantADistribuer <= 0.001) break;
          final reste = inv.resteAPayer as double;
          final aDistribuer = restantADistribuer >= reste ? reste : restantADistribuer;
          allocations.add({
            'factureId': inv.id as String,
            'factureType': inv is FactureVente ? 'VENTE' : 'ACHAT',
            'montant': aDistribuer,
          });
          restantADistribuer -= aDistribuer;
        }
      } else {
        // Mode manuel
        double totalManual = 0.0;
        _manualAllocations.forEach((factId, val) {
          if (val > 0.001) {
            totalManual += val;
            allocations.add({
              'factureId': factId,
              'factureType': widget.typeReglement == 'CLIENT' ? 'VENTE' : 'ACHAT',
              'montant': val,
            });
          }
        });

        if (totalManual > montant + 0.01) {
          setState(() => _errorMessage = 'Le total alloué (${formatMoney(totalManual)}) dépasse le montant saisi.');
          return;
        }
      }
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      if (widget.existingReglement != null) {
        await _reglementRepo.updateReglement(
          reglementId: widget.existingReglement!.id,
          dateReglement: _selectedDate,
          montant: montant,
          modePaiement: _selectedModePaiement,
          compteCaisseId: _selectedCaisseId!,
          departementId: _selectedDepartementId,
          numCheque: _numChequeController.text.trim().isEmpty ? null : _numChequeController.text.trim(),
          dateCheque: _selectedModePaiement == 'Chèque' ? _dateCheque : null,
          observation: _observationController.text.trim().isEmpty ? null : _observationController.text.trim(),
          allocations: allocations,
        );
      } else {
        await _reglementRepo.createReglement(
          typeReglement: widget.typeReglement,
          tiersId: widget.tiers.id,
          compteCaisseId: _selectedCaisseId!,
          dateReglement: _selectedDate,
          montant: montant,
          modePaiement: _selectedModePaiement,
          departementId: _selectedDepartementId,
          numCheque: _numChequeController.text.trim().isEmpty ? null : _numChequeController.text.trim(),
          dateCheque: _selectedModePaiement == 'Chèque' ? _dateCheque : null,
          observation: _observationController.text.trim().isEmpty ? null : _observationController.text.trim(),
          userId: Session.user?.id ?? 'SYSTEM',
          allocations: allocations,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Erreur lors de l\'enregistrement du règlement: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existingReglement != null
        ? 'Modifier Règlement'
        : widget.mode == ReglementDialogMode.regle
            ? 'Régler la Facture'
            : 'Nouveau Versement Client / Fournisseur';

    final isCheque = _selectedModePaiement == 'Chèque';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
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
                              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.deepSpaceBlue),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.tiers.nom} (${widget.typeReglement == 'CLIENT' ? 'Client' : 'Fournisseur'})',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

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

                        // Date & Montant
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date Règlement *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Mode de Paiement & Sélection Caisse/Banque
                        Row(
                          children: [
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
                                    items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedModePaiement = val;
                                          _updateFilteredAccounts();
                                        });
                                      }
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
                                  Text(
                                    _selectedModePaiement == 'Espèces' ? 'Compte Caisse *' : 'Compte Banque *',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCaisseId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        _selectedModePaiement == 'Espèces' ? Icons.point_of_sale_rounded : Icons.account_balance_rounded,
                                        size: 18,
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      hintText: _caissesOrBanques.isEmpty ? 'Aucun compte disponible' : 'Choisir',
                                    ),
                                    items: _caissesOrBanques.map((c) {
                                      return DropdownMenuItem(
                                        value: c.id,
                                        child: Text('${c.code} - ${c.libelle}', overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedCaisseId = val),
                                    validator: (v) => v == null ? 'Veuillez sélectionner un compte' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Champs spécifiques chèque
                        if (isCheque) ...[
                          if (widget.typeReglement == 'CLIENT') ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Remise de chèques : Ce chèque sera placé en portefeuille. Le mouvement bancaire et les règles de frais seront appliqués lors de la validation du bordereau de remise en banque.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('N° Chèque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _numChequeController,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 18),
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
                                    const Text('Date d\'échéance du Chèque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _dateChequeController,
                                      readOnly: true,
                                      onTap: _pickDateCheque,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.event, size: 18),
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
                                hintText: _departements.isEmpty ? 'Aucun département' : 'Sélectionner un département',
                              ),
                              items: _departements.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.code} - ${d.nom}'))).toList(),
                              onChanged: (val) => setState(() => _selectedDepartementId = val),
                            ),
                          ],
                        ),

                        // Section Répartition Factures en mode Versement
                        if (widget.mode == ReglementDialogMode.versement) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Mode d\'affectation des factures :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Row(
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Auto (Ancien → Récent)'),
                                          selected: _isAutoDistribution,
                                          onSelected: (_) => setState(() => _isAutoDistribution = true),
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('Sélection manuelle'),
                                          selected: !_isAutoDistribution,
                                          onSelected: (_) => setState(() => _isAutoDistribution = false),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_unpaidInvoices.isEmpty)
                                  const Text('Aucune facture impayée pour ce tiers.', style: TextStyle(fontSize: 12, color: Colors.grey))
                                else
                                  ..._unpaidInvoices.map((inv) {
                                    final numFact = inv.numFacture as String;
                                    final dt = inv.dateFacture as DateTime;
                                    final montantTot = inv.montant as double;
                                    final reste = inv.resteAPayer as double;
                                    final id = inv.id as String;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$numFact (${formatDate(dt)}) - Total: ${formatMoney(montantTot)} - Reste: ${formatMoney(reste)}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          if (!_isAutoDistribution)
                                            SizedBox(
                                              width: 130,
                                              height: 36,
                                              child: TextFormField(
                                                initialValue: _manualAllocations[id]?.toStringAsFixed(2) ?? '',
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: const InputDecoration(
                                                  hintText: '0.00',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  border: OutlineInputBorder(),
                                                ),
                                                onChanged: (v) {
                                                  final val = double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
                                                  _manualAllocations[id] = val;
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Observation
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Observation (facultatif)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _observationController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Observation sur ce règlement...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Actions
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
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _saving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check, size: 18),
                              label: Text(_saving ? 'Enregistrement...' : 'Valider le Règlement'),
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


