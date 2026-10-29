import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/database.dart';
import '../../../../core/security/session.dart';
import '../../../../data/datasources/finance_datasource.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../controllers/accounting_controller.dart';
import '../widgets/new_account_dialog.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late final AccountingController _controller;

  final TextEditingController _searchController = TextEditingController();
  List<Compte> _accounts = [];
  Set<String> _accountIdsWithMovements = {};
  String? _selectedAccountId;
  bool _loading = true;
  String? _error;
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _controller = AccountingController(FinanceRepository(FinanceDataSource(Database.instance)));
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
      final accounts = await _controller.loadAccounts();
      final idsWithMovements = await _controller.loadAccountIdsWithMovements();

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _accountIdsWithMovements = idsWithMovements;
        // Auto-expand all parents
        for (final account in accounts) {
  if (account.isParent) {
    _expandedIds.add(account.id);
  }
}
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger le plan comptable: $e';
      });
    }
  }

  Map<String, Compte> get _compteMap => {for (final a in _accounts) a.id: a};

  /// Returns IDs of accounts that are parents (have children) using NSM.
  // Set<String> get _parentIds => {
  //   for (final a in _accounts)
  //     if (a.isParent) a.id,
  // };

  Future<void> _newAccount({Compte? defaultParent}) async {
    final saved = await showNewAccountDialog(
      context,
      accounts: _accounts,
      accountIdsWithMovements: _accountIdsWithMovements,
      defaultParentId: defaultParent?.id,
      onSave: (code, libelle, parentId, typeCompte, {isDevise = false, codeDevise}) async {
        final parent = parentId == null ? null : _compteMap[parentId];
        await _controller.createAccount(
          code: code,
          libelle: libelle,
          compteFr: libelle,
          parentCompte: parent,
          userId: Session.user?.id,
          typeCompte: typeCompte,
          isDevise: isDevise,
          codeDevise: codeDevise,
        );
      },
    );

    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé avec succès dans le plan comptable.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _load();
    }
  }

  Future<void> _editAccount(Compte account) async {
    final isRoot = account.code == '0';
    final codeCtrl = TextEditingController(text: account.code);
    final libelleCtrl = TextEditingController(text: account.libelle);
    final compteFrCtrl = TextEditingController(text: account.compteFr ?? account.libelle);
    CompteType? selectedType = account.typeCompte ?? account.resolveEffectiveType(_accounts);
    
    // Find current parent of this account
    Compte? currentParent;
    if (!isRoot) {
      final ancestors = await _controller.getAncestors(account.id);
      if (ancestors.isNotEmpty) {
        currentParent = ancestors.last;
      }
    }
    String? selectedParentId = currentParent?.id;

    // Eligible parents: must not have movements, cannot be the account itself, and cannot be any descendant
    final eligibleParents = _accounts.where((a) {
      if (_accountIdsWithMovements.contains(a.id)) return false;
      // Cannot be self or inside its own subtree
      if (a.bg >= account.bg && a.bd <= account.bd) return false;
      return true;
    }).toList();

    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(
                isRoot ? 'Modifier le compte racine' : 'Modifier le compte',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      readOnly: isRoot,
                      decoration: InputDecoration(
                        labelText: 'Code de compte *',
                        helperText: isRoot ? 'Le compte racine conserve le code 0' : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: libelleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Libellé *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: compteFrCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nom FR',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!isRoot) ...[
                      DropdownButtonFormField<String>(
                        value: selectedParentId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Compte Parent *',
                          helperText: 'Tous les comptes doivent avoir un parent (racine: TOUS LES COMPTES)',
                          helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          for (final p in eligibleParents)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.displayName, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setS(() => selectedParentId = v),
                        validator: (v) => v == null ? 'Veuillez sélectionner un compte parent' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<CompteType>(
                      value: selectedType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Type de compte',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        for (final t in CompteType.values)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (v) => setS(() => selectedType = v),
                    ),
                  ],
                ),
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
      final updated = Compte(
        id: account.id,
        code: codeCtrl.text.trim(),
        libelle: libelleCtrl.text.trim(),
        compteFr: compteFrCtrl.text.trim().isEmpty ? null : compteFrCtrl.text.trim(),
        niveau: account.niveau,
        bg: account.bg,
        bd: account.bd,
        active: account.active,
        userId: account.userId,
        typeCompte: selectedType,
      );
      await _controller.updateAccount(updated);

      // If parent changed, move the account in NSM hierarchy
      if (!isRoot && selectedParentId != null && selectedParentId != currentParent?.id) {
        await _controller.moveAccount(account.id, targetParentId: selectedParentId);
      }

      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte modifié avec succès.'), backgroundColor: Color(0xFF10B981)),
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

  Future<void> _deleteAccount(Compte account) async {
    if (account.code == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le compte racine TOUS LES COMPTES ne peut jamais être supprimé.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (account.code == '6' || account.code.startsWith('6')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les comptes de Charges (Classe 6) sont obligatoires et protégés contre toute suppression.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Protection des comptes obligatoires du système (Trésorerie, Banques, Chèques, Taxes)
    const mandatoryCodes = {'0', '5', '51', '512', '511', '5112', '53', '531', '445', '44566', '7', '70', '71'};
    if (mandatoryCodes.contains(account.code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le compte "${account.code} - ${account.libelle}" est un compte obligatoire du système. Il ne peut jamais être supprimé.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if account has movements
    if (_accountIdsWithMovements.contains(account.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce compte contient des mouvements de trésorerie et ne peut pas être supprimé.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if account is a parent with subaccounts
    if (account.isParent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer un compte parent qui contient des sous-comptes.'),
          backgroundColor: Colors.red,
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
            Text('Supprimer ce compte ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${account.code} - ${account.libelle}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'La suppression de ce compte entraînera également la révocation automatique des accès utilisateurs associés à cette caisse.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
            ),
          ],
        ),
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
      await _controller.deleteAccount(account.id);
      setState(() => _selectedAccountId = null);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte supprimé avec succès.'), backgroundColor: Color(0xFFEF4444)),
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
    final selectedAcc = _selectedAccountId != null ? _compteMap[_selectedAccountId] : null;
    final search = _searchController.text.trim().toLowerCase();

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
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un compte (code, nom)...',
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
                if (Session.user?.hasManageComptesPermission ?? true)
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _newAccount(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouveau Compte', style: TextStyle(fontWeight: FontWeight.w600)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text(
                          'Mode Consultation Uniquement',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
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

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Tree panel
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                                    color: Color(0xFFF9FAFB),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.account_tree_rounded, size: 18, color: Color(0xFF2563EB)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Arborescence du Plan Comptable',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${_accounts.length} comptes',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: search.isEmpty
                                          ? _buildTree(null, 0)
                                          : _buildSearchResults(search),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 20),

                        // Right: Account Details & Actions
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: selectedAcc == null
                                ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.touch_app_rounded, size: 40, color: Color(0xFF9CA3AF)),
                                        SizedBox(height: 10),
                                        Text(
                                          'Sélectionnez un compte',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Cliquez sur un compte dans l\'arbre pour afficher ses informations et options.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.folder_open_rounded, color: Color(0xFF2563EB), size: 24),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  selectedAcc.displayName,
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                                ),
                                                Text(
                                                  'Niveau ${selectedAcc.niveau}',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      const Divider(height: 1),
                                      const SizedBox(height: 20),

                                      _detailRow('Code', selectedAcc.code),
                                      _detailRow('Libellé', selectedAcc.libelle),
                                      _detailRow('Nom FR', selectedAcc.compteFr ?? '—'),
                                      _detailRow(
                                        'Type de compte',
                                        selectedAcc.resolveEffectiveType(_accounts).label,
                                      ),
                                      _detailRow(
                                        'Compte Parent',
                                        _accounts
                                            .where((a) => a.isDirectParentOf(selectedAcc))
                                            .map((a) => a.displayName)
                                            .firstOrNull ?? 'Racine (Aucun)',
                                      ),
                                      _detailRow('Niveau', '${selectedAcc.niveau}'),
                                      _detailRow('Borne Gauche (BG)', '${selectedAcc.bg}'),
                                      _detailRow('Borne Droite (BD)', '${selectedAcc.bd}'),
                                      _detailRow('Nature', selectedAcc.isParent ? 'Compte Regroupement (Parent)' : 'Compte Feuille (Opérationnel)'),
                                      _detailRow('Possède des mouvements ?', _accountIdsWithMovements.contains(selectedAcc.id) ? 'Oui (Actif dans Trésorerie)' : 'Non'),

                                      const SizedBox(height: 24),

                                      // Edit this account
                                      if (Session.user?.hasManageComptesPermission ?? true)
                                        OutlinedButton.icon(
                                          onPressed: () => _editAccount(selectedAcc),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF2563EB),
                                            side: const BorderSide(color: Color(0xFF2563EB)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.edit_rounded, size: 16),
                                          label: const Text('Modifier ce compte'),
                                        ),

                                      const SizedBox(height: 10),

                                      // Actions on this account
                                      if (!_accountIdsWithMovements.contains(selectedAcc.id))
                                        if (Session.user?.hasManageComptesPermission ?? true) ...[
                                          ElevatedButton.icon(
                                            onPressed: () => _newAccount(defaultParent: selectedAcc),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.add, size: 16),
                                            label: const Text('Créer un sous-compte sous ce compte'),
                                          ),
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: () => _deleteAccount(selectedAcc),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFEF4444),
                                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                                              backgroundColor: const Color(0xFFFEF2F2),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                            label: const Text('Supprimer ce compte'),
                                          ),
                                        ]
                                      else
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Ce compte possède déjà des mouvements de trésorerie. Conformément aux règles, aucun sous-compte ne peut lui être rattaché.',
                                                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                                ),
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
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(CompteType type) {
    Color bg;
    Color fg;
    switch (type) {
      case CompteType.caisse:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case CompteType.banque:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case CompteType.recette:
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF6D28D9);
        break;
      case CompteType.depense:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case CompteType.recetteDepense:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        type.label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  /// Build the account tree using NSM (BG/BD) to determine hierarchy.
  /// [parentAccount] is null for root level; direct children are those with
  /// niveau == parent.niveau+1 AND parent.isAncestorOf(child).
  List<Widget> _buildTree(Compte? parentAccount, int depth) {
    final List<Compte> children;
    if (parentAccount == null) {
      // Root nodes: niveau == 1 (or the minimum niveau)
      final minNiveau = _accounts.isEmpty ? 1 : _accounts.map((a) => a.niveau).reduce((a, b) => a < b ? a : b);
      children = _accounts.where((a) => a.niveau == minNiveau).toList()..sort((a, b) => a.bg.compareTo(b.bg));
    } else {
      children = _accounts
          .where((a) => parentAccount.isDirectParentOf(a))
          .toList()
        ..sort((a, b) => a.bg.compareTo(b.bg));
    }

    final widgets = <Widget>[];

    for (final child in children) {
      final isParent = child.isParent;
      final isExpanded = _expandedIds.contains(child.id);
      final isSelected = _selectedAccountId == child.id;
      final hasMovements = _accountIdsWithMovements.contains(child.id);

      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 20.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedAccountId = child.id;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected ? Border.all(color: const Color(0xFF2563EB)) : null,
              ),
              child: Row(
                children: [
                  if (isParent)
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                        size: 18,
                        color: const Color(0xFF6B7280),
                      ),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedIds.remove(child.id);
                          } else {
                            _expandedIds.add(child.id);
                          }
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    )
                  else
                    const SizedBox(width: 24),
                  Icon(
                    isParent
                        ? (isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded)
                        : Icons.description_outlined,
                    size: 18,
                    color: isParent ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    child.code,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isParent ? const Color(0xFF1E3A8A) : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      child.libelle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isParent ? FontWeight.w600 : FontWeight.w400,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTypeBadge(child.resolveEffectiveType(_accounts)),
                  if (hasMovements) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Mvt', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      if (isParent && isExpanded) {
        widgets.addAll(_buildTree(child, depth + 1));
      }
    }

    return widgets;
  }

  List<Widget> _buildSearchResults(String query) {
    final matches = _accounts.where((a) {
      return a.code.toLowerCase().contains(query) ||
          a.libelle.toLowerCase().contains(query) ||
          (a.compteFr?.toLowerCase().contains(query) ?? false);
    }).toList();

    if (matches.isEmpty) {
      return const [Center(child: Text('Aucun compte correspondant.'))];
    }

    return matches.map((acc) {
      final isSelected = _selectedAccountId == acc.id;
      return ListTile(
        title: Text(acc.displayName, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
        selected: isSelected,
        selectedTileColor: const Color(0xFFEFF6FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => setState(() => _selectedAccountId = acc.id),
      );
    }).toList();
  }
}

