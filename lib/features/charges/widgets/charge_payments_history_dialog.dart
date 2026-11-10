import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/models/charge.dart';
import '../controllers/charges_controller.dart';

class ChargePaymentsHistoryDialog extends StatefulWidget {
  final Charge charge;
  final ChargesController controller;

  const ChargePaymentsHistoryDialog({
    super.key,
    required this.charge,
    required this.controller,
  });

  @override
  State<ChargePaymentsHistoryDialog> createState() =>
      _ChargePaymentsHistoryDialogState();
}

class _ChargePaymentsHistoryDialogState
    extends State<ChargePaymentsHistoryDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _details = [];
  String? _error;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'fr_DZ',
    symbol: 'DZD',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final list =
          await widget.controller.loadChargePaymentDetails(widget.charge.idCharge);
      if (mounted) {
        setState(() {
          _details = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historique des Règlements',
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
              const SizedBox(height: 10),

              // Summary Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Total Charge',
                      _currencyFormat.format(widget.charge.montantCharge),
                      AppColors.textPrimary,
                    ),
                    _buildSummaryItem(
                      'Total Réglé',
                      _currencyFormat.format(widget.charge.montantRegle),
                      AppColors.success,
                    ),
                    _buildSummaryItem(
                      'Reste à Régler',
                      _currencyFormat.format(widget.charge.resteARegler),
                      widget.charge.resteARegler > 0.001
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              'Erreur: $_error',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          )
                        : _details.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Aucun règlement enregistré pour cette charge.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    AppColors.surface,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Date & Heure')),
                                    DataColumn(label: Text('N° Mouvement')),
                                    DataColumn(label: Text('Compte Caisse')),
                                    DataColumn(label: Text('Mode')),
                                    DataColumn(
                                      label: Text('Montant Réglé'),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: _details.map((item) {
                                    final dateCreat = item['DATE_CREAT'];
                                    String dateStr = '-';
                                    if (dateCreat != null) {
                                      if (dateCreat is DateTime) {
                                        dateStr = _dateFormat.format(dateCreat);
                                      } else {
                                        dateStr = dateCreat.toString();
                                      }
                                    }

                                    final numMvt =
                                        item['NUMERO_MOUVEMENT']?.toString() ??
                                            '-';
                                    final caisseNom =
                                        item['NOM_COMPTE']?.toString() ??
                                            item['ID_MVT_TRESOR']?.toString() ??
                                            '-';
                                    final mode =
                                        item['TYPE_MOUVEMENT']?.toString() ??
                                            'Espèces';
                                    final montant =
                                        (item['TRANCHE_MONTANT'] is num)
                                            ? (item['TRANCHE_MONTANT'] as num)
                                                .toDouble()
                                            : 0.0;

                                    return DataRow(cells: [
                                      DataCell(Text(dateStr)),
                                      DataCell(Text(numMvt)),
                                      DataCell(Text(caisseNom)),
                                      DataCell(Text(mode)),
                                      DataCell(
                                        Text(
                                          _currencyFormat.format(montant),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
