class User {
  final String id;
  final String username;
  final String role;
  final bool isActive;
  final bool canSeeAllCaisses;
  // Mouvements permissions
  final bool canCreateMov;
  final bool canUpdateMov;
  final bool canDeleteMov;
  // Comptes plan comptable permissions
  final bool canManageComptes; // If false, user can only CONSULT (read-only) accounts
  // Journal suppression permissions
  final bool canViewJournalSuppr;
  // Ancien solde (solde initial / report) permission
  final bool canViewOldSolde;
  // Module / Section permissions
  final bool canViewCustomers;
  final bool canViewProducts;
  final bool canViewSales;
  final bool canViewPurchases;
  final bool canViewStock;
  final bool canViewAccounting;
  final bool canValidateTransfert;
  final bool canDeleteBankRules;
  final List<String> assignedCaisseIds;

  const User({
    required this.id,
    required this.username,
    required this.role,
    this.isActive = true,
    this.canSeeAllCaisses = true,
    this.canCreateMov = true,
    this.canUpdateMov = true,
    this.canDeleteMov = true,
    this.canManageComptes = false,
    this.canViewJournalSuppr = false,
    this.canViewOldSolde = true,
    this.canViewCustomers = true,
    this.canViewProducts = true,
    this.canViewSales = true,
    this.canViewPurchases = true,
    this.canViewStock = true,
    this.canViewAccounting = true,
    this.canValidateTransfert = true,
    this.canDeleteBankRules = false,
    this.assignedCaisseIds = const [],
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  // Movement permissions (admin has all)
  bool get hasCreateMovPermission => isAdmin || canCreateMov;
  bool get hasUpdateMovPermission => isAdmin || canUpdateMov;
  bool get hasDeleteMovPermission => isAdmin || canDeleteMov;

  // Compte permissions: true means can create/edit/delete accounts; false means consultation only
  bool get hasManageComptesPermission => isAdmin || canManageComptes;

  // Journal suppression access
  bool get hasViewJournalSupprPermission => isAdmin || canViewJournalSuppr;

  // Ancien solde (solde initial) access
  bool get hasViewOldSoldePermission => isAdmin || canViewOldSolde;

  // Transfer validation access: accept or refuse transfer requests
  bool get hasValidateTransfertPermission => isAdmin || canValidateTransfert;

  // Bank rules deletion permission
  bool get hasDeleteBankRulesPermission => isAdmin || canDeleteBankRules;

  // Module section permissions (admin has all)
  bool get hasViewCustomersPermission => isAdmin || canViewCustomers;
  bool get hasViewProductsPermission => isAdmin || canViewProducts;
  bool get hasViewSalesPermission => isAdmin || canViewSales;
  bool get hasViewPurchasesPermission => isAdmin || canViewPurchases;
  bool get hasViewStockPermission => isAdmin || canViewStock;
  bool get hasViewAccountingPermission => isAdmin || canViewAccounting;

  /// Legacy aliases
  bool get hasCreatePermission => hasCreateMovPermission;
  bool get hasUpdatePermission => hasUpdateMovPermission;
  bool get hasDeletePermission => hasDeleteMovPermission;

  /// Whether this user can access the specified caisse
  bool canAccessCaisse(String caisseId) {
    if (isAdmin || canSeeAllCaisses) return true;
    return assignedCaisseIds.contains(caisseId);
  }

  User copyWith({
    String? id,
    String? username,
    String? role,
    bool? isActive,
    bool? canSeeAllCaisses,
    bool? canCreateMov,
    bool? canUpdateMov,
    bool? canDeleteMov,
    bool? canManageComptes,
    bool? canViewJournalSuppr,
    bool? canViewOldSolde,
    bool? canViewCustomers,
    bool? canViewProducts,
    bool? canViewSales,
    bool? canViewPurchases,
    bool? canViewStock,
    bool? canViewAccounting,
    bool? canValidateTransfert,
    bool? canDeleteBankRules,
    List<String>? assignedCaisseIds,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      canSeeAllCaisses: canSeeAllCaisses ?? this.canSeeAllCaisses,
      canCreateMov: canCreateMov ?? this.canCreateMov,
      canUpdateMov: canUpdateMov ?? this.canUpdateMov,
      canDeleteMov: canDeleteMov ?? this.canDeleteMov,
      canManageComptes: canManageComptes ?? this.canManageComptes,
      canViewJournalSuppr: canViewJournalSuppr ?? this.canViewJournalSuppr,
      canViewOldSolde: canViewOldSolde ?? this.canViewOldSolde,
      canViewCustomers: canViewCustomers ?? this.canViewCustomers,
      canViewProducts: canViewProducts ?? this.canViewProducts,
      canViewSales: canViewSales ?? this.canViewSales,
      canViewPurchases: canViewPurchases ?? this.canViewPurchases,
      canViewStock: canViewStock ?? this.canViewStock,
      canViewAccounting: canViewAccounting ?? this.canViewAccounting,
      canValidateTransfert: canValidateTransfert ?? this.canValidateTransfert,
      canDeleteBankRules: canDeleteBankRules ?? this.canDeleteBankRules,
      assignedCaisseIds: assignedCaisseIds ?? this.assignedCaisseIds,
    );
  }
}
