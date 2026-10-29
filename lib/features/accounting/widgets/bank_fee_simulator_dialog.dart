import 'package:flutter/material.dart';
import '../../../../data/models/bank_rule.dart';
import '../../../../data/models/cheque_remise.dart';
import '../../../../data/models/compte.dart';
import '../../../../core/services/bank_fee_calculator.dart';

class BankFeeSimulatorDialog extends StatefulWidget {
  final List<Compte> bankAccounts;
  final List<TransactionTypeCatalog> transactionTypes;
  final List<BankRule> rules;

  const BankFeeSimulatorDialog({
    super.key,
    required this.bankAccounts,
    required this.transactionTypes,
    required this.rules,
  });

  @override
  State<BankFeeSimulatorDialog> createState() => _BankFeeSimulatorDialogState();
}

class _BankFeeSimulatorDialogState extends State<BankFeeSimulatorDialog> {
  String? _selectedBankCompteId;
  String _selectedTxCode = 'VERSEMENT_CHEQUE';
  final TextEditingController _amountController = TextEditingController(text: '325230.61');
  final TextEditingController _chequesCountController = TextEditingController(text: '1');
  List<BankTransactionFee> _simulatedFees = [];

  @override
  void initState() {
    super.initState();
    if (widget.bankAccounts.isNotEmpty) {
      _selectedBankCompteId = widget.bankAccounts.first.id;
    }
    _runSimulation();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _chequesCountController.dispose();
    super.dispose();
  }

  void _runSimulation() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final count = int.tryParse(_chequesCountController.text.trim()) ?? 1;

    final txMap = {for (final tx in widget.transactionTypes) tx.code: tx.id};

    final fees = BankFeeCalculator.computeFees(
      input: FeeCalculationInput(
        bankCompteId: _selectedBankCompteId,
        transactionTypeCode: _selectedTxCode,
        transactionAmount: amount,
        chequesCount: count,
      ),
      allRules: widget.rules,
      transactionTypeCodeToId: txMap,
    );

    setState(() {
      _simulatedFees = fees;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalFees = _simulatedFees.fold(0.0, (sum, f) => sum + f.computedAmount);
    final netAmount = (double.tryParse(_amountController.text.trim()) ?? 0.0) - totalFees;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calculate_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simulateur de Règles & Frais Bancaires',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Testez les barèmes et la décomposition de TVA en temps réel',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const Divider(height: 28),

            // Formulaire paramètres de simulation
            Row(
              children: [
                // Compte Banque
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compte Bancaire (COMPTES)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: widget.bankAccounts.any((b) => b.id == _selectedBankCompteId) ? _selectedBankCompteId : null,
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Toutes banques (Règles générales)')),
                          ...widget.bankAccounts.map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text('${b.code} - ${b.libelle}'),
                          )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedBankCompteId = val);
                          _runSimulation();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Type d'opération
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Opération bancaire', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedTxCode,
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: widget.transactionTypes.map((t) => DropdownMenuItem(
                          value: t.code,
                          child: Text(t.label),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedTxCode = val);
                            _runSimulation();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // Montant brut
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Montant de la transaction (DZD)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration(suffix: 'DZD'),
                        onChanged: (_) => _runSimulation(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Nombre de chèques (si remise)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nombre de chèques', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _chequesCountController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(),
                        onChanged: (_) => _runSimulation(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Résultats calculés
            const Text('Lignes de frais et taxes déduites :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFF8FAFC),
              ),
              child: _simulatedFees.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Aucun frais ni taxe applicable pour cette configuration.', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    )
                  : Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('Règle / Intitulé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                              Expanded(flex: 2, child: Text('Base de calcul', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                              Expanded(flex: 2, child: Text('Taux / Barème', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                              Expanded(flex: 2, child: Text('Montant prélevé', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                            ],
                          ),
                        ),
                        // Lines
                        ..._simulatedFees.map((fee) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(fee.ruleName ?? 'Frais bancaire', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${fee.baseAmount.toStringAsFixed(2)} DZD', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${fee.rateOrAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '- ${fee.computedAmount.toStringAsFixed(2)} DZD',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Récapitulatif total
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total des frais & taxes :', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 13)),
                      Text(
                        '${totalFees.toStringAsFixed(2)} DZD',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Montant net crédité :', style: TextStyle(color: Color(0xFF065F46), fontSize: 13)),
                      Text(
                        '${netAmount.toStringAsFixed(2)} DZD',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? suffix}) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixText: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
