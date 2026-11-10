import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../data/datasources/departement_datasource.dart';
import '../../../../data/models/departement.dart';
import '../../../../data/repositories/departement_repository.dart';

class DepartementsPage extends StatefulWidget {
  const DepartementsPage({super.key});

  @override
  State<DepartementsPage> createState() => _DepartementsPageState();
}

class _DepartementsPageState extends State<DepartementsPage> {
  late final DepartementRepository _repository;
  List<Departement> _departements = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = DepartementRepository(DepartementDataSource(Database.instance));
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
      final list = await _repository.getDepartements();
      if (!mounted) return;
      setState(() {
        _departements = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erreur lors du chargement des départements: $e';
      });
    }
  }

  Future<void> _openCreateOrEditDialog([Departement? departement]) async {
    final codeCtrl = TextEditingController(text: departement?.code ?? '');
    final nomCtrl = TextEditingController(text: departement?.nom ?? '');
    final descCtrl = TextEditingController(text: departement?.description ?? '');
    bool isActive = departement?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                departement == null ? 'Nouveau Département' : 'Modifier le Département',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Code Département *',
                      hintText: 'ex: DEP-VENTES, DEP-RH, DEP-INFO',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Le code est requis' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nomCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nom du Département *',
                      hintText: 'ex: Département Ventes & Marketing',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description (facultatif)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    title: const Text('Actif', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Disponible dans les sélections de factures et règlements', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: isActive,
                    activeThumbColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setS(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  if (departement == null) {
                    await _repository.createDepartement(
                      code: codeCtrl.text.trim(),
                      nom: nomCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      isActive: isActive,
                    );
                  } else {
                    await _repository.updateDepartement(
                      id: departement.id,
                      code: codeCtrl.text.trim(),
                      nom: nomCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      isActive: isActive,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(departement == null ? 'Créer' : 'Mettre à jour'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      _load();
    }
  }

  Future<void> _deleteDepartement(Departement dep) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce département ?'),
        content: Text('Voulez-vous vraiment supprimer "${dep.nom}" (${dep.code}) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteDepartement(dep.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Département supprimé.'), backgroundColor: Colors.green),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _departements.where((d) {
      if (query.isEmpty) return true;
      return d.code.toLowerCase().contains(query) || d.nom.toLowerCase().contains(query);
    }).toList();

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
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher département...',
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
                Tooltip(
                  message: 'Actualiser',
                  child: IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    color: AppColors.coolSteel,
                    onPressed: _loading ? null : _load,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openCreateOrEditDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouveau Département', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 13))),
                ],
              ),
            ),

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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.apartment_rounded, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Aucun département trouvé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: () => _openCreateOrEditDialog(), child: const Text('Créer un Département')),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF374151)),
                              dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                              columns: const [
                                DataColumn(label: Text('Code')),
                                DataColumn(label: Text('Nom')),
                                DataColumn(label: Text('Description')),
                                DataColumn(label: Text('Statut')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: filtered.map((d) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(d.code, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                                    ),
                                    DataCell(Text(d.nom, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(Text(d.description ?? '—')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: d.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          d.isActive ? 'Actif' : 'Inactif',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: d.isActive ? Colors.green.shade700 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                            onPressed: () => _openCreateOrEditDialog(d),
                                            tooltip: 'Modifier',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () => _deleteDepartement(d),
                                            tooltip: 'Supprimer',
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
    );
  }
}

