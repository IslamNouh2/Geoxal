import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/security/session.dart';
import '../../../../data/datasources/finance_datasource.dart';
import '../../../../data/datasources/user_datasource.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/models/user.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/finance_repository.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  late final AuthRepository _authRepo;
  late final FinanceRepository _financeRepo;

  bool _loading = true;
  String? _error;
  List<User> _users = [];
  List<Compte> _caisses = [];

  @override
  void initState() {
    super.initState();
    final db = Database.instance;
    _authRepo = AuthRepository(UserDataSource(db));
    _financeRepo = FinanceRepository(FinanceDataSource(db));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await _authRepo.getAllUsers();
      final accounts = await _financeRepo.getAccounts();
      final caisses = accounts.where((a) {
        if (!a.isLeaf || !a.active) return false;
        final t = a.resolveEffectiveType(accounts);
        return t == CompteType.caisse || t == CompteType.banque;
      }).toList();

      if (mounted) {
        setState(() {
          _users = users;
          _caisses = caisses;
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

  Future<void> _openUserDialog({User? user}) async {
    final isNew = user == null;
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final passwordCtrl = TextEditingController();
    String role = user?.role.toUpperCase() == 'ADMIN' ? 'ADMIN' : 'USER';
    bool isActive = user?.isActive ?? true;
    bool canSeeAll = user?.canSeeAllCaisses ?? true;
    bool canCreateMov = user?.canCreateMov ?? true;
    bool canUpdateMov = user?.canUpdateMov ?? true;
    bool canDeleteMov = user?.canDeleteMov ?? true;
    bool canManageComptes = user?.canManageComptes ?? false;
    bool canViewJournalSuppr = user?.canViewJournalSuppr ?? false;
    bool canViewOldSolde = user?.canViewOldSolde ?? true;
    bool canViewCustomers = user?.canViewCustomers ?? true;
    bool canViewProducts = user?.canViewProducts ?? true;
    bool canViewSales = user?.canViewSales ?? true;
    bool canViewPurchases = user?.canViewPurchases ?? true;
    bool canViewStock = user?.canViewStock ?? true;
    bool canViewAccounting = user?.canViewAccounting ?? true;
    bool canValidateTransfert = user?.canValidateTransfert ?? true;
    bool canDeleteBankRules = user?.canDeleteBankRules ?? false;
    Set<String> selectedCaisses = Set.from(user?.assignedCaisseIds ?? []);

    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => DefaultTabController(
          length: 4,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                  ),
                  child: Icon(
                    isNew ? Icons.person_add_rounded : Icons.manage_accounts_rounded,
                    color: const Color(0xFF18181B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNew ? 'Nouvel Utilisateur' : 'Modifier Utilisateur : ${user.username}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF09090B), letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isNew ? 'Créer un profil et configurer ses habilitations' : 'Ajuster les permissions et accès de ce compte',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  icon: const Icon(Icons.close, color: Color(0xFF71717A), size: 20),
                ),
              ],
            ),
            content: SizedBox(
              width: 880,
              height: 530,
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    // Modern Tab Bar with Zinc Styling
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE4E4E7)),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        labelColor: const Color(0xFF09090B),
                        unselectedLabelColor: const Color(0xFF71717A),
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.badge_outlined, size: 18),
                            text: 'Général & Rôle',
                          ),
                          Tab(
                            icon: Icon(Icons.payments_outlined, size: 18),
                            text: 'Opérations & Trésorerie',
                          ),
                          Tab(
                            icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                            text: 'Caisses & Plan Comptable',
                          ),
                          Tab(
                            icon: Icon(Icons.grid_view_rounded, size: 18),
                            text: 'Modules Visibles',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        children: [
                          // ================= TAB 1: GENERAL & ROLE =================
                          SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: usernameCtrl,
                                          enabled: isNew,
                                          decoration: InputDecoration(
                                            labelText: 'Nom d\'utilisateur *',
                                            prefixIcon: const Icon(Icons.person_outline, size: 18),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: passwordCtrl,
                                          obscureText: true,
                                          decoration: InputDecoration(
                                            labelText: isNew ? 'Mot de passe *' : 'Nouveau mot de passe (laisser vide pour garder)',
                                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          ),
                                          validator: (v) {
                                            if (isNew && (v == null || v.trim().isEmpty)) return 'Requis';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: role,
                                          decoration: InputDecoration(
                                            labelText: 'Rôle Système *',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'ADMIN', child: Text('Administrateur (Tous droits et accès)')),
                                            DropdownMenuItem(value: 'USER', child: Text('Utilisateur Standard (Accès configurables)')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) {
                                              setDialogState(() {
                                                role = v;
                                                if (role == 'ADMIN') {
                                                  canSeeAll = true;
                                                  canCreateMov = true;
                                                  canUpdateMov = true;
                                                  canDeleteMov = true;
                                                  canManageComptes = true;
                                                  canViewJournalSuppr = true;
                                                  canViewOldSolde = true;
                                                  canViewCustomers = true;
                                                  canViewProducts = true;
                                                  canViewSales = true;
                                                  canViewPurchases = true;
                                                  canViewStock = true;
                                                  canViewAccounting = true;
                                                  canValidateTransfert = true;
                                                }
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      FCard(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          child: FSwitch(
                                            value: isActive,
                                            label: Text(
                                              isActive ? 'Compte Actif' : 'Compte Inactif',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                              ),
                                            ),
                                            description: const Text('Statut de connexion'),
                                            onChange: (v) => setDialogState(() => isActive = v),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  if (role == 'ADMIN')
                                    FCard(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: const [
                                                  Text(
                                                    'Rôle Administrateur Activé',
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Ce rôle confère automatiquement l\'ensemble des permissions et un accès illimité à toutes les caisses, modules et opérations.',
                                                    style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // ================= TAB 2: OPERATIONS & TRESORERIE =================
                          SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: FCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canCreateMov,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canCreateMov = v),
                                        label: const Text('Créer des mouvements (Nouveau Mouvement)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Autorise la saisie de mouvements d\'entrées et de sorties'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canUpdateMov,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canUpdateMov = v),
                                        label: const Text('Modifier des mouvements existants', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Autorise l\'édition des montants, libellés et dates'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canDeleteMov,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canDeleteMov = v),
                                        label: const Text('Supprimer des mouvements (Archivage automatique)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Les suppressions sont sauvegardées dans le journal d\'audit'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canViewJournalSuppr,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canViewJournalSuppr = v),
                                        label: const Text('Consulter le Journal des Suppressions', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Permet de voir l\'historique des mouvements supprimés et annulés'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canViewOldSolde,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canViewOldSolde = v),
                                        label: const Text('Peut voir l\'ancien solde (Solde initial / report)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Si désactivé, l\'utilisateur est strictement limité à la date du jour'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canValidateTransfert,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canValidateTransfert = v),
                                        label: const Text('Valider / Refuser les demandes de transfert', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                                        description: const Text('Permet d\'accepter ou de rejeter les demandes de transfert de trésorerie entre caisses'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canDeleteBankRules,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canDeleteBankRules = v),
                                        label: const Text('Supprimer des règles bancaires', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                                        description: const Text('Autorise la suppression définitive de règles de commissions et TVA bancaires'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ================= TAB 3: CAISSES & PLAN COMPTABLE =================
                          SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Plan Comptable Permission with FCard and FCheckbox
                                  FCard(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: FCheckbox(
                                        value: role == 'ADMIN' ? true : canManageComptes,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canManageComptes = v),
                                        label: Text(
                                          role == 'ADMIN' || canManageComptes
                                              ? 'Gestion Complète du Plan Comptable (Créer, modifier, reparenter)'
                                              : 'Mode Consultation Uniquement (Lecture seule de l\'arborescence)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: role == 'ADMIN' || canManageComptes ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                          ),
                                        ),
                                        description: Text(
                                          role == 'ADMIN' || canManageComptes
                                              ? 'L\'utilisateur peut modifier les comptes, changer leurs parents et en ajouter.'
                                              : 'L\'utilisateur peut seulement consulter le plan comptable sans pouvoir créer ou modifier de compte.',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Caisses Access Radio
                                  const Text(
                                    'Périmètre d\'accès aux caisses & banques :',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
                                  ),
                                  const SizedBox(height: 8),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: role == 'ADMIN' ? null : () => setDialogState(() => canSeeAll = true),
                                          borderRadius: BorderRadius.circular(8),
                                          child: FCard(
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: canSeeAll ? const Color(0xFFF4F4F5) : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: canSeeAll ? const Color(0xFF18181B) : Colors.transparent,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.all_inclusive_rounded, color: Color(0xFF18181B), size: 20),
                                                  SizedBox(width: 10),
                                                  Text('Accès à TOUTES les caisses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: role == 'ADMIN' ? null : () => setDialogState(() => canSeeAll = false),
                                          borderRadius: BorderRadius.circular(8),
                                          child: FCard(
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: !canSeeAll ? const Color(0xFFF4F4F5) : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: !canSeeAll ? const Color(0xFF18181B) : Colors.transparent,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.tune_rounded, color: Color(0xFF18181B), size: 20),
                                                  SizedBox(width: 10),
                                                  Text('Caisses spécifiques assignées', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (!canSeeAll && role != 'ADMIN') ...[
                                    const SizedBox(height: 12),
                                    FCard(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: _caisses.isEmpty
                                            ? const Text('Aucune caisse disponible.', style: TextStyle(fontSize: 12))
                                            : Wrap(
                                                spacing: 10,
                                                runSpacing: 8,
                                                children: _caisses.map((caisse) {
                                                  final isChecked = selectedCaisses.contains(caisse.id);
                                                  return FilterChip(
                                                    selected: isChecked,
                                                    label: Text('${caisse.code} - ${caisse.libelle}', style: const TextStyle(fontSize: 12)),
                                                    selectedColor: const Color(0xFFE4E4E7),
                                                    checkmarkColor: const Color(0xFF18181B),
                                                    onSelected: (val) {
                                                      setDialogState(() {
                                                        if (val) {
                                                          selectedCaisses.add(caisse.id);
                                                        } else {
                                                          selectedCaisses.remove(caisse.id);
                                                        }
                                                      });
                                                    },
                                                  );
                                                }).toList(),
                                              ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // ================= TAB 4: VISIBILITE DES MODULES =================
                          SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: FCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canViewCustomers,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canViewCustomers = v),
                                        label: const Text('Clients (Customers)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Afficher la section Clients dans le menu latéral'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canViewProducts,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canViewProducts = v),
                                        label: const Text('Produits & Articles (Products)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Afficher la section Produits dans le menu latéral'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canViewSales,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canViewSales = v),
                                        label: const Text('Ventes & Facturation (Sales)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Afficher la section Ventes dans le menu latéral'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canViewPurchases,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canViewPurchases = v),
                                        label: const Text('Achats & Fournisseurs (Purchases)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Afficher la section Achats dans le menu latéral'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canViewStock,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canViewStock = v),
                                        label: const Text('Stock & Entrepôt (Stock)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Afficher la section Stock dans le menu latéral'),
                                      ),
                                      const SizedBox(height: 12),
                                      const FDivider(),
                                      const SizedBox(height: 12),
                                      FCheckbox(
                                        value: role == 'ADMIN' ? true : canViewAccounting,
                                        enabled: role != 'ADMIN',
                                        onChange: (v) => setDialogState(() => canViewAccounting = v),
                                        label: const Text('Finance & Trésorerie (Accounting / Comptes)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        description: const Text('Afficher la Trésorerie et le Plan Comptable dans le menu latéral'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              FButton(
                onPress: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              FButton(
                onPress: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(ctx, true);
                  }
                },
                prefix: const Icon(Icons.check, size: 16),
                child: Text(
                  isNew ? 'Créer l\'utilisateur' : 'Enregistrer les modifications',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;

    try {
      if (isNew) {
        await _authRepo.createUser(
          username: usernameCtrl.text.trim(),
          password: passwordCtrl.text.trim(),
          role: role,
          canSeeAllCaisses: role == 'ADMIN' ? true : canSeeAll,
          canCreateMov: role == 'ADMIN' ? true : canCreateMov,
          canUpdateMov: role == 'ADMIN' ? true : canUpdateMov,
          canDeleteMov: role == 'ADMIN' ? true : canDeleteMov,
          canManageComptes: role == 'ADMIN' ? true : canManageComptes,
          canViewJournalSuppr: role == 'ADMIN' ? true : canViewJournalSuppr,
          canViewOldSolde: role == 'ADMIN' ? true : canViewOldSolde,
          canViewCustomers: role == 'ADMIN' ? true : canViewCustomers,
          canViewProducts: role == 'ADMIN' ? true : canViewProducts,
          canViewSales: role == 'ADMIN' ? true : canViewSales,
          canViewPurchases: role == 'ADMIN' ? true : canViewPurchases,
          canViewStock: role == 'ADMIN' ? true : canViewStock,
          canViewAccounting: role == 'ADMIN' ? true : canViewAccounting,
          canValidateTransfert: role == 'ADMIN' ? true : canValidateTransfert,
          canDeleteBankRules: role == 'ADMIN' ? true : canDeleteBankRules,
          assignedCaisseIds: selectedCaisses.toList(),
        );
      } else {
        await _authRepo.updateUser(
          user.id,
          role: role,
          isActive: isActive,
          canSeeAllCaisses: role == 'ADMIN' ? true : canSeeAll,
          canCreateMov: role == 'ADMIN' ? true : canCreateMov,
          canUpdateMov: role == 'ADMIN' ? true : canUpdateMov,
          canDeleteMov: role == 'ADMIN' ? true : canDeleteMov,
          canManageComptes: role == 'ADMIN' ? true : canManageComptes,
          canViewJournalSuppr: role == 'ADMIN' ? true : canViewJournalSuppr,
          canViewOldSolde: role == 'ADMIN' ? true : canViewOldSolde,
          canViewCustomers: role == 'ADMIN' ? true : canViewCustomers,
          canViewProducts: role == 'ADMIN' ? true : canViewProducts,
          canViewSales: role == 'ADMIN' ? true : canViewSales,
          canViewPurchases: role == 'ADMIN' ? true : canViewPurchases,
          canViewStock: role == 'ADMIN' ? true : canViewStock,
          canViewAccounting: role == 'ADMIN' ? true : canViewAccounting,
          canValidateTransfert: role == 'ADMIN' ? true : canValidateTransfert,
          canDeleteBankRules: role == 'ADMIN' ? true : canDeleteBankRules,
          assignedCaisseIds: selectedCaisses.toList(),
          newPassword: passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
        );
      }

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNew ? 'Utilisateur créé avec succès.' : 'Utilisateur mis à jour.'),
            backgroundColor: const Color(0xFF10B981),
          ),
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

  Future<void> _deleteUser(User user) async {
    if (user.id == Session.user?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez pas supprimer votre propre compte session.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Supprimer cet utilisateur ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text('Êtes-vous sûr de vouloir supprimer définitivement l\'utilisateur "${user.username}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _authRepo.deleteUser(user.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur supprimé.'), backgroundColor: Color(0xFFEF4444)),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = Session.user;
    if (currentUser != null && !currentUser.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_person_rounded, size: 54, color: Color(0xFFEF4444)),
              SizedBox(height: 14),
              Text(
                'Accès Refusé',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              ),
              SizedBox(height: 6),
              Text(
                'Seuls les administrateurs ont l\'autorisation de gérer les utilisateurs et leurs accès.',
                style: TextStyle(color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildToolbar(),
          if (_error != null) _buildErrorBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('Aucun utilisateur trouvé.'))
                    : _buildUsersTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.manage_accounts_rounded, size: 22, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion des Utilisateurs & Droits d\'Accès',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              ),
              SizedBox(height: 2),
              Text(
                'Distinction Mouvements (CRUD) vs Plan Comptable (Consultation seule ou Gestion)',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const Spacer(),
          Tooltip(
            message: 'Actualiser',
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.coolSteel,
              onPressed: _loading ? null : _loadData,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _openUserDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Nouvel Utilisateur', style: TextStyle(fontWeight: FontWeight.w600)),
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
          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.deepSpaceBlue))),
          TextButton(onPressed: _loadData, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  Widget _buildUsersTable() {
    return SingleChildScrollView(
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
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
          headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
          dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          columnSpacing: 22,
          columns: const [
            DataColumn(label: Text('Utilisateur')),
            DataColumn(label: Text('Rôle')),
            DataColumn(label: Text('Statut')),
            DataColumn(label: Text('Mouvements (C/U/D)')),
            DataColumn(label: Text('Plan Comptable')),
            DataColumn(label: Text('Accès Caisses')),
            DataColumn(label: Text('Sections Visibles')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _users.map((u) {
            final isCurrent = u.id == Session.user?.id;
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: u.isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                        child: Icon(
                          u.isAdmin ? Icons.shield_rounded : Icons.person_rounded,
                          size: 16,
                          color: u.isAdmin ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        u.username,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Vous', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                        ),
                      ],
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: u.isAdmin ? const Color(0xFFDBEAFE) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      u.isAdmin ? 'ADMINISTRATEUR' : 'UTILISATEUR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: u.isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: u.isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      u.isActive ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: u.isActive ? const Color(0xFF047857) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _permBadge('Créer', u.hasCreateMovPermission),
                      const SizedBox(width: 4),
                      _permBadge('Modifier', u.hasUpdateMovPermission),
                      const SizedBox(width: 4),
                      _permBadge('Suppr', u.hasDeleteMovPermission),
                      const SizedBox(width: 4),
                      _permBadge('Journal', u.hasViewJournalSupprPermission, activeColor: const Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      _permBadge('Ancien Solde', u.hasViewOldSoldePermission, activeColor: const Color(0xFF4F46E5)),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: u.hasManageComptesPermission ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: u.hasManageComptesPermission ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          u.hasManageComptesPermission ? Icons.edit_note_rounded : Icons.visibility_rounded,
                          size: 13,
                          color: u.hasManageComptesPermission ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          u.hasManageComptesPermission ? 'Gestion complète' : 'Consultation seule',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: u.hasManageComptesPermission ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    u.isAdmin || u.canSeeAllCaisses
                        ? 'Toutes les caisses'
                        : '${u.assignedCaisseIds.length} caisse(s) assignée(s)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: u.isAdmin || u.canSeeAllCaisses ? const Color(0xFF059669) : const Color(0xFF2563EB),
                    ),
                  ),
                ),
                DataCell(
                  u.isAdmin
                      ? const Text('Toutes (Admin)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)))
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (u.canViewCustomers) _permBadge('Clients', true, activeColor: const Color(0xFF0891B2)),
                            if (u.canViewProducts) _permBadge('Produits', true, activeColor: const Color(0xFF0891B2)),
                            if (u.canViewSales) _permBadge('Ventes', true, activeColor: const Color(0xFF0891B2)),
                            if (u.canViewPurchases) _permBadge('Achats', true, activeColor: const Color(0xFF0891B2)),
                            if (u.canViewStock) _permBadge('Stock', true, activeColor: const Color(0xFF0891B2)),
                            if (u.canViewAccounting) _permBadge('Finance', true, activeColor: const Color(0xFF0891B2)),
                          ],
                        ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Modifier',
                        child: IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF2563EB)),
                          onPressed: () => _openUserDialog(user: u),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      if (!isCurrent)
                        Tooltip(
                          message: 'Supprimer',
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                            onPressed: () => _deleteUser(u),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _permBadge(String label, bool allowed, {Color? activeColor}) {
    final color = activeColor ?? const Color(0xFF059669);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: allowed ? color.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
        border: Border.all(color: allowed ? color.withValues(alpha: 0.3) : const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: allowed ? color : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}
