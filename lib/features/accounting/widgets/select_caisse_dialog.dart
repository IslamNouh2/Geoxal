import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/security/session.dart';
import '../../../../data/models/compte.dart';

class CaisseSessionSelection {
  final Compte caisse;
  final DateTime fromDate;
  final DateTime toDate;

  const CaisseSessionSelection({
    required this.caisse,
    required this.fromDate,
    required this.toDate,
  });
}

Future<CaisseSessionSelection?> showSelectCaisseDialog(
  BuildContext context, {
  required List<Compte> caisseAccounts,
  Compte? initialCaisse,
  DateTime? initialFrom,
  DateTime? initialTo,
}) {
  return showDialog<CaisseSessionSelection?>(
    context: context,
    barrierDismissible: initialCaisse != null, // Can dismiss only if already had one
    builder: (context) => SelectCaisseDialog(
      caisseAccounts: caisseAccounts,
      initialCaisse: initialCaisse,
      initialFrom: initialFrom,
      initialTo: initialTo,
    ),
  );
}

class SelectCaisseDialog extends StatefulWidget {
  const SelectCaisseDialog({
    super.key,
    required this.caisseAccounts,
    this.initialCaisse,
    this.initialFrom,
    this.initialTo,
  });

  final List<Compte> caisseAccounts;
  final Compte? initialCaisse;
  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<SelectCaisseDialog> createState() => _SelectCaisseDialogState();
}

class _SelectCaisseDialogState extends State<SelectCaisseDialog> {
  late Compte? _selectedCaisse;
  late DateTime _fromDate;
  late DateTime _toDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canViewOld = Session.user?.hasViewOldSoldePermission ?? true;

    _selectedCaisse = widget.initialCaisse ?? (widget.caisseAccounts.isNotEmpty ? widget.caisseAccounts.first : null);
    if (!canViewOld) {
      _fromDate = today;
      _toDate = today;
    } else {
      _fromDate = widget.initialFrom ?? DateTime(now.year, now.month, 1);
      _toDate = widget.initialTo ?? today;
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_fromDate.isAfter(_toDate)) {
          _toDate = _fromDate;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        if (_toDate.isBefore(_fromDate)) {
          _fromDate = _toDate;
        }
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _confirm() {
    if (_selectedCaisse == null) {
      setState(() => _error = 'Veuillez sélectionner une caisse ou une banque.');
      return;
    }

    Navigator.of(context).pop(
      CaisseSessionSelection(
        caisse: _selectedCaisse!,
        fromDate: _fromDate,
        toDate: _toDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canViewOld = Session.user?.hasViewOldSoldePermission ?? true;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF2563EB),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sélection Caisse / Banque',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepSpaceBlue,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Choisissez la caisse ou banque à ouvrir ainsi que la période',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                ),
                const SizedBox(height: 14),
              ],

              // Section Caisse / Banque
              const Text(
                'Caisse ou Banque à consulter *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 10),

              if (widget.caisseAccounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Aucun compte caisse ou banque disponible.'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.caisseAccounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final acc = widget.caisseAccounts[index];
                      final isSelected = _selectedCaisse?.id == acc.id;
                      final isBanque = acc.typeCompte == CompteType.banque || acc.libelle.toLowerCase().contains('banque');

                      return InkWell(
                        onTap: () => setState(() {
                          _selectedCaisse = acc;
                          _error = null;
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isBanque ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5))
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? (isBanque ? const Color(0xFF2563EB) : const Color(0xFF10B981))
                                  : const Color(0xFFE5E7EB),
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isBanque ? Icons.account_balance_rounded : Icons.payments_rounded,
                                size: 22,
                                color: isBanque ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.displayName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: const Color(0xFF1F2937),
                                      ),
                                    ),
                                    Text(
                                      isBanque ? 'Compte Bancaire' : 'Caisse d\'espèces',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: isBanque ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // Période (Date début et Date fin)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Période de consultation *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                  if (!canViewOld)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 12, color: Color(0xFF92400E)),
                          SizedBox(width: 4),
                          Text(
                            'Date du jour uniquement',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: canViewOld ? _pickFromDate : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: canViewOld ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              canViewOld ? Icons.calendar_today_rounded : Icons.lock_clock,
                              size: 16,
                              color: canViewOld ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date début', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                                Text(
                                  _formatDate(_fromDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: canViewOld ? const Color(0xFF1F2937) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: canViewOld ? _pickToDate : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: canViewOld ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              canViewOld ? Icons.event_available_rounded : Icons.lock_clock,
                              size: 16,
                              color: canViewOld ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date fin', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                                Text(
                                  _formatDate(_toDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: canViewOld ? const Color(0xFF1F2937) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Accéder aux Mouvements',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
