import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/datasources/achat_datasource.dart';
import '../../../../data/datasources/tiers_datasource.dart';
import '../../../../data/datasources/vente_datasource.dart';
import '../../../../data/models/facture_achat.dart';
import '../../../../data/models/facture_vente.dart';
import '../../../../data/models/tiers.dart';
import '../../../../data/repositories/achat_repository.dart';
import '../../../../data/repositories/tiers_repository.dart';
import '../../../../data/repositories/vente_repository.dart';
import '../../sales/widgets/fiche_client_dialog.dart';
import '../../sales/widgets/reglement_dialog.dart';
import '../widgets/new_purchase_dialog.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  late final AchatRepository _achatRepository;
  late final VenteRepository _venteRepository;
  late final TiersRepository _tiersRepository;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  List<FactureAchat> _invoices = [];
  List<FactureVente> _sales = [];
  List<Tiers> _fournisseurs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final db = Database.instance;
    _achatRepository = AchatRepository(AchatDataSource(db));
    _venteRepository = VenteRepository(VenteDataSource(db));
    _tiersRepository = TiersRepository(TiersDataSource(db));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final from = tryParseFilterDate(_fromController.text);
      final to = tryParseFilterDate(_toController.text);
      final query = _searchController.text.trim();

      final list = await _achatRepository.getFacturesAchat(
        from: from,
        to: to,
        searchQuery: query.isEmpty ? null : query,
      );

      final sales = await _venteRepository.getFacturesVente();
      final suppliers = await _tiersRepository.getFournisseurs();

      if (!mounted) return;
      setState(() {
        _invoices = list;
        _sales = sales;
        _fournisseurs = suppliers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les factures d\'achat: $e';
      });
    }
  }

  Future<void> _newInvoice() async {
    final saved = await showNewPurchaseDialog(
      context,
      achatRepository: _achatRepository,
      tiersRepository: _tiersRepository,
    );

    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Facture d\'achat créée avec succès!'),
          backgroundColor: Color(0xFF2563EB),
        ),
      );
      _load();
    }
  }

  Future<void> _openFicheFournisseur(String tiersId) async {
    final tiers = _fournisseurs.cast<Tiers?>().firstWhere(
      (t) => t?.id == tiersId,
      orElse: () => null,
    );
    if (tiers == null) return;

    await showFicheClientDialog(
      context,
      tiers: tiers,
      allClientFactures: _sales,
      allFournisseurFactures: _invoices,
      onRefreshParent: _load,
    );
  }

  Future<void> _openVersementFournisseur(String tiersId) async {
    final tiers = _fournisseurs.cast<Tiers?>().firstWhere(
      (t) => t?.id == tiersId,
      orElse: () => null,
    );
    if (tiers == null) return;

    final saved = await showReglementDialog(
      context,
      tiers: tiers,
      typeReglement: 'FOURNISSEUR',
      mode: ReglementDialogMode.versement,
      allClientFactures: _sales,
      allFournisseurFactures: _invoices,
    );

    if (saved == true && mounted) {
      _load();
    }
  }

  Future<void> _openReglerFacture(FactureAchat invoice) async {
    final tiers = _fournisseurs.cast<Tiers?>().firstWhere(
      (t) => t?.id == invoice.tiersId,
      orElse: () => null,
    );
    if (tiers == null) return;

    final saved = await showReglementDialog(
      context,
      tiers: tiers,
      typeReglement: 'FOURNISSEUR',
      mode: ReglementDialogMode.regle,
      specificFactureAchat: invoice,
      allClientFactures: _sales,
      allFournisseurFactures: _invoices,
    );

    if (saved == true && mounted) {
      _load();
    }
  }

  double get _totalAchats => _invoices.fold(0.0, (sum, f) => sum + f.montant);

  double get _totalRegle => _invoices.fold(0.0, (sum, f) => sum + f.montantRegle);

  double get _totalDettes => _invoices.fold(0.0, (sum, f) => sum + f.resteAPayer);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildToolbar(),
          if (_error != null) _buildErrorBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildStatCards(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildTableCard()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Search box
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Rechercher (N°, fournisseur)...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date from
          SizedBox(
            width: 130,
            child: TextField(
              controller: _fromController,
              onEditingComplete: _load,
              decoration: InputDecoration(
                hintText: 'Du (yyyy-MM-dd)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Date to
          SizedBox(
            width: 130,
            child: TextField(
              controller: _toController,
              onEditingComplete: _load,
              decoration: InputDecoration(
                hintText: 'Au (yyyy-MM-dd)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Filtrer / Actualiser',
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.coolSteel,
              onPressed: _loading ? null : _load,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _newInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Nouvel Achat / Charge',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brickEmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brickEmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.brickEmber),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
          TextButton(onPressed: _load, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            title: 'Volume Total Achats & Charges',
            value: formatMoney(_totalAchats),
            icon: Icons.trending_down_rounded,
            iconColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(
            title: 'Total Règlements Décaissés',
            value: formatMoney(_totalRegle),
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(
            title: 'Dettes Fournisseurs Restantes',
            value: formatMoney(_totalDettes),
            icon: Icons.pending_actions_rounded,
            iconColor: const Color(0xFFE11D48),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
                      headingTextStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                      dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('N° Interne')),
                        DataColumn(label: Text('N° Fournisseur')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Fournisseur')),
                        DataColumn(label: Text('Département')),
                        DataColumn(label: Text('Compte / Charge')),
                        DataColumn(label: Text('Mode')),
                        DataColumn(label: Text('Montant'), numeric: true),
                        DataColumn(label: Text('Réglé'), numeric: true),
                        DataColumn(label: Text('Reste'), numeric: true),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _invoices.map((f) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: f.isCharge ? Colors.purple.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  f.isCharge ? 'Charge' : 'Achat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: f.isCharge ? Colors.purple.shade700 : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.receipt_outlined, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Text(f.numFacture, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            // N° Facture Fournisseur (référence externe)
                            DataCell(
                              f.numFactureFournisseur != null && f.numFactureFournisseur!.isNotEmpty
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF6B7280)),
                                        const SizedBox(width: 4),
                                        Text(
                                          f.numFactureFournisseur!,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                                        ),
                                      ],
                                    )
                                  : const Text('—', style: TextStyle(color: Color(0xFF9CA3AF))),
                            ),
                            DataCell(Text(formatDate(f.dateFacture))),
                            DataCell(
                              InkWell(
                                onTap: () => _openFicheFournisseur(f.tiersId),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(f.fournisseurNom ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.open_in_new, size: 12, color: Color(0xFF2563EB)),
                                      ],
                                    ),
                                    if (f.fournisseurTelephone != null)
                                      Text(f.fournisseurTelephone!, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(f.departementNom ?? '—')),
                            DataCell(Text(f.compteLibelle ?? '—', overflow: TextOverflow.ellipsis)),
                            DataCell(Text(f.modePaiement ?? '—')),
                            DataCell(
                              Text(
                                formatMoney(f.montant),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                              ),
                            ),
                            DataCell(
                              Text(
                                formatMoney(f.montantRegle),
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: f.isSoldee ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  f.isSoldee ? 'Soldée' : formatMoney(f.resteAPayer),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: f.isSoldee ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Bouton Fiche Fournisseur
                                  IconButton(
                                    icon: const Icon(Icons.assignment_ind_outlined, size: 18, color: Color(0xFF2563EB)),
                                    tooltip: 'Fiche Fournisseur & Situation',
                                    onPressed: () => _openFicheFournisseur(f.tiersId),
                                  ),
                                  // Bouton Versement
                                  IconButton(
                                    icon: const Icon(Icons.add_card_rounded, size: 18, color: Color(0xFF10B981)),
                                    tooltip: 'Versement Fournisseur',
                                    onPressed: () => _openVersementFournisseur(f.tiersId),
                                  ),
                                  // Bouton Régler
                                  if (!f.isSoldee)
                                    ElevatedButton(
                                      onPressed: () => _openReglerFacture(f),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Régler', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_rounded, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'Aucune facture d\'achat ou charge',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Créez votre première facture d\'achat ou enregistrez une charge.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _newInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvel Achat / Charge'),
            ),
          ],
        ),
      ),
    );
  }
}
