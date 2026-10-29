import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../data/datasources/tiers_datasource.dart';
import '../../../../data/models/tiers.dart';
import '../../../../data/repositories/tiers_repository.dart';
import '../widgets/new_tiers_dialog.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late final TiersRepository _repository;

  final TextEditingController _searchController = TextEditingController();
  List<Tiers> _tiersList = [];
  bool _loading = true;
  String? _error;
  int? _filterTypeId; // null = all, 1 = client, 2 = fournisseur

  @override
  void initState() {
    super.initState();
    _repository = TiersRepository(TiersDataSource(Database.instance));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _repository.getAllTiers();
      if (!mounted) return;
      setState(() {
        _tiersList = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les tiers: $e';
      });
    }
  }

  List<Tiers> get _filteredTiers {
    final q = _searchController.text.trim().toLowerCase();
    return _tiersList.where((t) {
      if (_filterTypeId != null && t.idTypeClient != _filterTypeId) {
        return false;
      }
      if (q.isNotEmpty) {
        final nomMatches = t.nom.toLowerCase().contains(q);
        final telMatches = t.telephone?.toLowerCase().contains(q) ?? false;
        final nifMatches = t.nif?.toLowerCase().contains(q) ?? false;
        return nomMatches || telMatches || nifMatches;
      }
      return true;
    }).toList();
  }

  Future<void> _newTiers() async {
    final created = await showNewTiersDialog(
      context,
      repository: _repository,
      defaultTypeId: _filterTypeId ?? 1,
    );

    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partenaire enregistré avec succès!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsCount = _tiersList.where((t) => t.isClient).length;
    final fournisseursCount = _tiersList.where((t) => t.isFournisseur).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Toolbar
          Container(
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
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un tiers (nom, tel, NIF)...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Filter chips
                ChoiceChip(
                  label: Text('Tous (${_tiersList.length})'),
                  selected: _filterTypeId == null,
                  onSelected: (_) => setState(() => _filterTypeId = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Clients ($clientsCount)'),
                  selected: _filterTypeId == 1,
                  onSelected: (_) => setState(() => _filterTypeId = 1),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Fournisseurs ($fournisseursCount)'),
                  selected: _filterTypeId == 2,
                  onSelected: (_) => setState(() => _filterTypeId = 2),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _newTiers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Nouveau Tiers', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
            ),

          // Table Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredTiers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Aucun partenaire trouvé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _newTiers, child: const Text('Ajouter un Tiers')),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF374151)),
                                dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Nom / Raison Sociale')),
                                  DataColumn(label: Text('Téléphone')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('RC')),
                                  DataColumn(label: Text('NIF')),
                                  DataColumn(label: Text('AI')),
                                  DataColumn(label: Text('Adresse')),
                                ],
                                rows: _filteredTiers.map((t) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: t.isClient ? Colors.blue.shade50 : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            t.isClient ? 'Client' : 'Fournisseur',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: t.isClient ? Colors.blue.shade700 : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(t.nom, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(t.telephone ?? '—')),
                                      DataCell(Text(t.email ?? '—')),
                                      DataCell(Text(t.rc ?? '—')),
                                      DataCell(Text(t.nif ?? '—')),
                                      DataCell(Text(t.ai ?? '—')),
                                      DataCell(Text(t.adresse ?? '—', overflow: TextOverflow.ellipsis)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
