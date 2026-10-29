import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/security/session.dart';
import '../../../../data/models/tiers.dart';
import '../../../../data/repositories/achat_repository.dart';
import '../../../../data/repositories/tiers_repository.dart';
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
  final _montantController = TextEditingController();
  final _designationController = TextEditingController();
  late final TextEditingController _dateController;

  DateTime _selectedDate = DateTime.now();
  String? _selectedFournisseurId;
  List<Tiers> _fournisseurs = [];
  bool _loadingFournisseurs = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text:
          '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
    );
    _initData();
  }

  @override
  void dispose() {
    _numFactureController.dispose();
    _montantController.dispose();
    _designationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final nextNum = await widget.achatRepository.getNextNumFacture();
      final suppliers = await widget.tiersRepository.getFournisseurs();
      if (!mounted) return;
      setState(() {
        _numFactureController.text = nextNum;
        _fournisseurs = suppliers;
        _loadingFournisseurs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFournisseurs = false);
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

  Future<void> _quickAddSupplier() async {
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

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.achatRepository.createFactureAchat(
        tiersId: _selectedFournisseurId!,
        numFacture: _numFactureController.text.trim(),
        dateFacture: _selectedDate,
        montant: montant,
        designation: _designationController.text.trim().isEmpty
            ? null
            : _designationController.text.trim(),
        userId: Session.user?.id ?? 'SYSTEM',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
                          color: const Color(0xFFEA580C).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: Color(0xFFEA580C),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nouvelle Facture d\'Achat',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepSpaceBlue,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enregistrer un achat / dépense auprès d\'un fournisseur (Doc/database.md)',
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

                  // Num Facture & Date Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('N° Facture Fournisseur *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _numFactureController,
                              decoration: InputDecoration(
                                hintText: 'FA-2026-0001',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Numéro obligatoire';
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
                            const Text('Date de facture *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Fournisseur selection with Quick Add Button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fournisseur *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: _quickAddSupplier,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Nouveau Fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFEA580C),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_loadingFournisseurs)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedFournisseurId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Sélectionner un fournisseur',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: _fournisseurs.map((f) {
                            return DropdownMenuItem<String>(
                              value: f.id,
                              child: Text('${f.nom} ${f.telephone != null ? '(${f.telephone})' : ''}'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedFournisseurId = val),
                          validator: (v) => v == null ? 'Veuillez sélectionner un fournisseur' : null,
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Montant
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Montant Total (DZD) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _montantController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: 'DA ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Montant requis';
                          final num = double.tryParse(v.trim().replaceAll(',', '.'));
                          if (num == null || num <= 0) return 'Montant invalide';
                          return null;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Désignation
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Désignation / Motif d\'achat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _designationController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Description des marchandises ou services achetés...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
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
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(_saving ? 'Enregistrement...' : 'Enregistrer l\'achat'),
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
