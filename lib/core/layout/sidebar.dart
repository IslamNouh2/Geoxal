import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../security/session.dart';

class Sidebar extends StatelessWidget {
  final String currentRoute;

  const Sidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF15171A),

      child: Column(
        children: [
          const SizedBox(height: 24),

          _buildLogo(),

          const SizedBox(height: 30),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _menuItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    route: '/dashboard',
                  ),

                  _sectionTitle('Management'),

                  if (Session.user?.hasViewCustomersPermission ?? true)
                    _menuItem(
                      context,
                      icon: Icons.people_alt_rounded,
                      title: 'Customers',
                      route: '/customers',
                    ),

                  if (Session.user?.hasViewProductsPermission ?? true)
                    _menuItem(
                      context,
                      icon: Icons.inventory_2_rounded,
                      title: 'Products',
                      route: '/products',
                    ),

                  if (Session.user?.hasViewSalesPermission ?? true)
                    _menuItem(
                      context,
                      icon: Icons.point_of_sale_rounded,
                      title: 'Sales',
                      route: '/sales',
                    ),

                  if (Session.user?.hasViewPurchasesPermission ?? true)
                    _menuItem(
                      context,
                      icon: Icons.shopping_cart_rounded,
                      title: 'Purchases',
                      route: '/purchases',
                    ),

                  if (Session.user?.hasViewStockPermission ?? true)
                    _menuItem(
                      context,
                      icon: Icons.warehouse_rounded,
                      title: 'Stock',
                      route: '/stock',
                    ),

                  _sectionTitle('Finance'),

                  if (Session.user?.hasViewAccountingPermission ?? true)
                    _menuItem(
                      context,
                      icon: Icons.account_balance_rounded,
                      title: 'Trésorerie',
                      route: '/accounting',
                    ),

                  if (Session.user?.hasViewAccountingPermission ?? true)
                    _menuItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      title: 'Remise Chèques',
                      route: '/remises-cheques',
                    ),


                  if (Session.user?.hasViewAccountingPermission ?? true)
                    _menuItem(
                      context,
                      icon: Icons.account_tree_rounded,
                      title: 'Comptes',
                      route: '/accounts',
                    ),

                  _sectionTitle('System'),

                  if (Session.user?.isAdmin ?? true)
                    _menuItem(
                      context,
                      icon: Icons.manage_accounts_rounded,
                      title: 'Utilisateurs',
                      route: '/users',
                    ),

                  _menuItem(
                    context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    route: '/settings',
                  ),
                ],
              ),
            ),
          ),

          _buildUser(context),
        ],
      ),
    );
  }

  Widget _buildLogo() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: SizedBox(
      height: 64,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          'assets/images/Logo-2.png',
          width: 200,
          height: 50,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    ),
  );
}

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        8,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    final bool selected = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 2,
      ),
      child: Material(
        color: selected
            ? const Color(0xFF2563EB)
            : Colors.transparent,

        borderRadius: BorderRadius.circular(9),

        child: InkWell(
          borderRadius: BorderRadius.circular(9),

          onTap: () {
            if (!selected) {
              context.go(route);
            }
          },

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF9CA3AF),
                ),

                const SizedBox(width: 13),

                Text(
                  title,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFFD1D5DB),
                    fontSize: 14,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUser(BuildContext context) {
    final user = Session.user;
    final username = user?.username ?? 'Administrator';
    final roleName = user?.isAdmin == true ? 'Administrateur' : 'Utilisateur';

    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: user?.isAdmin == true ? const Color(0xFF2563EB) : const Color(0xFF4B5563),
            child: Icon(
              user?.isAdmin == true ? Icons.shield_rounded : Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  roleName,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Déconnexion',
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
                        SizedBox(width: 8),
                        Text('Déconnexion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Se déconnecter'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  Session.setUser(null);
                  context.go('/login');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}