import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/datasources/achat_datasource.dart';
import '../../../../data/datasources/tiers_datasource.dart';
import '../../../../data/models/facture_achat.dart';
import '../../../../data/repositories/achat_repository.dart';
import '../../../../data/repositories/tiers_repository.dart';
import '../widgets/new_purchase_dialog.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  late final AchatRepository _achatRepository;
  late final TiersRepository _tiersRepository;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  List<FactureAchat> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final db = Database.instance;
    _achatRepository = AchatRepository(AchatDataSource(db));
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

      if (!mounted) return;
      setState(() {
        _invoices = list;
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
          content: Text('Facture d\'achat enregistrée avec succès!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _load();
    }
  }

  double get _totalAchats => _invoices.fold(0.0, (sum, f) => sum + f.montant);

  double get _depenseMoyenne => _invoices.isEmpty ? 0.0 : _totalAchats / _invoices.length;

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
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Nouvel Achat',
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
        color: AppColors.brickEmber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brickEmber.withOpacity(0.3)),
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
            title: 'Total Dépenses Achats',
            value: formatMoney(_totalAchats),
            icon: Icons.shopping_cart_rounded,
            iconColor: const Color(0xFFEA580C),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(
            title: 'Factures d\'Achat',
            value: '${_invoices.length}',
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(
            title: 'Dépense Moyenne',
            value: formatMoney(_depenseMoyenne),
            icon: Icons.pie_chart_outline_rounded,
            iconColor: const Color(0xFF0D9488),
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
            color: Colors.black.withOpacity(0.02),
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
              color: iconColor.withOpacity(0.12),
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
            color: Colors.black.withOpacity(0.02),
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
                      columnSpacing: 28,
                      columns: const [
                        DataColumn(label: Text('N° Facture')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Fournisseur')),
                        DataColumn(label: Text('Désignation / Motif')),
                        DataColumn(label: Text('Montant (TTC)'), numeric: true),
                      ],
                      rows: _invoices.map((f) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.receipt_outlined, size: 16, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 6),
                                  Text(f.numFacture, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DataCell(Text(formatDate(f.dateFacture))),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.fournisseurNom ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  if (f.fournisseurTelephone != null)
                                    Text(f.fournisseurTelephone!, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(f.designation ?? '—', overflow: TextOverflow.ellipsis),
                            ),
                            DataCell(
                              Text(
                                formatMoney(f.montant),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEA580C),
                                ),
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
            Icon(Icons.shopping_cart_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'Aucune facture d\'achat',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Créez votre première facture d\'achat auprès d\'un fournisseur.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _newInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvelle Facture Achat'),
            ),
          ],
        ),
      ),
    );
  }
}
