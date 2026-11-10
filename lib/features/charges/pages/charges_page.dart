import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/database/database.dart';
import '../../../core/security/session.dart';
import '../../../data/datasources/charges_data_source.dart';
import '../../../data/models/charge.dart';
import '../../../data/models/compte.dart';
import '../../../data/repositories/charges_repository.dart';
import '../controllers/charges_controller.dart';
import '../widgets/charge_dialog.dart';
import '../widgets/charge_payment_dialog.dart';
import '../widgets/charge_payments_history_dialog.dart';

class ChargesPage extends StatefulWidget {
  const ChargesPage({super.key});

  @override
  State<ChargesPage> createState() => _ChargesPageState();
}

class _ChargesPageState extends State<ChargesPage> {
  late final ChargesController _controller;
  List<Charge> _allCharges = [];
  List<Charge> _filteredCharges = [];
  List<Compte> _expenseAccounts = [];

  bool _loading = true;
  String? _error;

  // Filters
  String _searchQuery = '';
  String? _selectedCategory; // 'ALL', 'SIMPLE', 'AMORTISSABLE'
  String? _selectedStatus; // 'ALL', 'UNPAID', 'PARTIALLY_PAID', 'PAID'
  String? _selectedAccountId;
  DateTimeRange? _selectedDateRange;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'fr_DZ',
    symbol: 'DZD',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final ds = ChargesDataSource(Database.instance);
    final repo = ChargesRepository(ds, Database.instance);
    _controller = ChargesController(repo);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final charges = await _controller.loadCharges();
      final accounts = await _controller.loadExpenseAccounts();
      if (mounted) {
        setState(() {
          _allCharges = charges;
          _expenseAccounts = accounts;
          _loading = false;
        });
        _applyFilters();
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

  void _applyFilters() {
    List<Charge> list = List.from(_allCharges);

    // Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((c) {
        final ref = c.refCharge.toLowerCase();
        final des = c.designation.toLowerCase();
        final obs = (c.observation ?? '').toLowerCase();
        final acc = '${c.compteCode ?? ''} ${c.compteLibelle ?? ''}'
            .toLowerCase();
        return ref.contains(q) ||
            des.contains(q) ||
            obs.contains(q) ||
            acc.contains(q);
      }).toList();
    }

    // Category
    if (_selectedCategory != null && _selectedCategory != 'ALL') {
      list = list.where((c) => c.categorieCharge == _selectedCategory).toList();
    }

    // Status
    if (_selectedStatus != null && _selectedStatus != 'ALL') {
      list = list.where((c) {
        switch (_selectedStatus) {
          case 'UNPAID':
            return c.paymentStatus == ChargePaymentStatus.unpaid;
          case 'PARTIALLY_PAID':
            return c.paymentStatus == ChargePaymentStatus.partiallyPaid;
          case 'PAID':
            return c.paymentStatus == ChargePaymentStatus.paid;
          default:
            return true;
        }
      }).toList();
    }

    // Account
    if (_selectedAccountId != null && _selectedAccountId != 'ALL') {
      list = list.where((c) => c.compteId == _selectedAccountId).toList();
    }

    // Date Range
    if (_selectedDateRange != null) {
      list = list.where((c) {
        final d = c.dateCharge;
        return (d.isAfter(
              _selectedDateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            d.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));
      }).toList();
    }

    setState(() {
      _filteredCharges = list;
    });
  }

  Future<void> _openCreateOrEditDialog([Charge? charge]) async {
    String nextRef = '';
    if (charge == null) {
      try {
        nextRef = await _controller.getNextReference();
      } catch (_) {
        nextRef = 'CHG-2026-0001';
      }
    } else {
      nextRef = charge.referance;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChargeDialog(
        existingCharge: charge,
        expenseAccounts: _expenseAccounts,
        nextReference: nextRef,
        onSave: (chargeToSave, isNew) async {
          await _controller.saveCharge(chargeToSave, isNew: isNew);
          _loadData();
        },
      ),
    );
  }

  void _openPaymentDialog(Charge charge) {
    final currentUserId = Session.user?.id ?? 'USER-1';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChargePaymentDialog(
        charge: charge,
        controller: _controller,
        userId: currentUserId,
        onPaymentSuccess: () {
          _loadData();
        },
      ),
    );
  }

  Future<void> _deleteCharge(Charge charge) async {
    // Check if this charge was auto-created from trésorerie
    final linkedMvtId = await _controller.getAutoLinkedMovementId(charge.idCharge);
    final isAutoCharge = linkedMvtId != null;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              isAutoCharge ? Icons.warning_amber_rounded : Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'Supprimer la charge ?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${charge.refCharge} — ${charge.designation}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (isAutoCharge) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cette charge a été créée automatiquement depuis la Trésorerie.\n'
                        'Sa suppression supprimera aussi le mouvement de trésorerie associé.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAutoCharge ? 'Supprimer (charge + mouvement)' : 'Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      if (isAutoCharge) {
        // 1. Find and delete DETAIL_MVT_CHARGES row (triggers TRG_DMC_AD → resets MONTANT_REGLE)
        final linked = await _controller.getAutoChargeForMovement(linkedMvtId);
        if (linked != null) {
          await _controller.deleteDetailMvtCharge(linked.detailId);
        }
        // 2. Delete the trésorerie movement
        await _controller.deleteMovement(linkedMvtId);
      }
      // 3. Delete the charge
      await _controller.deleteCharge(charge.idCharge);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAutoCharge
                  ? 'Charge et mouvement de trésorerie supprimés avec succès.'
                  : 'Charge supprimée avec succès.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  void _openHistoryDialog(Charge charge) {
    showDialog(
      context: context,
      builder: (ctx) =>
          ChargePaymentsHistoryDialog(charge: charge, controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    // KPI Calculations
    final totalMontant = _allCharges.fold<double>(
      0.0,
      (sum, c) => sum + c.montantCharge,
    );
    final totalRegle = _allCharges.fold<double>(
      0.0,
      (sum, c) => sum + c.montantRegle,
    );
    final totalReste = _allCharges.fold<double>(
      0.0,
      (sum, c) => sum + c.resteARegler,
    );
    final countSimple = _allCharges.where((c) => c.isSimple).length;
    final countAmort = _allCharges.where((c) => c.isAmortissable).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Main Action Bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Gestion des Charges',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            // child: const Text(
                            //   'ط¥ط¯ط§ط±ط© ظ…طµط§ط±ظٹظپ ط§ظ„ط´ط±ظƒط©',
                            //   style: TextStyle(
                            //     fontSize: 13,
                            //     fontWeight: FontWeight.bold,
                            //     color: AppColors.primary,
                            //   ),
                            // ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Suivi et gestion des charges simples et amortissables, reglements et comptabilisation.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (Session.user?.hasCreateChargesPermission ?? true)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _openCreateOrEditDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Nouvelle Charge',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // KPI Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Charges',
                    value: _currencyFormat.format(totalMontant),
                    subtitle: '${_allCharges.length} operations',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Montant Regle',
                    value: _currencyFormat.format(totalRegle),
                    subtitle: totalMontant > 0
                        ? '${((totalRegle / totalMontant) * 100).toStringAsFixed(1)}% regle'
                        : '0%',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Reste e Regler',
                    value: _currencyFormat.format(totalReste),
                    subtitle: 'Engagements en cours',
                    icon: Icons.pending_actions_rounded,
                    color: totalReste > 0
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Repartition',
                    value: '$countSimple Simples',
                    subtitle: '$countAmort Amortissables',
                    icon: Icons.pie_chart_outline_rounded,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filters Bar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search
                    SizedBox(
                      width: 350,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher reference, libelle...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (val) {
                          _searchQuery = val;
                          _applyFilters();
                        },
                      ),
                    ),

                    // Filter Category
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory ?? 'ALL',
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Categorie',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text('Toutes categories'),
                          ),
                          DropdownMenuItem(
                            value: 'SIMPLE',
                            child: Text('Charge Simple'),
                          ),
                          DropdownMenuItem(
                            value: 'AMORTISSABLE',
                            child: Text('Amortissable'),
                          ),
                        ],
                        onChanged: (val) {
                          _selectedCategory = val;
                          _applyFilters();
                        },
                      ),
                    ),

                    // Filter Status
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus ?? 'ALL',
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Statut Paiement',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text('Tous les statuts'),
                          ),
                          DropdownMenuItem(
                            value: 'UNPAID',
                            child: Text('Non payee'),
                          ),
                          DropdownMenuItem(
                            value: 'PARTIALLY_PAID',
                            child: Text('Partiellement payee'),
                          ),
                          DropdownMenuItem(
                            value: 'PAID',
                            child: Text('Totalement payee'),
                          ),
                        ],
                        onChanged: (val) {
                          _selectedStatus = val;
                          _applyFilters();
                        },
                      ),
                    ),

                    // Filter Account
                    SizedBox(
                      width: 350,
                      child: DropdownButtonFormField<String>(
                        value: _selectedAccountId ?? 'ALL',
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Compte de charge',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'ALL',
                            child: Text('Tous les comptes'),
                          ),
                          ..._expenseAccounts.map((acc) {
                            return DropdownMenuItem(
                              value: acc.idCompte,
                              child: Text(
                                '${acc.code} - ${acc.nomCompte}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          _selectedAccountId = val;
                          _applyFilters();
                        },
                      ),
                    ),

                    // Date range picker button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDateRange: _selectedDateRange,
                        );
                        if (picked != null) {
                          setState(() => _selectedDateRange = picked);
                          _applyFilters();
                        }
                      },
                      icon: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(
                        _selectedDateRange != null
                            ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}'
                            : 'Filtrer par date',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                    if (_selectedDateRange != null ||
                        _selectedCategory != null &&
                            _selectedCategory != 'ALL' ||
                        _selectedStatus != null && _selectedStatus != 'ALL' ||
                        _selectedAccountId != null &&
                            _selectedAccountId != 'ALL' ||
                        _searchQuery.isNotEmpty)
                      IconButton(
                        tooltip: 'Reinitialiser les filtres',
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.error,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedCategory = 'ALL';
                            _selectedStatus = 'ALL';
                            _selectedAccountId = 'ALL';
                            _selectedDateRange = null;
                          });
                          _applyFilters();
                        },
                      ),
                    // Refresh Button
                    IconButton(
                      tooltip: 'Actualiser',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Data Table
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Erreur: $_error',
                              style: const TextStyle(color: AppColors.error),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Ressayer'),
                            ),
                          ],
                        ),
                      )
                    : _filteredCharges.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune charge enregistree.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              AppColors.surface,
                            ),
                            horizontalMargin: 16,
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('Reference')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Categorie')),
                              DataColumn(label: Text('Designation')),
                              DataColumn(label: Text('Compte')),
                              DataColumn(
                                label: Text('Montant Total'),
                                numeric: true,
                              ),
                              DataColumn(label: Text('Regle'), numeric: true),
                              DataColumn(
                                label: Text('Reste a Regler'),
                                numeric: true,
                              ),
                              DataColumn(label: Text('Statut')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _filteredCharges.map((c) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      c.refCharge,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_dateFormat.format(c.dateCharge)),
                                  ),
                                  DataCell(_buildCategoryBadge(c)),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        c.designation,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        c.compteLibelle != null
                                            ? '${c.compteCode ?? ''} - ${c.compteLibelle}'
                                            : c.compteId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _currencyFormat.format(c.montantCharge),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _currencyFormat.format(c.montantRegle),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: c.montantRegle > 0
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _currencyFormat.format(c.resteARegler),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: c.resteARegler > 0.001
                                            ? AppColors.warning
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  DataCell(_buildStatusBadge(c.paymentStatus)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (Session
                                                .user
                                                ?.hasUpdateChargesPermission ??
                                            true)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                            ),
                                            tooltip: 'Modifier la charge',
                                            onPressed: () =>
                                                _openCreateOrEditDialog(c),
                                          ),
                                        if (Session
                                                .user
                                                ?.hasUpdateChargesPermission ??
                                            true)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.payment_rounded,
                                              size: 18,
                                              color: AppColors.success,
                                            ),
                                            tooltip: c.resteARegler > 0.001
                                                ? 'Enregistrer un reglement'
                                                : 'Totalement regle',
                                            onPressed: c.resteARegler > 0.001
                                                ? () => _openPaymentDialog(c)
                                                : null,
                                          ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.history_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          tooltip: 'Historique des reglements',
                                          onPressed: () =>
                                              _openHistoryDialog(c),
                                        ),
                                        if (Session
                                                .user
                                                ?.hasDeleteChargesPermission ??
                                            true)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: AppColors.error,
                                            ),
                                            tooltip: 'Supprimer la charge',
                                            onPressed: () => _deleteCharge(c),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(Charge c) {
    final isSimple = c.isSimple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSimple
            ? Colors.blue.withOpacity(0.1)
            : Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSimple
              ? Colors.blue.withOpacity(0.3)
              : Colors.purple.withOpacity(0.3),
        ),
      ),
      child: Text(
        isSimple ? 'Simple' : 'Amortissable',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSimple ? Colors.blue.shade700 : Colors.purple.shade700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ChargePaymentStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case ChargePaymentStatus.paid:
        bg = AppColors.success.withOpacity(0.12);
        fg = AppColors.success;
        label = 'Reglee';
        break;
      case ChargePaymentStatus.partiallyPaid:
        bg = AppColors.warning.withOpacity(0.12);
        fg = AppColors.warning;
        label = 'Partielle';
        break;
      case ChargePaymentStatus.unpaid:
        bg = AppColors.error.withOpacity(0.12);
        fg = AppColors.error;
        label = 'Non reglee';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}


