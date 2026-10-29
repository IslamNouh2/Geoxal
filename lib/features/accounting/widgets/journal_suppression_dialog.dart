import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/compte.dart';
import '../../../data/models/journal_suppression_entry.dart';
import '../controllers/accounting_controller.dart';

class JournalSuppressionDialog extends StatefulWidget {
  final AccountingController controller;
  final List<Compte> caisses;
  final String? initialCaisseId;

  const JournalSuppressionDialog({
    super.key,
    required this.controller,
    this.caisses = const [],
    this.initialCaisseId,
  });

  static Future<void> show(
    BuildContext context, {
    required AccountingController controller,
    List<Compte> caisses = const [],
    String? initialCaisseId,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => JournalSuppressionDialog(
        controller: controller,
        caisses: caisses,
        initialCaisseId: initialCaisseId,
      ),
    );
  }

  @override
  State<JournalSuppressionDialog> createState() => _JournalSuppressionDialogState();
}

class _JournalSuppressionDialogState extends State<JournalSuppressionDialog> {
  bool _loading = true;
  String? _error;
  List<JournalSuppressionEntry> _entries = [];
  String _searchQuery = '';

  // Filter states
  String? _selectedCaisseId;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _selectedCaisseId = widget.initialCaisseId;
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.controller.loadJournalSuppression(
        caisseId: _selectedCaisseId,
        from: _fromDate,
        to: _toDate,
      );
      if (mounted) {
        setState(() {
          _entries = data;
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

  List<JournalSuppressionEntry> get _filteredEntries {
    if (_searchQuery.trim().isEmpty) return _entries;
    final q = _searchQuery.toLowerCase().trim();
    return _entries.where((e) {
      return e.movDesignation.toLowerCase().contains(q) ||
          e.sourceDisplayName.toLowerCase().contains(q) ||
          e.destDisplayName.toLowerCase().contains(q) ||
          (e.userSuppression?.toLowerCase().contains(q) ?? false) ||
          e.formattedDateSuppression.contains(q) ||
          e.formattedMovDate.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1100,
          maxHeight: 740,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(),

            // Filter Bar (Caisse dropdown + Date range picker)
            _buildFilterBar(),

            // Search Bar & Stats Counter
            _buildSearchAndStatsBar(),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorView()
                      : _filteredEntries.isEmpty
                          ? _buildEmptyView()
                          : _buildTableView(),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_delete_outlined,
              size: 20,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Journal des Suppressions (Trésorerie)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Traçabilité complète des suppressions avec filtres par caisse et période',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF6B7280)),
            onPressed: _loading ? null : _loadEntries,
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final hasDateFilter = _fromDate != null || _toDate != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          // Filter by Caisse
          const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF4B5563)),
          const SizedBox(width: 8),
          const Text('Caisse / Banque :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(width: 10),
          SizedBox(
            width: 250,
            height: 38,
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedCaisseId,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Toutes les caisses & banques', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ...widget.caisses.map((c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text('${c.code} - ${c.libelle}', overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) {
                setState(() => _selectedCaisseId = v);
                _loadEntries();
              },
            ),
          ),

          const SizedBox(width: 20),

          // Date Range Filter Button
          OutlinedButton.icon(
            onPressed: () async {
              final initialRange = (_fromDate != null && _toDate != null)
                  ? DateTimeRange(start: _fromDate!, end: _toDate!)
                  : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());

              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                initialDateRange: initialRange,
                helpText: 'Filtrer par date de suppression',
                cancelText: 'Annuler',
                confirmText: 'Appliquer',
              );

              if (picked != null) {
                setState(() {
                  _fromDate = picked.start;
                  _toDate = picked.end;
                });
                _loadEntries();
              }
            },
            icon: Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: hasDateFilter ? const Color(0xFF2563EB) : const Color(0xFF4B5563),
            ),
            label: Text(
              hasDateFilter
                  ? '${formatDate(_fromDate!)} au ${formatDate(_toDate!)}'
                  : 'Filtrer par date de suppression',
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasDateFilter ? FontWeight.w700 : FontWeight.w500,
                color: hasDateFilter ? const Color(0xFF1D4ED8) : const Color(0xFF374151),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: hasDateFilter ? const Color(0xFFEFF6FF) : Colors.white,
              side: BorderSide(color: hasDateFilter ? const Color(0xFF93C5FD) : const Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          if (hasDateFilter) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Effacer le filtre date',
              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFFEF4444)),
              onPressed: () {
                setState(() {
                  _fromDate = null;
                  _toDate = null;
                });
                _loadEntries();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Recherche rapide par libellé, compte, utilisateur...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 15, color: Color(0xFF4B5563)),
                const SizedBox(width: 6),
                Text(
                  '${_filteredEntries.length} enregistrement(s)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1020),
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
            headingTextStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
            dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
            columnSpacing: 22,
            columns: const [
              DataColumn(label: Text('Date Suppression')),
              DataColumn(label: Text('Utilisateur')),
              DataColumn(label: Text('Date Mouvement')),
              DataColumn(label: Text('Compte Source')),
              DataColumn(label: Text('Compte Dest.')),
              DataColumn(label: Text('Désignation')),
              DataColumn(label: Text('Montant'), numeric: true),
            ],
            rows: _filteredEntries.map((entry) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        Text(
                          entry.formattedDateSuppression,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.userSuppression?.trim().isNotEmpty == true
                            ? entry.userSuppression!
                            : '—',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                      ),
                    ),
                  ),
                  DataCell(Text(entry.formattedMovDate)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(entry.sourceDisplayName),
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(entry.destDisplayName),
                      ],
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        entry.movDesignation.isEmpty ? '—' : entry.movDesignation,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${formatMoney(entry.movMontant)} DA',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
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

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Aucune suppression trouvée',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Aucun mouvement supprimé ne correspond aux filtres sélectionnés.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44, color: AppColors.brickEmber),
          const SizedBox(height: 10),
          Text('Erreur: $_error', style: const TextStyle(color: AppColors.brickEmber)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadEntries,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
