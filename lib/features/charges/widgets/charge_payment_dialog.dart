import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/models/charge.dart';
import '../../../data/models/compte.dart';
import '../controllers/charges_controller.dart';

class ChargePaymentDialog extends StatefulWidget {
  final Charge charge;
  final ChargesController controller;
  final String userId;
  final VoidCallback onPaymentSuccess;

  const ChargePaymentDialog({
    super.key,
    required this.charge,
    required this.controller,
    required this.userId,
    required this.onPaymentSuccess,
  });

  @override
  State<ChargePaymentDialog> createState() => _ChargePaymentDialogState();
}

class _ChargePaymentDialogState extends State<ChargePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _numChequeController = TextEditingController();
  final _observationController = TextEditingController();

  DateTime _datePaiement = DateTime.now();
  DateTime? _dateCheque;
  String _modePaiement = 'Espèces';
  String? _selectedCaisseId;

  List<Compte> _treasuryAccounts = [];
  bool _loadingAccounts = true;
  bool _submitting = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'fr_DZ',
    symbol: 'DZD',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final remaining = widget.charge.resteARegler;
    _montantController.text = remaining > 0 ? remaining.toStringAsFixed(2) : '0.00';
    _loadAccounts();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _numChequeController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.controller.loadTreasuryPaymentAccounts();
      if (mounted) {
        setState(() {
          _treasuryAccounts = accounts;
          if (accounts.isNotEmpty) {
            _selectedCaisseId = accounts.first.idCompte;
          }
          _loadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAccounts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chargement des comptes trésorerie: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCaisseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un compte de trésorerie (Caisse / Banque).'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final double montant = double.tryParse(_montantController.text.replaceAll(',', '.')) ?? 0;
    if (montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le montant doit être supérieur à zéro.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (montant > widget.charge.resteARegler + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Le montant ne peut pas dépasser le reste à régler (${_currencyFormat.format(widget.charge.resteARegler)}).',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await widget.controller.payCharge(
        charge: widget.charge,
        sourceCaisseId: _selectedCaisseId!,
        montant: montant,
        datePaiement: _datePaiement,
        modePaiement: _modePaiement,
        numCheque: _modePaiement == 'Chèque' ? _numChequeController.text.trim() : null,
        dateCheque: _modePaiement == 'Chèque' ? _dateCheque : null,
        observation: _observationController.text.trim().isEmpty ? null : _observationController.text.trim(),
        userId: widget.userId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPaymentSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Règlement de ${_currencyFormat.format(montant)} enregistré avec succès.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du règlement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _loadingAccounts
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payment_rounded, color: AppColors.success),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Règlement de Charge',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${widget.charge.refCharge} — ${widget.charge.designation}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Charge info cards
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoStat(
                              'Montant Total',
                              _currencyFormat.format(widget.charge.montantCharge),
                              AppColors.textPrimary,
                            ),
                            _buildInfoStat(
                              'Déjà Réglé',
                              _currencyFormat.format(widget.charge.montantRegle),
                              AppColors.success,
                            ),
                            _buildInfoStat(
                              'Reste à Régler',
                              _currencyFormat.format(widget.charge.resteARegler),
                              AppColors.warning,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Fields
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _montantController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Montant à régler *',
                                prefixIcon: Icon(Icons.attach_money_rounded),
                                suffixText: 'DZD',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Montant requis';
                                }
                                final val = double.tryParse(value.replaceAll(',', '.'));
                                if (val == null || val <= 0) {
                                  return 'Montant invalide';
                                }
                                if (val > widget.charge.resteARegler + 0.001) {
                                  return 'Dépasse le reste';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _datePaiement,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _datePaiement = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date règlement *',
                                  prefixIcon: Icon(Icons.calendar_today_rounded),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(_dateFormat.format(_datePaiement)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Treasury Account Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCaisseId,
                        decoration: const InputDecoration(
                          labelText: 'Compte Trésorerie Source *',
                          prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: _treasuryAccounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.idCompte,
                            child: Text(
                              '${acc.code} - ${acc.nomCompte} (${acc.typeCompte ?? "Trésorerie"})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCaisseId = val);
                        },
                        validator: (val) => val == null ? 'Sélectionnez un compte' : null,
                      ),
                      const SizedBox(height: 14),

                      // Payment Mode
                      DropdownButtonFormField<String>(
                        value: _modePaiement,
                        decoration: const InputDecoration(
                          labelText: 'Mode de Paiement *',
                          prefixIcon: Icon(Icons.credit_card_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Espèces', child: Text('Espèces')),
                          DropdownMenuItem(value: 'Chèque', child: Text('Chèque')),
                          DropdownMenuItem(value: 'Virement', child: Text('Virement bancaire')),
                          DropdownMenuItem(value: 'Carte bancaire', child: Text('Carte bancaire')),
                          DropdownMenuItem(value: 'Prélèvement', child: Text('Prélèvement')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _modePaiement = val);
                        },
                      ),

                      if (_modePaiement == 'Chèque') ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _numChequeController,
                                decoration: const InputDecoration(
                                  labelText: 'N° Chèque',
                                  prefixIcon: Icon(Icons.tag_rounded),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _dateCheque ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => _dateCheque = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date d\'échéance Chèque',
                                    prefixIcon: Icon(Icons.event_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    _dateCheque != null
                                        ? _dateFormat.format(_dateCheque!)
                                        : 'Non définie',
                                    style: TextStyle(
                                      color: _dateCheque != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _observationController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observation / Note',
                          prefixIcon: Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline_rounded),
                            label: Text(_submitting ? 'Validation...' : 'Valider le Règlement'),
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

  Widget _buildInfoStat(String title, String value, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
