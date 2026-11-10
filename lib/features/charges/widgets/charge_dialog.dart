import 'package:flutter/material.dart';
import '../../../../core/security/session.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/uuid.dart';
import '../../../../data/models/charge.dart';
import '../../../../data/models/compte.dart';

class ChargeDialog extends StatefulWidget {
  final Charge? existingCharge;
  final List<Compte> expenseAccounts;
  final String nextReference;
  final Future<void> Function(Charge charge, bool isNew) onSave;

  const ChargeDialog({
    super.key,
    this.existingCharge,
    required this.expenseAccounts,
    required this.nextReference,
    required this.onSave,
  });

  @override
  State<ChargeDialog> createState() => _ChargeDialogState();
}

class _ChargeDialogState extends State<ChargeDialog> {
  final _formKey = GlobalKey<FormState>();

  late CategorieCharge _categorie;
  late final TextEditingController _refCtrl;
  late final TextEditingController _designationCtrl;
  late final TextEditingController _montantCtrl;
  late final TextEditingController _obsCtrl;

  late DateTime _dateCharge;
  late DateTime _dateCreation;

  // Simple: consumption period
  DateTime? _dateDebutConsommation;
  DateTime? _dateFinConsommation;

  // Amortissable: amortization period
  // Start is automatically charge creation date
  DateTime? _dateFinAmortissement;

  String? _selectedCompteId;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCharge;
    if (c != null) {
      _categorie = c.categorie;
      _refCtrl = TextEditingController(text: c.referance);
      _designationCtrl = TextEditingController(text: c.designation);
      _montantCtrl = TextEditingController(text: c.montantCharge.toStringAsFixed(2));
      _obsCtrl = TextEditingController(text: c.observation ?? '');
      _dateCharge = c.dateCharge;
      _dateCreation = c.dateCreation;
      _dateDebutConsommation = c.dateDebutConsommation;
      _dateFinConsommation = c.dateFinConsommation;
      _dateFinAmortissement = c.dateFinAmortissement;
      _selectedCompteId = c.compteId;
    } else {
      _categorie = CategorieCharge.simple;
      _refCtrl = TextEditingController(text: widget.nextReference);
      _designationCtrl = TextEditingController();
      _montantCtrl = TextEditingController();
      _obsCtrl = TextEditingController();
      _dateCharge = DateTime.now();
      _dateCreation = DateTime.now();
      _dateDebutConsommation = DateTime.now();
      _dateFinConsommation = DateTime.now().add(const Duration(days: 30));
      _dateFinAmortissement = DateTime.now().add(const Duration(days: 365));
      if (widget.expenseAccounts.isNotEmpty) {
        _selectedCompteId = widget.expenseAccounts.first.id;
      }
    }
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _designationCtrl.dispose();
    _montantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCompteId == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner un compte de charges.');
      return;
    }

    // Specific category validations
    if (_categorie == CategorieCharge.simple) {
      if (_dateDebutConsommation == null || _dateFinConsommation == null) {
        setState(() => _errorMessage = 'Veuillez spécifier la période de consommation.');
        return;
      }
      if (_dateFinConsommation!.isBefore(_dateDebutConsommation!)) {
        setState(() => _errorMessage = 'La fin de consommation ne peut pas précéder le début.');
        return;
      }
    } else {
      if (_dateFinAmortissement == null) {
        setState(() => _errorMessage = 'Veuillez spécifier la date de fin d\'amortissement.');
        return;
      }
      if (_dateFinAmortissement!.isBefore(_dateCreation)) {
        setState(() => _errorMessage = 'La date de fin d\'amortissement ne peut pas précéder la date de création.');
        return;
      }
    }

    final montant = double.tryParse(_montantCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (montant <= 0) {
      setState(() => _errorMessage = 'Le montant total doit être supérieur à zéro.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final isNew = widget.existingCharge == null;
      final charge = Charge(
        id: widget.existingCharge?.id ?? Uuid.v4(),
        userId: widget.existingCharge?.userId ?? Session.user?.id ?? '123e4567-e89b-12d3-a456-426614174000',
        dateCreation: _dateCreation,
        referance: _refCtrl.text.trim(),
        dateCharge: _dateCharge,
        compteId: _selectedCompteId!,
        categorie: _categorie,
        currencyCode: 'DZD',
        tauxChange: 1.0,
        amortissable: _categorie == CategorieCharge.amortisable,
        dateDebutConsommation: _categorie == CategorieCharge.simple ? _dateDebutConsommation : null,
        dateFinConsommation: _categorie == CategorieCharge.simple ? _dateFinConsommation : null,
        dateDebutAmortissement: _categorie == CategorieCharge.amortisable ? _dateCreation : null,
        dateFinAmortissement: _categorie == CategorieCharge.amortisable ? _dateFinAmortissement : null,
        montantCharge: montant,
        montantRegle: widget.existingCharge?.montantRegle ?? 0.0,
        designation: _designationCtrl.text.trim(),
        observation: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );

      await widget.onSave(charge, isNew);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Erreur: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existingCharge == null;
    final title = isNew ? 'Nouvelle Charge' : 'Modifier la Charge';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                          const Text('إدارة مصاريف الشركة - Gestion des charges', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type Selection (Segmented)
                      const Text('Catégorie de Charge *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isNew
                                  ? () => setState(() => _categorie = CategorieCharge.simple)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: _categorie == CategorieCharge.simple
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: _categorie == CategorieCharge.simple
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFE2E8F0),
                                    width: _categorie == CategorieCharge.simple ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      color: _categorie == CategorieCharge.simple
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Charge Simple (Périodique)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: _categorie == CategorieCharge.simple
                                                  ? const Color(0xFF1E40AF)
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          const Text(
                                            'Électricité, eau, loyer, internet, abonnements',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: isNew
                                  ? () => setState(() => _categorie = CategorieCharge.amortisable)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: _categorie == CategorieCharge.amortisable
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: _categorie == CategorieCharge.amortisable
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFE2E8F0),
                                    width: _categorie == CategorieCharge.amortisable ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.pie_chart_rounded,
                                      color: _categorie == CategorieCharge.amortisable
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Charge Amortissable',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: _categorie == CategorieCharge.amortisable
                                                  ? const Color(0xFF1E40AF)
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          const Text(
                                            'Matériel, informatique, mobilier, véhicules',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Ref, Date Charge, Montant
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _refCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Référence *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _dateCharge,
                                onPicked: (d) => _dateCharge = d,
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date Charge *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                ),
                                child: Text(formatDate(_dateCharge)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _montantCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Montant Total (DZD) *',
                                border: OutlineInputBorder(),
                                isDense: true,
                                suffixText: 'DZD',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requis';
                                final val = double.tryParse(v.trim().replaceAll(',', '.'));
                                if (val == null || val <= 0) return 'Montant invalide';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Compte de charges (Subtree 60 leaves)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCompteId,
                        decoration: const InputDecoration(
                          labelText: 'Compte de Charges (Plan Comptable) *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: widget.expenseAccounts.map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.code} - ${a.libelle}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedCompteId = v),
                        validator: (v) => v == null ? 'Veuillez sélectionner un compte' : null,
                      ),
                      const SizedBox(height: 16),

                      // Désignation
                      TextFormField(
                        controller: _designationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Désignation *',
                          hintText: 'Ex: Facture Eau Sonelgaz / Ordinateur portable Dell',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                      const SizedBox(height: 16),

                      // Dynamic Section: SIMPLE vs AMORTISSABLE
                      if (_categorie == CategorieCharge.simple) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF2563EB)),
                                  SizedBox(width: 8),
                                  Text('Période de Consommation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _pickDate(
                                        context: context,
                                        initialDate: _dateDebutConsommation ?? DateTime.now(),
                                        onPicked: (d) => _dateDebutConsommation = d,
                                      ),
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Date Début Consommation *',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                        ),
                                        child: Text(_dateDebutConsommation != null ? formatDate(_dateDebutConsommation!) : 'Sélectionner'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _pickDate(
                                        context: context,
                                        initialDate: _dateFinConsommation ?? DateTime.now().add(const Duration(days: 30)),
                                        firstDate: _dateDebutConsommation,
                                        onPicked: (d) => _dateFinConsommation = d,
                                      ),
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Date Fin Consommation *',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                        ),
                                        child: Text(_dateFinConsommation != null ? formatDate(_dateFinConsommation!) : 'Sélectionner'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF2563EB)),
                                  SizedBox(width: 8),
                                  Text('Période d\'Amortissement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date Début Amortissement (Automatique)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        helperText: 'Date de création de la charge',
                                      ),
                                      child: Text(formatDate(_dateCreation), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _pickDate(
                                        context: context,
                                        initialDate: _dateFinAmortissement ?? DateTime.now().add(const Duration(days: 365)),
                                        firstDate: _dateCreation,
                                        onPicked: (d) => _dateFinAmortissement = d,
                                      ),
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Date Fin Amortissement *',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                        ),
                                        child: Text(_dateFinAmortissement != null ? formatDate(_dateFinAmortissement!) : 'Sélectionner'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Observation
                      TextFormField(
                        controller: _obsCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observation (Facultatif)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
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
