import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../../core/security/session.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/models/movement.dart';
import '../controllers/accounting_controller.dart';

/// Professional Statistics & Analytics Section for Trésorerie
/// 1. Movements by Caisse or All Caisses for selected Compte (Tree view).
/// 2. Dashboard with Caisse Cards (showing transactions and balances) and Total Charges.
/// 3. Strict access control enforcement (users only see caisses they have access to).
class TresorerieStatistiquesDialog extends StatefulWidget {
  final AccountingController controller;
  final List<Compte> allAccounts;
  final List<Compte> userCaisses;
  final Compte? initialCaisse;
  final bool isEmbedded;
  final ValueChanged<Compte>? onOpenCaisse;
  final VoidCallback? onOpenTresorerie;

  const TresorerieStatistiquesDialog({
    super.key,
    required this.controller,
    required this.allAccounts,
    required this.userCaisses,
    this.initialCaisse,
    this.isEmbedded = false,
    this.onOpenCaisse,
    this.onOpenTresorerie,
  });

  static Future<void> show(
    BuildContext context, {
    required AccountingController controller,
    required List<Compte> allAccounts,
    required List<Compte> userCaisses,
    Compte? initialCaisse,
    ValueChanged<Compte>? onOpenCaisse,
    VoidCallback? onOpenTresorerie,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TresorerieStatistiquesDialog(
        controller: controller,
        allAccounts: allAccounts,
        userCaisses: userCaisses,
        initialCaisse: initialCaisse,
        onOpenCaisse: onOpenCaisse,
        onOpenTresorerie: onOpenTresorerie,
      ),
    );
  }

  @override
  State<TresorerieStatistiquesDialog> createState() => _TresorerieStatistiquesDialogState();
}

class _TresorerieStatistiquesDialogState extends State<TresorerieStatistiquesDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  final ScrollController _caisseScrollController = ScrollController();
  final ScrollController _dashboardScrollController = ScrollController();

  // Multi-caisse selection: empty set = toutes les caisses autorisées
  final Set<String> _selectedCaisseIds = {};
  Compte? _selectedCompte;

  // Search & Tree expansion
  final TextEditingController _compteSearchCtrl = TextEditingController();
  String _searchFilter = '';
  final Set<String> _expandedCompteIds = {};

  // Loaded data
  bool _loading = true;
  String? _error;
  List<Movement> _movements = [];
  Map<String, Map<String, dynamic>> _caissesSummary = {};
  Map<String, dynamic> _chargesStats = {'count': 0, 'total': 0.0};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final canViewOld = Session.user?.hasViewOldSoldePermission ?? true;
    _startDate = canViewOld ? DateTime(now.year, now.month, 1) : DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);

    // Pre-select the initial caisse if provided
    if (widget.initialCaisse != null) {
      _selectedCaisseIds.add(widget.initialCaisse!.id);
    }

    // Expand top level accounts by default
    for (final a in widget.allAccounts) {
      if (a.niveau <= 2) _expandedCompteIds.add(a.id);
    }

    _loadStatistics();
  }

  @override
  void dispose() {
    _compteSearchCtrl.dispose();
    _caisseScrollController.dispose();
    _dashboardScrollController.dispose();
    super.dispose();
  }

  /// Returns the effective caisse IDs for queries:
  /// - If user selected specific caisses → use those
  /// - Otherwise → use all allowed caisses
  Set<String> get _effectiveCaisseIds =>
      _selectedCaisseIds.isNotEmpty ? _selectedCaisseIds : _allowedCaisseIds;

  Set<String> get _allowedCaisseIds => widget.userCaisses.map((c) => c.id).toSet();

  Future<void> _loadStatistics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final caisseIdsToQuery = widget.userCaisses.map((c) => c.id).toList();

      // 1. Load caisses dashboard summary (always for all accessible caisses)
      final summaries = await widget.controller.loadCaissesSummary(
        caisseIds: caisseIdsToQuery,
        from: _startDate,
        to: _endDate,
      );

      // 2. Load total charges (Classe 6) — scoped to selected caisses
      final charges = await widget.controller.loadChargesStatistics(
        allowedCaisseIds: _effectiveCaisseIds,
        from: _startDate,
        to: _endDate,
      );

      // 3. Load movements scoped to selected caisses + compte BG/BD hierarchy
      final movs = await widget.controller.loadMovements(
        compteId: _selectedCompte?.id,
        compteBg: _selectedCompte?.bg,
        compteBd: _selectedCompte?.bd,
        allowedCaisseIds: _effectiveCaisseIds,
        from: _startDate,
        to: _endDate,
      );

      if (!mounted) return;
      setState(() {
        _caissesSummary = summaries;
        _chargesStats = charges;
        _movements = movs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erreur lors du calcul des statistiques: $e';
      });
    }
  }

  // Reload only the movements when the selected compte changes.
  Future<void> _loadMovementsOnly() async {
    try {
      final movs = await widget.controller.loadMovements(
        compteId: _selectedCompte?.id,
        compteBg: _selectedCompte?.bg,
        compteBd: _selectedCompte?.bd,
        allowedCaisseIds: _effectiveCaisseIds,
        from: _startDate,
        to: _endDate,
      );

      if (!mounted) return;
      setState(() {
        _movements = movs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des mouvements: $e')),
      );
    }
  }

  Future<void> _pickDateRange() async {
    final canViewOld = Session.user?.hasViewOldSoldePermission ?? true;
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: canViewOld ? DateTime(2000) : DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2035),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: now, end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF18181B),
              onPrimary: Colors.white,
              onSurface: Color(0xFF18181B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadStatistics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      height: double.infinity,
      padding: widget.isEmbedded ? const EdgeInsets.all(20) : const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFilterBar(),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      )
                    : _buildContent(),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: SizedBox(
        width: 1200,
        height: 750,
        child: content,
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4E4E7)),
          ),
          child: const Icon(Icons.analytics_rounded, color: Color(0xFF18181B), size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Statistiques & Analyses de Trésorerie',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF09090B), letterSpacing: -0.4),
            ),
            SizedBox(height: 2),
            Text(
              'Tableau de bord multi-caisses, suivi des charges et mouvements par compte',
              style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
            ),
          ],
        ),
        const Spacer(),
        if (widget.onOpenTresorerie != null) ...[
          ElevatedButton.icon(
            onPressed: widget.onOpenTresorerie,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text(
              'Ouvrir une Caisse',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (!widget.isEmbedded)
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF71717A), size: 22),
          ),
      ],
    );
  }

  // ============================================================
  // FILTER BAR (Période, Multi-sélection Caisses, Recharger)
  // ============================================================
  Widget _buildFilterBar() {
   final canViewOld = Session.user?.hasViewOldSoldePermission ?? true;
   final allSelected = _selectedCaisseIds.isEmpty;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Row 1: Date range + refresh
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(12),
          ),
          border: Border.all(color: const Color(0xFFE4E4E7)),
        ),
        child: Row(
          children: [
            // Date Range button
            InkWell(
              onTap: canViewOld ? _pickDateRange : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E4E7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Color(0xFF18181B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _startDate != null && _endDate != null
                          ? '${formatDate(_startDate!)}  ➔  ${formatDate(_endDate!)}'
                          : 'Sélectionner la période',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF09090B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),

            // Compte filter badge if selected
            if (_selectedCompte != null) ...[
              Chip(
                backgroundColor: const Color(0xFFDBEAFE),
                label: Text(
                  'Compte: ${_selectedCompte!.displayName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                deleteIcon: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFF1D4ED8),
                ),
                onDeleted: () {
                  setState(() => _selectedCompte = null);
                  _loadMovementsOnly();
                },
              ),
              const SizedBox(width: 10),
            ],

            // Refresh button
            FButton(
              onPress: _loadStatistics,
              prefix: const Icon(Icons.refresh_rounded, size: 16),
              child: const Text('Actualiser'),
            ),
          ],
        ),
      ),

      // Row 2: Multi-caisse selector chips
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
          border: const Border(
            left: BorderSide(color: Color(0xFFE4E4E7)),
            right: BorderSide(color: Color(0xFFE4E4E7)),
            bottom: BorderSide(color: Color(0xFFE4E4E7)),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: Color(0xFF71717A),
            ),
            const SizedBox(width: 8),
            const Text(
              'Caisses :',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 6),

            // Caisse chips with left/right scrolling buttons
            Expanded(
              child: Row(
                children: [
                  // Scroll left
                  IconButton(
                    tooltip: 'Défiler vers la gauche',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: Color(0xFF374151),
                    ),
                    onPressed: () {
                      if (_caisseScrollController.hasClients) {
                        final position = _caisseScrollController.position;

                        _caisseScrollController.animateTo(
                          (_caisseScrollController.offset - 200).clamp(
                            0.0,
                            position.maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),

                  // Horizontal list — scrollbar hidden
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _caisseScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // "Toutes" chip
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.all_inclusive_rounded,
                                    size: 14,
                                    color: allSelected
                                        ? Colors.white
                                        : const Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Toutes (${widget.userCaisses.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: allSelected
                                          ? Colors.white
                                          : const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                              selected: allSelected,
                              onSelected: (_) {
                                setState(() => _selectedCaisseIds.clear());
                                _loadStatistics();
                              },
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: const Color(0xFFEFF6FF),
                              checkmarkColor: Colors.white,
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: allSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFBFDBFE),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                          ),

                          // One chip per caisse
                          ...widget.userCaisses.map((caisse) {
                            final isSelected =
                                _selectedCaisseIds.contains(caisse.id);

                            final isBanque =
                                caisse.libelle.toLowerCase().contains('banque') ||
                                caisse.typeCompte == CompteType.banque;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isBanque
                                          ? Icons.account_balance_rounded
                                          : Icons.point_of_sale_rounded,
                                      size: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF374151),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      caisse.displayName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedCaisseIds.add(caisse.id);
                                    } else {
                                      _selectedCaisseIds.remove(caisse.id);
                                    }
                                  });
                                  _loadStatistics();
                                },
                                selectedColor: const Color(0xFF18181B),
                                backgroundColor: const Color(0xFFF4F4F5),
                                checkmarkColor: Colors.white,
                                showCheckmark: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF18181B)
                                        : const Color(0xFFE4E4E7),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Scroll right
                  IconButton(
                    tooltip: 'Défiler vers la droite',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Color(0xFF374151),
                    ),
                    onPressed: () {
                      if (_caisseScrollController.hasClients) {
                        final position = _caisseScrollController.position;

                        _caisseScrollController.animateTo(
                          (_caisseScrollController.offset + 200).clamp(
                            0.0,
                            position.maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Selection count badge and clear button
            if (_selectedCaisseIds.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedCaisseIds.length} sélectionnée(s)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() => _selectedCaisseIds.clear());
                  _loadStatistics();
                },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.clear_all_rounded,
                    size: 16,
                    color: Color(0xFF71717A),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

  // ============================================================
  // MAIN CONTENT (Dashboard Cards + Split View Tree & Movements)
  // ============================================================
  Widget _buildContent() {
    return Column(
      children: [
        _buildDashboardCards(),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Account Tree Selector (Tree of Comptes)
              SizedBox(
                width: 380,
                child: _buildAccountTreePanel(),
              ),
              const SizedBox(width: 16),

              // Right: Movements Table for selected account / caisse
              Expanded(
                child: _buildMovementsPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DASHBOARD CARDS (Caisse name, Montant, Transactions & Charges)
  // ============================================================
 
Widget _buildDashboardCards() {
  final totalCharges = (_chargesStats['total'] as num?)?.toDouble() ?? 0.0;
  final countCharges = (_chargesStats['count'] as num?)?.toInt() ?? 0;

  return SizedBox(
    height: 126,
    child: Row(
      children: [
        // Left arrow
        IconButton(
          tooltip: 'Précédent',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            if (!_dashboardScrollController.hasClients) return;

            final position = _dashboardScrollController.position;
            _dashboardScrollController.animateTo(
              (position.pixels - 250).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          },
        ),

        // Dashboard cards
        Expanded(
          child: ListView(
            controller: _dashboardScrollController,
            scrollDirection: Axis.horizontal,
            children: [
              // Charges Card
              Container(
                width: 250,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFEE2E2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Total Charges (Classe 6)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.trending_down_rounded,
                            size: 15,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '-${formatMoney(totalCharges)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    Text(
                      '$countCharges dépense(s) enregistrée(s)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),

              // Cards for each authorized caisse/banque
              ...widget.userCaisses.map((caisse) {
                final stats = _caissesSummary[caisse.id] ?? {};
                final soldeFinal =
                    (stats['soldeFinal'] as num?)?.toDouble() ?? 0.0;
                final count = (stats['count'] as num?)?.toInt() ?? 0;
                final isSelected = _selectedCaisseIds.contains(caisse.id);

                // Devise data from enriched summary
                final deviseSoldeFinal = (stats['deviseSoldeFinal'] as num?)?.toDouble() ?? 0.0;
                // Show in devise ONLY when the caisse itself is a devise account
                final hasDevise = caisse.isDevise;
                final currCode = caisse.codeDevise ?? 'DEV';

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCaisseIds.remove(caisse.id);
                      } else {
                        _selectedCaisseIds.add(caisse.id);
                      }
                    });
                    _loadStatistics();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 230,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF4F4F5)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF18181B)
                            : const Color(0xFFE4E4E7),
                        width: isSelected ? 1.6 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                caisse.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF09090B),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Color(0xFF18181B),
                              )
                            else
                              Icon(
                                caisse.libelle.toLowerCase().contains('banque')
                                    ? Icons.account_balance_rounded
                                    : Icons.point_of_sale_rounded,
                                size: 16,
                                color: const Color(0xFF2563EB),
                              ),
                          ],
                        ),
                        // Primary amount: devise if hasDevise, otherwise DZD
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasDevise
                                  ? '${deviseSoldeFinal.toStringAsFixed(2)} $currCode'
                                  : formatMoney(soldeFinal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: (hasDevise ? deviseSoldeFinal : soldeFinal) >= 0
                                    ? const Color(0xFF09090B)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                            if (hasDevise)
                              Text(
                                '≈ ${formatMoney(soldeFinal)} DZD',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF71717A)),
                              ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '$count transaction(s)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ),
                            if (widget.onOpenCaisse != null)
                              InkWell(
                                onTap: () =>
                                    widget.onOpenCaisse!(caisse),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Ouvrir',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 12,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),

        // Right arrow
        IconButton(
          tooltip: 'Suivant',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            if (!_dashboardScrollController.hasClients) return;

            final position = _dashboardScrollController.position;
            _dashboardScrollController.animateTo(
              (position.pixels + 250).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          },
        ),
      ],
    ),
  );
}
  // ============================================================
  // ACCOUNT TREE PANEL (Plan Comptable Arborescent)
  // ============================================================
  Widget _buildAccountTreePanel() {
    // Filter accounts by search text
    final query = _searchFilter.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.allAccounts
        : widget.allAccounts.where((a) {
            return a.code.toLowerCase().contains(query) ||
                a.libelle.toLowerCase().contains(query) ||
                (a.compteFr ?? '').toLowerCase().contains(query);
          }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF18181B)),
                const SizedBox(width: 8),
                const Text(
                  'Arborescence des Comptes',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
                ),
                const Spacer(),
                if (_selectedCompte != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedCompte = null);
                      _loadMovementsOnly();
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Tout voir', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Search Input
            TextField(
              controller: _compteSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un compte...',
                prefixIcon: const Icon(Icons.search, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => setState(() => _searchFilter = val),
            ),
            const SizedBox(height: 10),
            const FDivider(),
            const SizedBox(height: 6),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Aucun compte trouvé', style: TextStyle(fontSize: 12, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final compte = filtered[index];
                        final isSelected = _selectedCompte?.id == compte.id;
                        final indent = (compte.niveau - 1).clamp(0, 5) * 16.0;

                        return Tooltip(
                          message: compte.isParent
                              ? 'Sélectionner inclut tous les sous-comptes (BG/BD)'
                              : compte.displayName,
                          waitDuration: const Duration(milliseconds: 600),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCompte = isSelected ? null : compte;
                              });
                              _loadMovementsOnly();
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: EdgeInsets.fromLTRB(8 + indent, 6, 8, 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFEFF6FF)
                                    : compte.isParent
                                        ? const Color(0xFFFAFAFA)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isSelected ? Border.all(color: const Color(0xFF93C5FD)) : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    compte.isParent ? Icons.folder_rounded : Icons.description_outlined,
                                    size: 15,
                                    color: compte.isParent
                                        ? (isSelected ? const Color(0xFF2563EB) : const Color(0xFFF59E0B))
                                        : (isSelected ? const Color(0xFF2563EB) : const Color(0xFF71717A)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      compte.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: compte.isParent ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF18181B),
                                      ),
                                    ),
                                  ),
                                  // Badge: parent includes all sub-account movements
                                  if (compte.isParent)
                                    Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        'tout',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
  }

  // ============================================================
  // MOVEMENTS TABLE PANEL
  // ============================================================
  Widget _buildMovementsPanel() {
    // Build a descriptive title based on the current selection
    String title;
    if (_selectedCompte != null) {
      title = 'Mouvements : ${_selectedCompte!.displayName}';
    } else if (_selectedCaisseIds.isEmpty) {
      title = 'Tous les Mouvements de Trésorerie';
    } else if (_selectedCaisseIds.length == 1) {
      final c = widget.userCaisses.firstWhere((c) => c.id == _selectedCaisseIds.first, orElse: () => widget.userCaisses.first);
      title = 'Mouvements — ${c.displayName}';
    } else {
      final names = widget.userCaisses
          .where((c) => _selectedCaisseIds.contains(c.id))
          .map((c) => c.code)
          .join(', ');
      title = 'Mouvements — $names (${_selectedCaisseIds.length} caisses)';
    }

    double totalIn = 0;
    double totalOut = 0;
    for (final m in _movements) {
      if (_selectedCaisseIds.isNotEmpty) {
        // Sum IN/OUT relative to the selected caisses
        if (_selectedCaisseIds.contains(m.compteDestId)) totalIn += m.montant;
        if (_selectedCaisseIds.contains(m.compteSourceId)) totalOut += m.montant;
      } else {
        // Global view: just accumulate total volume
        totalIn += m.montant;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: ${_movements.length} opération(s)',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                      ),
                    ],
                  ),
                ),
                if (_selectedCaisseIds.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${formatMoney(totalIn)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-${formatMoney(totalOut)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                  ),
                  child: Text(
                    'Volume: ${formatMoney(_movements.fold<double>(0, (s, m) => s + m.montant))}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const FDivider(),
            const SizedBox(height: 8),

            Expanded(
              child: _movements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.inbox_outlined, size: 40, color: Color(0xFFA1A1AA)),
                          SizedBox(height: 8),
                          Text('Aucun mouvement trouvé pour ces critères et cette période.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF71717A))),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 18,
                          headingRowHeight: 40,
                          dataRowMinHeight: 42,
                          dataRowMaxHeight: 46,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F4F5)),
                          columns: const [
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Désignation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Source (Sortie)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Destination (Entrée)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(numeric: true, label: Text('Montant (DA)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                          ],
                          rows: _movements.map((m) {
                            return DataRow(
                              cells: [
                                DataCell(Text(formatDate(m.date), style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        m.modePaiement?.isNotEmpty == true ? m.modePaiement! : 'Espèces',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      if (m.numCheque != null && m.numCheque!.isNotEmpty)
                                        Text(
                                          'N° ${m.numCheque}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    m.designation.isEmpty ? '-' : m.designation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    m.sourceDisplayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    m.destDisplayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A)),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        formatMoney(m.montant),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                      if (m.montantDevise != null && m.tauxChange != null)
                                        Text(
                                          '${m.montantDevise!.toStringAsFixed(2)} × ${m.tauxChange!.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600),
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
            ),
          ],
        ),
      );
  }
}
