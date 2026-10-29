import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/security/session.dart';
import '../../../../core/services/bank_fee_calculator.dart';
import '../../../../core/utils/uuid.dart';
import '../../../../data/datasources/banking_datasource.dart';
import '../../../../data/models/bank_rule.dart';
import '../../../../data/models/cheque_remise.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/repositories/banking_repository.dart';

class RemisesChequesPage extends StatefulWidget {
  const RemisesChequesPage({super.key});

  @override
  State<RemisesChequesPage> createState() => _RemisesChequesPageState();
}

class _RemisesChequesPageState extends State<RemisesChequesPage> with SingleTickerProviderStateMixin {
  late final BankingRepository _repository;
  late final TabController _tabController;

  List<RemiseCheque> _remises = [];
  List<Cheque> _portfolioCheques = [];
  List<Compte> _bankAccounts = [];
  List<BankRule> _bankRules = [];
  List<TransactionTypeCatalog> _txTypes = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = BankingRepository(BankingDataSource(Database.instance));
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final remises = await _repository.getRemises();
      final portfolio = await _repository.getChequesInPortfolio();
      final bankAccounts = await _repository.getBankAccounts();
      final rules = await _repository.getBankRules();
      final txTypes = await _repository.getTransactionTypes();

      if (!mounted) return;
      setState(() {
        _remises = remises;
        _portfolioCheques = portfolio;
        _bankAccounts = bankAccounts;
        _bankRules = rules;
        _txTypes = txTypes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erreur de chargement: $e';
      });
    }
  }

  Future<void> _openCreateRemiseDialog() async {
    if (_bankAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun compte bancaire configuré dans le plan comptable.')),
      );
      return;
    }

    final bordereauCtrl = TextEditingController(text: 'BR-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');
    String selectedBankCompteId = _bankAccounts.first.id;
    final Set<String> selectedChequeIds = {};
    List<BankTransactionFee> computedFees = [];

    final txMap = {for (final tx in _txTypes) tx.code: tx.id};

    void recomputeFees(StateSetter setModalState) {
      final selectedCheques = _portfolioCheques.where((c) => selectedChequeIds.contains(c.id)).toList();
      final totalAmount = selectedCheques.fold(0.0, (sum, c) => sum + c.montant);

      final fees = BankFeeCalculator.computeFees(
        input: FeeCalculationInput(
          bankCompteId: selectedBankCompteId,
          transactionTypeCode: 'VERSEMENT_CHEQUE',
          transactionAmount: totalAmount,
          chequesCount: selectedCheques.length,
        ),
        allRules: _bankRules,
        transactionTypeCodeToId: txMap,
      );

      setModalState(() {
        computedFees = fees;
      });
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedCheques = _portfolioCheques.where((c) => selectedChequeIds.contains(c.id)).toList();
          final totalAmount = selectedCheques.fold(0.0, (sum, c) => sum + c.montant);
          final totalFees = computedFees.fold(0.0, (sum, f) => sum + f.finalAmount);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 860,
              height: 640,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Créer un Bordereau de Remise de Chèques', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Divider(height: 20),

                  // Header : Bordereau & Banque
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bordereauCtrl,
                          decoration: const InputDecoration(labelText: 'N° Bordereau *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedBankCompteId,
                          decoration: const InputDecoration(labelText: 'Compte Banque destinataire *', isDense: true, border: OutlineInputBorder()),
                          items: _bankAccounts.map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text('${b.code} - ${b.libelle}'),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedBankCompteId = val);
                              recomputeFees(setModalState);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Chèques en portefeuille disponibles :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),

                  // Liste des chèques en portefeuille
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _portfolioCheques.isEmpty
                          ? const Center(child: Text('Aucun chèque en portefeuille pour le moment.', style: TextStyle(color: Color(0xFF64748B))))
                          : ListView.separated(
                              itemCount: _portfolioCheques.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final chq = _portfolioCheques[index];
                                final isSelected = selectedChequeIds.contains(chq.id);

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedChequeIds.add(chq.id);
                                      } else {
                                        selectedChequeIds.remove(chq.id);
                                      }
                                    });
                                    recomputeFees(setModalState);
                                  },
                                  title: Row(
                                    children: [
                                      Text('Chèque N° ${chq.chequeNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      Text('(${chq.draweeBankName})', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                  subtitle: Text('Client: ${chq.clientNom ?? "N/A"} - Facture: ${chq.numFacture ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                                  secondary: Text(
                                    '${chq.montant.toStringAsFixed(2)} DZD',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 14),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Aperçu des frais calculés
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sélection : ${selectedCheques.length} chèque(s) | Total : ${totalAmount.toStringAsFixed(2)} DZD',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              'Frais estimés : - ${totalFees.toStringAsFixed(2)} DZD',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                        if (computedFees.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...computedFees.map((f) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• ${f.ruleName ?? "Frais bancaire"}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                Text('- ${f.computedAmount.toStringAsFixed(2)} DZD', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: selectedCheques.isEmpty
                            ? null
                            : () async {
                                final remise = RemiseCheque(
                                  id: Uuid.v4(),
                                  bordereauNumber: bordereauCtrl.text.trim(),
                                  dateRemise: DateTime.now(),
                                  bankCompteId: selectedBankCompteId,
                                  totalAmount: totalAmount,
                                  chequesCount: selectedCheques.length,
                                  createdBy: Session.user?.id ?? '123e4567-e89b-12d3-a456-426614174000',
                                );

                                for (final f in computedFees) {
                                  // Associer l'ID de la remise aux frais
                                }

                                await _repository.createRemiseDraft(
                                  remise: remise,
                                  chequeIds: selectedChequeIds.toList(),
                                  fees: computedFees,
                                );

                                if (mounted) Navigator.of(context).pop(true);
                              },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                        child: const Text('Enregistrer le bordereau (Brouillon)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bordereau créé en brouillon.'), backgroundColor: Color(0xFF10B981)),
      );
      _load();
    }
  }

  Future<void> _validateRemise(RemiseCheque remise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider la remise en banque ?'),
        content: Text('Le bordereau N° ${remise.bordereauNumber} sera verrouillé. Le versement sera comptabilisé en trésorerie et les chèques passeront au statut "Remis en banque".'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Valider & Comptabiliser'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final fees = await _repository.getFeesByRemiseId(remise.id);
      await _repository.validateRemise(
        remiseId: remise.id,
        validatedByUserId: Session.user?.id ?? '123e4567-e89b-12d3-a456-426614174000',
        bankCompteId: remise.bankCompteId,
        totalAmount: remise.totalAmount,
        bordereauNumber: remise.bordereauNumber,
        fees: fees,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remise validée et comptabilisée.'), backgroundColor: Color(0xFF10B981)),
        );
        _load();
      }
    }
  }

  Future<void> _cancelRemise(RemiseCheque remise) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la remise de chèques'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cette action extourne le versement et replace les chèques en portefeuille.'),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Motif de l\'annulation *', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Fermer')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.isNotEmpty) {
      await _repository.cancelRemise(
        remiseId: remise.id,
        cancelledByUserId: Session.user?.id ?? '123e4567-e89b-12d3-a456-426614174000',
        reason: reasonCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remise annulée avec succès.')),
        );
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remise de Chèques & Portefeuille', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    SizedBox(height: 4),
                    Text('Gérez vos bordereaux de remise, les frais déduits et le cycle de vie des chèques', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openCreateRemiseDialog,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Nouveau Bordereau', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              tabs: [
                Tab(text: 'Bordereaux de Remise (${_remises.length})'),
                Tab(text: 'Chèques en Portefeuille (${_portfolioCheques.length})'),
              ],
            ),
            const SizedBox(height: 16),

            // Contenu
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildRemisesList(),
                            _buildPortfolioList(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemisesList() {
    if (_remises.isEmpty) {
      return const Center(child: Text('Aucun bordereau de remise créé.', style: TextStyle(color: Color(0xFF64748B))));
    }

    return ListView.separated(
      itemCount: _remises.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = _remises[index];
        final isDraft = r.status == RemiseStatus.brouillon;
        final isValidated = r.status == RemiseStatus.validee;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isValidated ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isValidated ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: isValidated ? const Color(0xFF166534) : const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Bordereau : ${r.bordereauNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isValidated ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.status.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isValidated ? const Color(0xFF166534) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Banque: ${r.bankCompteLabel ?? "N/A"} • ${r.chequesCount} chèque(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Text(
                  '${r.totalAmount.toStringAsFixed(2)} DZD',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                ),
                const SizedBox(width: 20),
                if (isDraft)
                  ElevatedButton(
                    onPressed: () => _validateRemise(r),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    child: const Text('Valider'),
                  ),
                if (isValidated)
                  OutlinedButton(
                    onPressed: () => _cancelRemise(r),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
                    child: const Text('Annuler'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortfolioList() {
    if (_portfolioCheques.isEmpty) {
      return const Center(child: Text('Le portefeuille de chèques est vide.', style: TextStyle(color: Color(0xFF64748B))));
    }

    return ListView.separated(
      itemCount: _portfolioCheques.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = _portfolioCheques[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEFF6FF),
              child: Icon(Icons.receipt_rounded, color: Color(0xFF2563EB)),
            ),
            title: Text('Chèque N° ${c.chequeNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Tiré sur: ${c.draweeBankName} • Client: ${c.clientNom ?? "Client"} • Facture: ${c.numFacture ?? "N/A"}'),
            trailing: Text(
              '${c.montant.toStringAsFixed(2)} DZD',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF047857)),
            ),
          ),
        );
      },
    );
  }
}
