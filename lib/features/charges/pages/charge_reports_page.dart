import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/database/database.dart';
import '../../../core/services/charge_calculator.dart';
import '../../../data/datasources/charges_data_source.dart';
import '../../../data/models/charge.dart';
import '../../../data/models/compte.dart';
import '../../../data/repositories/charges_repository.dart';
import '../controllers/charges_controller.dart';

class ChargeReportsPage extends StatefulWidget {
  const ChargeReportsPage({super.key});

  @override
  State<ChargeReportsPage> createState() => _ChargeReportsPageState();
}

class _ChargeReportsPageState extends State<ChargeReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ChargesController _controller;

  List<Charge> _allCharges = [];
  List<Compte> _expenseAccounts = [];
  bool _loading = true;
  String? _error;

  // Period Filter
  late DateTime _periodeDebut;
  late DateTime _periodeFin;

  // Filters for Report A
  String? _selectedAccountIdA;
  String _searchA = '';

  // Filters for Report B
  String? _selectedAccountIdB;
  String _searchB = '';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'fr_DZ',
    symbol: 'DZD',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final now = DateTime.now();
    _periodeDebut = DateTime(now.year, now.month, 1);
    _periodeFin = DateTime(now.year, now.month + 1, 0); // last day of current month

    final ds = ChargesDataSource(Database.instance);
    final repo = ChargesRepository(ds, Database.instance);
    _controller = ChargesController(repo);

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Rapports des Charges',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'تقارير المصاريف الدورية والاستهلاك',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Calcul comptable au prorata temporis et tableau d\'amortissement selon les normes.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Period Selector
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Période: ${_dateFormat.format(_periodeDebut)} au ${_dateFormat.format(_periodeFin)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                          tooltip: 'Modifier la période',
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDateRange: DateTimeRange(start: _periodeDebut, end: _periodeFin),
                            );
                            if (picked != null) {
                              setState(() {
                                _periodeDebut = picked.start;
                                _periodeFin = picked.end;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabs
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.receipt_long_rounded),
                    text: 'Rapport A: Charges Simples (Prorata Période)',
                  ),
                  Tab(
                    icon: Icon(Icons.account_balance_rounded),
                    text: 'Rapport B: Charges Amortissables (Dotations & Actif)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Erreur: $_error', style: const TextStyle(color: AppColors.error)),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _loadData, child: const Text('Réessayer')),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildReportASimpleCharges(),
                            _buildReportBAmortizableCharges(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REPORT A: CHARGES SIMPLES ---
  Widget _buildReportASimpleCharges() {
    List<Charge> simples = _allCharges.where((c) => c.isSimple).toList();

    if (_searchA.trim().isNotEmpty) {
      final q = _searchA.trim().toLowerCase();
      simples = simples.where((c) {
        return c.refCharge.toLowerCase().contains(q) ||
            c.designation.toLowerCase().contains(q) ||
            (c.compteLibelle ?? '').toLowerCase().contains(q) ||
            (c.observation ?? '').toLowerCase().contains(q);
      }).toList();
    }

    if (_selectedAccountIdA != null && _selectedAccountIdA != 'ALL') {
      simples = simples.where((c) => c.compteId == _selectedAccountIdA).toList();
    }

    // Run calculations
    final List<Map<String, dynamic>> calculatedRows = [];
    double totalFactures = 0;
    double totalImputePeriode = 0;

    for (final c in simples) {
      if (c.dateDebutConsommation == null || c.dateFinConsommation == null) continue;
      final calc = ChargeCalculator.calculateSimpleCharge(
        charge: c,
        reportStart: _periodeDebut,
        reportEnd: _periodeFin,
      );

      // Only display charges with consumption period overlap > 0 or occurring in period
      if (calc.joursPeriode > 0) {
        totalFactures += c.montantCharge;
        totalImputePeriode += calc.montantPeriode;
        calculatedRows.add({
          'charge': c,
          'calc': calc,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar for Tab A
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Recherche...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _searchA = val),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    value: _selectedAccountIdA ?? 'ALL',
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Compte de charge',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('Tous les comptes')),
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
                    onChanged: (val) => setState(() => _selectedAccountIdA = val),
                  ),
                ),
                const Spacer(),
                Text(
                  '${calculatedRows.length} charges rattachées à la période',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // KPI Summary Bar
        Row(
          children: [
            Expanded(
              child: _buildReportMetricCard(
                'Total Factures Originales',
                _currencyFormat.format(totalFactures),
                AppColors.textPrimary,
                Icons.receipt_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildReportMetricCard(
                'Montant Imputé sur la Période',
                _currencyFormat.format(totalImputePeriode),
                AppColors.primary,
                Icons.calendar_view_day_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Table
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            child: calculatedRows.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune charge simple avec consommation sur la période sélectionnée.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.surface),
                        columnSpacing: 14,
                        columns: const [
                          DataColumn(label: Text('Réf.')),
                          DataColumn(label: Text('Début Conso.')),
                          DataColumn(label: Text('Fin Conso.')),
                          DataColumn(label: Text('Compte')),
                          DataColumn(label: Text('Désignation')),
                          DataColumn(label: Text('Total Facture'), numeric: true),
                          DataColumn(label: Text('Jours Conso.'), numeric: true),
                          DataColumn(label: Text('Jours Période'), numeric: true),
                          DataColumn(label: Text('Montant Période'), numeric: true),
                        ],
                        rows: calculatedRows.map((row) {
                          final Charge c = row['charge'];
                          final SimpleChargeCalculation calc = row['calc'];
                          return DataRow(cells: [
                            DataCell(Text(c.refCharge, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(_dateFormat.format(c.dateDebutConsommation!))),
                            DataCell(Text(_dateFormat.format(c.dateFinConsommation!))),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  c.compteLibelle != null ? '${c.compteCode} - ${c.compteLibelle}' : c.compteId,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(c.designation, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            DataCell(Text(_currencyFormat.format(c.montantCharge))),
                            DataCell(Text('${calc.joursConsommation} j')),
                            DataCell(
                              Text(
                                '${calc.joursPeriode} j',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                            DataCell(
                              Text(
                                _currencyFormat.format(calc.montantPeriode),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // --- REPORT B: CHARGES AMORTISSABLES ---
  Widget _buildReportBAmortizableCharges() {
    List<Charge> amortissables = _allCharges.where((c) => c.isAmortissable).toList();

    if (_searchB.trim().isNotEmpty) {
      final q = _searchB.trim().toLowerCase();
      amortissables = amortissables.where((c) {
        return c.refCharge.toLowerCase().contains(q) ||
            c.designation.toLowerCase().contains(q) ||
            (c.compteLibelle ?? '').toLowerCase().contains(q) ||
            (c.observation ?? '').toLowerCase().contains(q);
      }).toList();
    }

    if (_selectedAccountIdB != null && _selectedAccountIdB != 'ALL') {
      amortissables = amortissables.where((c) => c.compteId == _selectedAccountIdB).toList();
    }

    final List<Map<String, dynamic>> calculatedRows = [];
    double totalActif = 0;
    double totalAmortPeriode = 0;
    double totalAmortCumule = 0;
    double totalResteAAmortir = 0;

    for (final c in amortissables) {
      final calc = ChargeCalculator.calculateAmortizableCharge(
        charge: c,
        reportStart: _periodeDebut,
        reportEnd: _periodeFin,
      );

      totalActif += c.montantCharge;
      totalAmortPeriode += calc.montantAmortiPeriode;
      totalAmortCumule += calc.montantAmortiCumule;
      totalResteAAmortir += calc.resteAAmortir;

      calculatedRows.add({
        'charge': c,
        'calc': calc,
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar for Tab B
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Recherche...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _searchB = val),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    value: _selectedAccountIdB ?? 'ALL',
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Compte immobilisation',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('Tous les comptes')),
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
                    onChanged: (val) => setState(() => _selectedAccountIdB = val),
                  ),
                ),
                const Spacer(),
                Text(
                  '${calculatedRows.length} immobilisations suivies',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // KPI Summary Bar
        Row(
          children: [
            Expanded(
              child: _buildReportMetricCard(
                'Valeur Brute (Actif)',
                _currencyFormat.format(totalActif),
                AppColors.textPrimary,
                Icons.account_balance_wallet_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildReportMetricCard(
                'Dotation Période',
                _currencyFormat.format(totalAmortPeriode),
                Colors.indigo,
                Icons.schedule_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildReportMetricCard(
                'Amortissement Cumulé',
                _currencyFormat.format(totalAmortCumule),
                AppColors.warning,
                Icons.layers_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildReportMetricCard(
                'Valeur Nette (VNC)',
                _currencyFormat.format(totalResteAAmortir),
                AppColors.success,
                Icons.verified_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Table
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            child: calculatedRows.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune charge amortissable enregistrée.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.surface),
                        columnSpacing: 14,
                        columns: const [
                          DataColumn(label: Text('Réf.')),
                          DataColumn(label: Text('Début Amort.')),
                          DataColumn(label: Text('Fin Amort.')),
                          DataColumn(label: Text('Désignation')),
                          DataColumn(label: Text('Compte')),
                          DataColumn(label: Text('Valeur Origine'), numeric: true),
                          DataColumn(label: Text('Jours Total'), numeric: true),
                          DataColumn(label: Text('Jours Période'), numeric: true),
                          DataColumn(label: Text('Dotation Période'), numeric: true),
                          DataColumn(label: Text('Amort. Cumulé'), numeric: true),
                          DataColumn(label: Text('VNC Restante'), numeric: true),
                        ],
                        rows: calculatedRows.map((row) {
                          final Charge c = row['charge'];
                          final AmortizableChargeCalculation calc = row['calc'];
                          final debutAmort = c.dateDebutAmortissement ?? c.dateCharge;

                          return DataRow(cells: [
                            DataCell(Text(c.refCharge, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(_dateFormat.format(debutAmort))),
                            DataCell(
                              Text(c.dateFinAmortissement != null ? _dateFormat.format(c.dateFinAmortissement!) : '-'),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Text(c.designation, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  c.compteLibelle != null ? '${c.compteCode} - ${c.compteLibelle}' : c.compteId,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(Text(_currencyFormat.format(c.montantCharge))),
                            DataCell(Text('${calc.joursAmortissementTotal} j')),
                            DataCell(Text('${calc.joursPeriode} j')),
                            DataCell(
                              Text(
                                _currencyFormat.format(calc.montantAmortiPeriode),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                            ),
                            DataCell(
                              Text(
                                _currencyFormat.format(calc.montantAmortiCumule),
                                style: const TextStyle(color: AppColors.warning),
                              ),
                            ),
                            DataCell(
                              Text(
                                _currencyFormat.format(calc.resteAAmortir),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportMetricCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
