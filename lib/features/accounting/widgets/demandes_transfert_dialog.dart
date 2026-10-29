import 'package:flutter/material.dart';

import '../../../../core/security/session.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/models/demande_transfert.dart';
import '../controllers/accounting_controller.dart';

class DemandesTransfertDialog extends StatefulWidget {
  final AccountingController controller;
  final List<Compte> allCaisseBanqueAccounts;
  final Compte? activeCaisse;

  const DemandesTransfertDialog({
    super.key,
    required this.controller,
    required this.allCaisseBanqueAccounts,
    this.activeCaisse,
  });

  static Future<void> show(
    BuildContext context, {
    required AccountingController controller,
    required List<Compte> allCaisseBanqueAccounts,
    Compte? activeCaisse,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DemandesTransfertDialog(
        controller: controller,
        allCaisseBanqueAccounts: allCaisseBanqueAccounts,
        activeCaisse: activeCaisse,
      ),
    );
  }

  @override
  State<DemandesTransfertDialog> createState() => _DemandesTransfertDialogState();
}

class _DemandesTransfertDialogState extends State<DemandesTransfertDialog> {
  List<DemandeTransfert> _demandes = [];
  bool _loading = true;
  String? _error;
  String _selectedStatut = 'TOUS';
  String? _selectedCaisseId;

  @override
  void initState() {
    super.initState();
    _selectedCaisseId = widget.activeCaisse?.id;
    _loadDemandes();
  }

  Future<void> _loadDemandes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.controller.loadDemandesTransfert(
        caisseId: _selectedCaisseId,
        statut: _selectedStatut == 'TOUS' ? null : _selectedStatut,
      );
      if (mounted) {
        setState(() {
          _demandes = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger les demandes: $e';
        });
      }
    }
  }

  bool _canValidateDemande(DemandeTransfert d) {
    final user = Session.user;
    if (user == null) return false;
    if (user.isAdmin) return true;
    // Check if user has explicit permission to validate/refuse transfer requests
    if (!user.hasValidateTransfertPermission) return false;
    // Standard user also needs caisse access to either source or destination caisse
    return user.canAccessCaisse(d.compteDestId) || user.canAccessCaisse(d.compteSourceId);
  }

  Future<void> _openNewDemandeDialog() async {
    final user = Session.user;
    if (user == null) return;

    Compte? selectedSource = widget.activeCaisse ??
        (widget.allCaisseBanqueAccounts.isNotEmpty ? widget.allCaisseBanqueAccounts.first : null);
    Compte? selectedDest = widget.allCaisseBanqueAccounts.length > 1
        ? widget.allCaisseBanqueAccounts.firstWhere(
            (c) => c.id != selectedSource?.id,
            orElse: () => widget.allCaisseBanqueAccounts.last,
          )
        : null;

    final montantCtrl = TextEditingController();
    final motifCtrl = TextEditingController();
    DateTime dateDemande = DateTime.now();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Nouvelle Demande de Transfert',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caisse source
                    DropdownButtonFormField<String>(
                      value: selectedSource?.id,
                      decoration: InputDecoration(
                        labelText: 'Caisse / Banque Source (Débiteur) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        for (final c in widget.allCaisseBanqueAccounts)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(c.displayName, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (id) {
                        setS(() {
                          selectedSource = widget.allCaisseBanqueAccounts.firstWhere((c) => c.id == id);
                          if (selectedDest?.id == selectedSource?.id) {
                            selectedDest = null;
                          }
                        });
                      },
                      validator: (v) => v == null ? 'Veuillez choisir la caisse source' : null,
                    ),
                    const SizedBox(height: 14),

                    // Caisse destination
                    DropdownButtonFormField<String>(
                      value: selectedDest?.id,
                      decoration: InputDecoration(
                        labelText: 'Caisse / Banque Destination (Créditeur) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        for (final c in widget.allCaisseBanqueAccounts)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(c.displayName, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (id) {
                        setS(() {
                          selectedDest = widget.allCaisseBanqueAccounts.firstWhere((c) => c.id == id);
                        });
                      },
                      validator: (v) {
                        if (v == null) return 'Veuillez choisir la caisse destinataire';
                        if (v == selectedSource?.id) {
                          return 'La source et la destination doivent être différentes';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Montant
                    TextFormField(
                      controller: montantCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Montant du transfert (DZD) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Montant obligatoire';
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0) return 'Montant invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Motif / Désignation
                    TextFormField(
                      controller: motifCtrl,
                      decoration: InputDecoration(
                        labelText: 'Motif / Désignation de la demande *',
                        hintText: 'Ex: Alimentation caisse chantier, Virement agence...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Motif obligatoire' : null,
                    ),
                  ],
                ),
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
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Soumettre la demande'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      try {
        final montant = double.parse(montantCtrl.text.trim());
        await widget.controller.createDemandeTransfert(
          dateDemande: dateDemande,
          userDemandeurId: user.id,
          compteSourceId: selectedSource!.id,
          compteDestId: selectedDest!.id,
          montant: montant,
          designation: motifCtrl.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande de transfert enregistrée avec succès.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _loadDemandes();
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

  Future<void> _validerDemande(DemandeTransfert d) async {
    final user = Session.user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('Valider le transfert ?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Voulez-vous valider le transfert de ${formatMoney(d.montant)} '
          'depuis [${d.sourceDisplayName}] vers [${d.destDisplayName}] ?\n\n'
          'Un mouvement de trésorerie officiel sera automatiquement généré.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer & Valider'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.controller.validerDemandeTransfert(d.id, valideurUserId: user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande validée et mouvement de trésorerie créé.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _loadDemandes();
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

  Future<void> _refuserDemande(DemandeTransfert d) async {
    final user = Session.user;
    if (user == null) return;

    final motifCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Refuser la demande ?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Indiquez le motif du refus pour le transfert de ${formatMoney(d.montant)} :',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: motifCtrl,
                decoration: InputDecoration(
                  labelText: 'Motif du refus *',
                  hintText: 'Ex: Solde insuffisant, Non autorisé...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Veuillez saisir un motif' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer le refus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.controller.refuserDemandeTransfert(
          d.id,
          valideurUserId: user.id,
          motif: motifCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande de transfert refusée.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
          _loadDemandes();
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demandes de Transfert de Trésorerie',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937)),
                      ),
                      Text(
                        'Consultez, soumettez ou validez les virements entre caisses et banques',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _openNewDemandeDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nouvelle Demande', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Filter row
              Row(
                children: [
                  // Caisse filter
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedCaisseId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Filtrer par Caisse / Banque',
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Toutes les Caisses / Banques'),
                        ),
                        for (final c in widget.allCaisseBanqueAccounts)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(c.displayName, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (id) {
                        setState(() => _selectedCaisseId = id);
                        _loadDemandes();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Statut chips
                  Wrap(
                    spacing: 8,
                    children: [
                      _statutChip('TOUS', 'Tous'),
                      _statutChip('EN_ATTENTE', 'En Attente', const Color(0xFFF59E0B)),
                      _statutChip('VALIDEE', 'Validées', const Color(0xFF10B981)),
                      _statutChip('REFUSEE', 'Refusées', const Color(0xFFDC2626)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadDemandes,
                    icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF6B7280)),
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Error or Content
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _demandes.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucune demande de transfert trouvée.',
                              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                            ),
                          )
                        : _buildTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statutChip(String value, String label, [Color? color]) {
    final isSelected = _selectedStatut == value;
    final activeColor = color ?? const Color(0xFF2563EB);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF4B5563),
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: const Color(0xFFF3F4F6),
      onSelected: (sel) {
        if (sel) {
          setState(() => _selectedStatut = value);
          _loadDemandes();
        }
      },
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Demandeur', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Source', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Destination', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Montant', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Motif / Statut', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
            rows: [
              for (final d in _demandes)
                DataRow(
                  cells: [
                    DataCell(Text(formatDateTime(d.dateDemande), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(d.demandeurUsername ?? 'Utilisateur', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(Text(d.sourceDisplayName, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(d.destDisplayName, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(
                      formatMoney(d.montant),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                    )),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatutBadge(d.statut),
                          if (d.designation.isNotEmpty)
                            Text(d.designation,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                overflow: TextOverflow.ellipsis),
                          if (d.isRefusee && d.motifRefus != null)
                            Text('Refus: ${d.motifRefus}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                    DataCell(
                      d.isEnAttente && _canValidateDemande(d)
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _validerDemande(d),
                                  icon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                                  tooltip: 'Valider le transfert',
                                ),
                                IconButton(
                                  onPressed: () => _refuserDemande(d),
                                  icon: const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 20),
                                  tooltip: 'Refuser le transfert',
                                ),
                              ],
                            )
                          : Text(
                              d.isValidee
                                  ? 'Par ${d.valideurUsername ?? 'Valideur'}'
                                  : (d.isRefusee ? 'Refusé' : 'En attente'),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                            ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatutBadge(String statut) {
    Color bg;
    Color fg;
    String label;
    switch (statut) {
      case 'VALIDEE':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        label = 'Validée';
        break;
      case 'REFUSEE':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'Refusée';
        break;
      case 'EN_ATTENTE':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'En Attente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
