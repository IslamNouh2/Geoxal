import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/security/session.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/datasources/finance_datasource.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/models/movement.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../controllers/accounting_controller.dart';
import '../widgets/demandes_transfert_dialog.dart';
import '../widgets/journal_suppression_dialog.dart';
import '../widgets/new_movement_dialog.dart';
import '../widgets/select_caisse_dialog.dart';
import '../widgets/tresorerie_statistiques_dialog.dart';

class AccountingPage extends StatefulWidget {
  const AccountingPage({super.key});

  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage> {
  late final AccountingController _controller;

  List<Compte> _accounts = const [];
  List<Movement> _movements = const [];
  FinanceStats _stats = FinanceStats.zero;
  Set<String> _accountIdsWithMovements = {};

  Compte? _activeCaisse;
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loading = true;
  String? _error;
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();

    _controller = AccountingController(
      FinanceRepository(
        FinanceDataSource(Database.instance),
      ),
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canViewOld = Session.user?.hasViewOldSoldePermission ?? true;
    _fromDate = canViewOld ? DateTime(now.year, now.month, 1) : today;
    _toDate = today;

    _init();

    // Realtime synchronization: Poll every 4 seconds to sync movements from other postes
    _realtimeTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !_loading && _activeCaisse != null) {
        _silentReloadMovements();
      }
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentReloadMovements() async {
    if (_activeCaisse == null) return;
    try {
      final movements = await _controller.loadMovements(
        accountId: _activeCaisse!.id,
        from: _fromDate,
        to: _toDate,
      );
      final stats = await _controller.loadStats(
        accountId: _activeCaisse!.id,
        from: _fromDate,
        to: _toDate,
      );
      if (!mounted) return;
      // Only trigger setState if data actually changed
      if (movements.length != _movements.length || stats.soldeFinal != _stats.soldeFinal) {
        setState(() {
          _movements = movements;
          _stats = stats;
        });
      }
    } catch (_) {
      // Keep silent during background poll
    }
  }

  // ============================================================
  // GETTERS
  // ============================================================

 
  List<Compte> get _leafCaisseBanqueAccounts {
    final user = Session.user;
    return _accounts.where((account) {
      // Only leaf accounts without children can hold balances/movements
      if (!account.isLeaf || !account.active) return false;

      // Access control check: user must have access to this caisse
      if (user != null && !user.canAccessCaisse(account.id)) {
        return false;
      }

      // NSM check: belongs to Caisse or Banque hierarchy
      final effectiveType = account.resolveEffectiveType(_accounts);
      return effectiveType == CompteType.caisse || effectiveType == CompteType.banque;
    }).toList()
      ..sort((a, b) => a.bg.compareTo(b.bg));
  }

  List<Compte> get _allLeafCaisseBanqueAccounts {
    return _accounts.where((account) {
      if (!account.isLeaf || !account.active) return false;
      final effectiveType = account.resolveEffectiveType(_accounts);
      return effectiveType == CompteType.caisse || effectiveType == CompteType.banque;
    }).toList()
      ..sort((a, b) => a.bg.compareTo(b.bg));
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final accounts = await _controller.loadAccounts();
      final idsWithMovements = await _controller.loadAccountIdsWithMovements();
      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _accountIdsWithMovements = idsWithMovements;
      });

      // Show stats dashboard by default when no active caisse is selected yet
      if (_activeCaisse != null) {
        await _loadMovements();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible d\'initialiser la trésorerie: $e';
      });
    }
  }

  Future<void> _promptSelectCaisse() async {
    final caisses = _leafCaisseBanqueAccounts;
    final selection = await showSelectCaisseDialog(
      context,
      caisseAccounts: caisses,
      initialCaisse: _activeCaisse,
      initialFrom: _fromDate,
      initialTo: _toDate,
    );

    if (selection != null && mounted) {
      setState(() {
        _activeCaisse = selection.caisse;
        _fromDate = selection.fromDate;
        _toDate = selection.toDate;
      });
      await _loadMovements();
    } else if (_activeCaisse == null) {
      // If user cancelled and no caisse was selected, stop loading
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMovements() async {
    if (_activeCaisse == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final movements = await _controller.loadMovements(
        accountId: _activeCaisse!.id,
        from: _fromDate,
        to: _toDate,
      );

      final stats = await _controller.loadStats(
        accountId: _activeCaisse!.id,
        from: _fromDate,
        to: _toDate,
      );

      if (!mounted) return;
      setState(() {
        _movements = movements;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les mouvements: $e';
      });
    }
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _newMovement() async {
    if (_activeCaisse == null) {
      await _promptSelectCaisse();
      if (_activeCaisse == null) return;
    }

    final saved = await showNewMovementDialog(
      context,
      activeCaisse: _activeCaisse!,
      allAccounts: _accounts,
      accountIdsWithMovements: _accountIdsWithMovements,
      onSave: (
        date,
        compteSourceId,
        compteDestId,
        montant,
        designation, {
        fees,
        modePaiement,
        numCheque,
        dateCheque,
        tauxChange,
        montantDevise,
      }) async {
        await _controller.createMovement(
          date: date,
          compteSourceId: compteSourceId,
          compteDestId: compteDestId,
          montant: montant,
          designation: designation,
          userId: Session.user?.id,
          modePaiement: modePaiement,
          numCheque: numCheque,
          dateCheque: dateCheque,
          tauxChange: tauxChange,
          montantDevise: montantDevise,
        );

        // Si des frais bancaires / TVA s'appliquent, créer automatiquement les écritures de charge
        if (fees != null && fees.isNotEmpty) {
          // Identifier le compte bancaire impliqué (source ou dest)
          final isBankDest = _accounts.any((a) => a.id == compteDestId && (a.typeCompte == CompteType.banque || a.code.startsWith('51')));
          final bankId = isBankDest ? compteDestId : compteSourceId;

          for (final fee in fees) {
            if (fee.computedAmount > 0) {
              await _controller.createMovement(
                date: date,
                compteSourceId: bankId,
                compteDestId: fee.chargeCompteId,
                montant: fee.computedAmount,
                designation: 'Frais / Taxe bancaire : ${fee.ruleName ?? "Commission"}',
                userId: Session.user?.id,
              );
            }
          }
        }
      },
      onCreateAccount: (Session.user?.hasManageComptesPermission ?? true)
          +? (code, libelle, parentId, typeCompte, {isDevise = false, codeDevise}) async {
              final parent = parentId == null
                  ? null
                  : _accounts.firstWhere((a) => a.id == parentId, orElse: () => _accounts.first);
              await _controller.createAccount(
                code: code,
                libelle: libelle,
                compteFr: libelle,
                parentCompte: parentId == null ? null : parent,
                userId: Session.user?.id,
                typeCompte: typeCompte,
                isDevise: isDevise,
                codeDevise: codeDevise,
              );
              final updated = await _controller.loadAccounts();
              final updatedIds = await _controller.loadAccountIdsWithMovements();
              if (mounted) setState(() { _accounts = updated; _accountIdsWithMovements = updatedIds; });
            }
          : null,
    );

    if (!saved || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mouvement de trésorerie enregistré avec succès.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );

    await _loadMovements();
  }

  Future<void> _editMovement(Movement movement) async {
    final dateCtrl = TextEditingController(
      text: '${movement.date.year.toString().padLeft(4,'0')}-'
            '${movement.date.month.toString().padLeft(2,'0')}-'
            '${movement.date.day.toString().padLeft(2,'0')}',
    );
    final amountCtrl = TextEditingController(text: movement.montant.toStringAsFixed(2));
    final desCtrl = TextEditingController(text: movement.designation);
    DateTime selectedDate = movement.date;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('Modifier le mouvement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateCtrl,
                    readOnly: true,
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx, initialDate: selectedDate,
                        firstDate: DateTime(2020), lastDate: DateTime(2035),
                      );
                      if (p != null) {
                        setS(() {
                          selectedDate = p;
                          dateCtrl.text = '${p.year.toString().padLeft(4,'0')}-'
                                          '${p.month.toString().padLeft(2,'0')}-'
                                          '${p.day.toString().padLeft(2,'0')}';
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Date',
                      suffixIcon: const Icon(Icons.calendar_today, size: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Montant (DZD)',
                      prefixText: 'DA ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (n == null || n <= 0) return 'Montant invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: desCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Désignation',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _controller.updateMovement(
        movement.id,
        date: selectedDate,
        montant: double.parse(amountCtrl.text.trim().replaceAll(',', '.')),
        designation: desCtrl.text.trim(),
      );
      await _loadMovements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mouvement modifié.'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteMovement(Movement movement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text('Supprimer ce mouvement ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(movement.designation.isEmpty ? '(Sans désignation)' : movement.designation,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Montant: ${movement.montant.toStringAsFixed(2)} DA',
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            const Text('Cette action est irréversible.',
                style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _controller.deleteMovement(movement.id, userId: Session.user?.id);
      await _loadMovements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mouvement supprimé.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_activeCaisse == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildNoCaisseSelectedView(),
      );
    }

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

  // ============================================================
  // TOOLBAR / SESSION BANNER
  // ============================================================

  Widget _buildToolbar() {
    final isBanque = _activeCaisse != null &&
        (_activeCaisse!.typeCompte == CompteType.banque || _activeCaisse!.libelle.toLowerCase().contains('banque'));

    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (_activeCaisse != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isBanque ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isBanque ? Icons.account_balance_rounded : Icons.payments_rounded,
                size: 22,
                color: isBanque ? const Color(0xFF2563EB) : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _activeCaisse!.displayName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBanque ? const Color(0xFFDBEAFE) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBanque ? 'Banque' : 'Caisse',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isBanque ? const Color(0xFF1D4ED8) : const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (_fromDate != null && _toDate != null)
                  Text(
                    'Période: ${formatDate(_fromDate!)} au ${formatDate(_toDate!)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            OutlinedButton.icon(
              onPressed: _promptSelectCaisse,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Changer', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ] else ...[
            const Icon(Icons.account_balance_wallet_outlined, size: 22, color: Color(0xFF6B7280)),
            const SizedBox(width: 10),
            const Text(
              'Aucune caisse sélectionnée',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _promptSelectCaisse,
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('Ouvrir une Caisse'),
            ),
          ],
          const Spacer(),
          Tooltip(
            message: 'Actualiser',
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.coolSteel,
              onPressed: _loading ? null : _loadMovements,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _activeCaisse = null;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D9488),
              side: const BorderSide(color: Color(0xFF99F6E4)),
              backgroundColor: const Color(0xFFF0FDFA),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.dashboard_rounded, size: 17, color: Color(0xFF0D9488)),
            label: const Text(
              'Tableau de Bord / Stats',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await DemandesTransfertDialog.show(
                context,
                controller: _controller,
                allCaisseBanqueAccounts: _allLeafCaisseBanqueAccounts,
                activeCaisse: _activeCaisse,
              );
              if (mounted) _loadMovements();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: const Color(0xFFEFF6FF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 17, color: Color(0xFF2563EB)),
            label: const Text(
              'Demandes Transfert',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (Session.user?.hasViewJournalSupprPermission ?? false) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => JournalSuppressionDialog.show(
                context,
                controller: _controller,
                caisses: _leafCaisseBanqueAccounts,
                initialCaisseId: _activeCaisse?.id,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                backgroundColor: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.auto_delete_outlined, size: 17, color: Color(0xFFDC2626)),
              label: const Text(
                'Journal Suppr.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(width: 12),
          if (Session.user?.hasCreateMovPermission ?? true)
            ElevatedButton.icon(
              onPressed: (_loading || _activeCaisse == null) ? null : _newMovement,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Nouveau Mouvement',
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
          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.deepSpaceBlue))),
          TextButton(onPressed: _loadMovements, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  Widget _buildNoCaisseSelectedView() {
    return TresorerieStatistiquesDialog(
      controller: _controller,
      allAccounts: _accounts,
      userCaisses: _leafCaisseBanqueAccounts,
      initialCaisse: _activeCaisse,
      isEmbedded: true,
      onOpenCaisse: (caisse) async {
        setState(() {
          _activeCaisse = caisse;
        });
        await _loadMovements();
      },
      onOpenTresorerie: _promptSelectCaisse,
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatCards() {
    final canViewOld = Session.user?.hasViewOldSoldePermission ?? true;

    // Show in devise ONLY if the caisse itself is a devise account.
    // A DZD caisse that sends to a devise caisse still shows amounts in DZD.
    final isDevise = _activeCaisse?.isDevise == true;
    final currCode = _activeCaisse?.codeDevise ?? 'DEV';

    String fmtDev(double v) => '${v.toStringAsFixed(2)} $currCode';

    return Row(
      children: [
        // Solde Initial (Cumul avant la période) - Conditionné par permission
        if (canViewOld) ...[
          Expanded(
            child: _statCard(
              title: isDevise ? 'Solde Initial ($currCode)' : 'Solde Initial (Report)',
              value: isDevise
                  ? '${_stats.deviseInitial.toStringAsFixed(2)} $currCode'
                  : formatMoney(_stats.soldeInitial),
              sub: isDevise ? '${formatMoney(_stats.soldeInitial)} DZD' : null,
              icon: Icons.history_toggle_off_rounded,
              iconColor: const Color(0xFF6366F1),
              valueColor: _stats.soldeInitial >= 0 ? const Color(0xFF4338CA) : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 14),
        ],

        // Entrées de la période
        Expanded(
          child: _statCard(
            title: isDevise ? 'Entrées ($currCode)' : 'Entrées (Période)',
            value: isDevise ? '+${fmtDev(_stats.deviseEntrees)}' : '+${formatMoney(_stats.totalEntrees)}',
            sub: isDevise ? '≈ ${formatMoney(_stats.totalEntrees)} DZD' : null,
            icon: Icons.arrow_downward_rounded,
            iconColor: const Color(0xFF10B981),
            valueColor: const Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 14),

        // Sorties de la période
        Expanded(
          child: _statCard(
            title: isDevise ? 'Sorties ($currCode)' : 'Sorties (Période)',
            value: isDevise ? '-${fmtDev(_stats.deviseSorties)}' : '-${formatMoney(_stats.totalSorties)}',
            sub: isDevise ? '≈ ${formatMoney(_stats.totalSorties)} DZD' : null,
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFFEF4444),
            valueColor: const Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 14),

        // Solde Final
        Expanded(
          child: _statCard(
            title: isDevise ? 'Solde Final ($currCode)' : 'Solde Final (Clôture)',
            value: isDevise
                ? '${_stats.deviseSoldeFinal.toStringAsFixed(2)} $currCode'
                : formatMoney(_stats.soldeFinal),
            sub: isDevise ? '≈ ${formatMoney(_stats.soldeFinal)} DZD' : null,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: _stats.soldeFinal >= 0 ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
            valueColor: _stats.soldeFinal >= 0 ? const Color(0xFF1D4ED8) : const Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 14),

        // Nombre de mouvements
        Expanded(
          child: _statCard(
            title: 'Opérations',
            value: '${_stats.countMovements}',
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF8B5CF6),
            valueColor: const Color(0xFF1F2937),
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
    required Color valueColor,
    String? sub,
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
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // MOVEMENTS TABLE
  // ============================================================

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
          : _movements.isEmpty
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
                      columns: [
                        const DataColumn(label: Text('Date')),
                        const DataColumn(label: Text('Sens')),
                        const DataColumn(label: Text('Compte Source (Sortant)')),
                        const DataColumn(label: Text('Compte Dest. (Entrant)')),
                        const DataColumn(label: Text('Désignation')),
                        DataColumn(
                          numeric: true,
                          label: Text(
                            (_activeCaisse?.isDevise == true)
                                ? 'Montant (${_activeCaisse?.codeDevise ?? 'DEV'} / DZD)'
                                : 'Montant (DA)',
                          ),
                        ),
                        if (_activeCaisse?.isDevise == true && _movements.any((m) => m.montantDevise != null))
                          const DataColumn(
                            numeric: true,
                            label: Text('Taux de Change'),
                          ),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: _movements.map((movement) {
                        final isSortie = movement.compteSourceId == _activeCaisse!.id;

                        return DataRow(
                          cells: [
                            DataCell(Text(formatDate(movement.date))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSortie ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSortie ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 13,
                                      color: isSortie ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSortie ? 'Sortie' : 'Entrée',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSortie ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 4),
                                  Text(movement.sourceDisplayName),
                                ],
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(movement.destDisplayName),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(movement.designation.isEmpty ? '—' : movement.designation,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            DataCell(
                              Builder(builder: (context) {
                                // Show devise amount ONLY when viewing a devise caisse.
                                // DZD caisses always show in DZD, even if movement has montantDevise.
                                final caisseIsDevise = _activeCaisse?.isDevise == true;
                                final currCode = _activeCaisse?.codeDevise ?? 'DEV';
                                final hasDevise = caisseIsDevise && movement.montantDevise != null;
                                final devAmt = movement.montantDevise ?? movement.montant;
                                final displayLabel = hasDevise
                                    ? '${isSortie ? '-' : '+'}${devAmt.toStringAsFixed(2)} $currCode'
                                    : '${isSortie ? '-' : '+'}${formatMoney(movement.montant)}';
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      displayLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isSortie ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      ),
                                    ),
                                    if (hasDevise)
                                      Text(
                                        '≈ ${formatMoney(movement.montant)} DZD',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                                      ),
                                  ],
                                );
                              }),
                            ),
                            // Taux de Change cell — only when viewing a devise caisse
                            if (_activeCaisse?.isDevise == true && _movements.any((m) => m.montantDevise != null))
                              DataCell(
                                movement.tauxChange != null
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${movement.tauxChange!.toStringAsFixed(2)} DZD',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                            Text(
                                              '1 ${_activeCaisse?.codeDevise ?? 'DEV'} = X',
                                              style: const TextStyle(fontSize: 9, color: Color(0xFF93C5FD)),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const Text('—', style: TextStyle(color: Color(0xFF9CA3AF))),
                              ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (Session.user?.hasUpdateMovPermission ?? true)
                                    Tooltip(
                                      message: 'Modifier',
                                      child: IconButton(
                                        icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF2563EB)),
                                        onPressed: () => _editMovement(movement),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  if (Session.user?.hasDeleteMovPermission ?? true)
                                    Tooltip(
                                      message: 'Supprimer',
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                        onPressed: () => _deleteMovement(movement),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  if (!(Session.user?.hasUpdateMovPermission ?? true) &&
                                      !(Session.user?.hasDeleteMovPermission ?? true))
                                    const Text('—', style: TextStyle(color: Color(0xFF9CA3AF))),
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
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Aucun mouvement pour cette période',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 4),
            Text(
              'Aucune opération enregistrée pour ${_activeCaisse?.displayName ?? 'cette caisse'}.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _newMovement,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau Mouvement'),
            ),
          ],
        ),
      ),
    );
  }
}