import 'package:flutter/material.dart';
import '../../../../core/database/database.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/datasources/reglement_datasource.dart';
import '../../../../data/models/client_situation.dart';
import '../../../../data/models/facture_achat.dart';
import '../../../../data/models/facture_vente.dart';
import '../../../../data/models/reglement.dart';
import '../../../../data/models/tiers.dart';
import '../../../../data/repositories/reglement_repository.dart';
import 'reglement_dialog.dart';

Future<void> showFicheClientDialog(
  BuildContext context, {
  required Tiers tiers,
  required List<FactureVente> allClientFactures,
  required List<FactureAchat> allFournisseurFactures,
  required VoidCallback onRefreshParent,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => FicheClientDialog(
      tiers: tiers,
      allClientFactures: allClientFactures,
      allFournisseurFactures: allFournisseurFactures,
      onRefreshParent: onRefreshParent,
    ),
  );
}

class FicheClientDialog extends StatefulWidget {
  final Tiers tiers;
  final List<FactureVente> allClientFactures;
  final List<FactureAchat> allFournisseurFactures;
  final VoidCallback onRefreshParent;

  const FicheClientDialog({
    super.key,
    required this.tiers,
    required this.allClientFactures,
    required this.allFournisseurFactures,
    required this.onRefreshParent,
  });

  @override
  State<FicheClientDialog> createState() => _FicheClientDialogState();
}

class _FicheClientDialogState extends State<FicheClientDialog> with SingleTickerProviderStateMixin {
  late final ReglementRepository _reglementRepo;
  late final TabController _tabController;

  ClientSituation? _situation;
  List<Reglement> _reglements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reglementRepo = ReglementRepository(ReglementDataSource(Database.instance));
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
      final situation = await _reglementRepo.getClientSituation(widget.tiers.id);
      final regs = await _reglementRepo.getReglements(tiersId: widget.tiers.id);

      if (!mounted) return;
      setState(() {
        _situation = situation;
        _reglements = regs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erreur lors du chargement de la fiche client: $e';
      });
    }
  }

  Future<void> _openVersement() async {
    final saved = await showReglementDialog(
      context,
      tiers: widget.tiers,
      typeReglement: widget.tiers.isClient ? 'CLIENT' : 'FOURNISSEUR',
      mode: ReglementDialogMode.versement,
      allClientFactures: widget.allClientFactures,
      allFournisseurFactures: widget.allFournisseurFactures,
    );

    if (saved == true && mounted) {
      widget.onRefreshParent();
      _load();
    }
  }

  Future<void> _openEditReglement(Reglement reg) async {
    final saved = await showReglementDialog(
      context,
      tiers: widget.tiers,
      typeReglement: reg.typeReglement,
      mode: ReglementDialogMode.edit,
      existingReglement: reg,
      allClientFactures: widget.allClientFactures,
      allFournisseurFactures: widget.allFournisseurFactures,
    );

    if (saved == true && mounted) {
      widget.onRefreshParent();
      _load();
    }
  }

  void _showFacturesLiees(Reglement reg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text('Factures Réglées par ${reg.numReglement}'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: reg.facturesLiees.isEmpty
              ? const Text('Aucune facture liée enregistrée pour ce règlement.')
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('N° Facture')),
                      DataColumn(label: Text('Montant Facture')),
                      DataColumn(label: Text('Montant Réglé')),
                    ],
                    rows: reg.facturesLiees.map((rf) {
                      return DataRow(
                        cells: [
                          DataCell(Text(rf.factureType)),
                          DataCell(Text(rf.numFacture ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(rf.montantFacture != null ? formatMoney(rf.montantFacture!) : '—')),
                          DataCell(Text(formatMoney(rf.montantApplique), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981)))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 950, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_rounded, color: Color(0xFF2563EB), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fiche Client / Situation : ${widget.tiers.nom}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tél: ${widget.tiers.telephone ?? '—'}  |  Email: ${widget.tiers.email ?? '—'}  |  RC: ${widget.tiers.rc ?? '—'}  |  NIF: ${widget.tiers.nif ?? '—'}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openVersement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: const Text('Nouveau Versement'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // KPI Cards Solde, Total Ventes, Total Règlements
              if (_situation != null)
                Row(
                  children: [
                    Expanded(
                      child: _kpiCard(
                        title: 'Total Factures Ventes',
                        value: formatMoney(_situation!.totalFactures),
                        color: const Color(0xFF2563EB),
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _kpiCard(
                        title: 'Total Règlements Reçus',
                        value: formatMoney(_situation!.totalReglements),
                        color: const Color(0xFF10B981),
                        icon: Icons.payments_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _kpiCard(
                        title: 'Solde Client (Créance)',
                        value: formatMoney(_situation!.solde),
                        color: _situation!.solde > 0.01 ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // TabBar
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF6B7280),
                indicatorColor: const Color(0xFF2563EB),
                tabs: const [
                  Tab(text: 'Historique des Mouvements (Factures & Règlements)'),
                  Tab(text: 'Liste des Règlements & Factures Liées'),
                ],
              ),

              const SizedBox(height: 12),

              // TabBarView
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildMouvementsTab(),
                              _buildReglementsTab(),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMouvementsTab() {
    if (_situation == null || _situation!.mouvements.isEmpty) {
      return const Center(child: Text('Aucun mouvement enregistré pour ce client.'));
    }

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF374151)),
        dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Référence')),
          DataColumn(label: Text('Débit (Facture)'), numeric: true),
          DataColumn(label: Text('Crédit (Règlement)'), numeric: true),
          DataColumn(label: Text('Solde Progressif'), numeric: true),
          DataColumn(label: Text('Mode')),
          DataColumn(label: Text('Observation')),
        ],
        rows: _situation!.mouvements.map((m) {
          final isFact = m.type == 'FACTURE';
          return DataRow(
            cells: [
              DataCell(Text(formatDate(m.date))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFact ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFact ? 'Facture Vente' : 'Règlement',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isFact ? Colors.blue.shade700 : Colors.green.shade700,
                    ),
                  ),
                ),
              ),
              DataCell(Text(m.reference, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(m.debit > 0 ? formatMoney(m.debit) : '—')),
              DataCell(Text(m.credit > 0 ? formatMoney(m.credit) : '—', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600))),
              DataCell(
                Text(
                  formatMoney(m.soldeProgressif),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: m.soldeProgressif > 0.01 ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                  ),
                ),
              ),
              DataCell(Text(m.modePaiement)),
              DataCell(Text(m.observation ?? '—', overflow: TextOverflow.ellipsis)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReglementsTab() {
    if (_reglements.isEmpty) {
      return const Center(child: Text('Aucun règlement enregistré pour ce tiers.'));
    }

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF374151)),
        dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
        columns: const [
          DataColumn(label: Text('N° Règlement')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Montant'), numeric: true),
          DataColumn(label: Text('Mode')),
          DataColumn(label: Text('Caisse / Banque')),
          DataColumn(label: Text('Factures Liées')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _reglements.map((reg) {
          return DataRow(
            cells: [
              DataCell(Text(reg.numReglement, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)))),
              DataCell(Text(formatDate(reg.dateReglement))),
              DataCell(Text(formatMoney(reg.montant), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981)))),
              DataCell(Text(reg.modePaiement)),
              DataCell(Text(reg.caisseLibelle ?? '—')),
              DataCell(
                TextButton.icon(
                  onPressed: () => _showFacturesLiees(reg),
                  icon: const Icon(Icons.receipt_outlined, size: 16),
                  label: Text('${reg.facturesLiees.length} facture(s)'),
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                  tooltip: 'Modifier le règlement',
                  onPressed: () => _openEditReglement(reg),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

