import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/main_layout.dart';
import '../../features/accounting/pages/accounting_page.dart';
import '../../features/accounting/pages/accounts_page.dart';
import '../../features/accounting/pages/remises_cheques_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/customers/pages/customers_page.dart';
import '../../features/dashboard/pages/dashboard.dart';
import '../../features/purchases/pages/purchases_page.dart';
import '../../features/sales/pages/sales_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/users/pages/users_management_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',

    routes: [
      // =========================
      // AUTH
      // =========================
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          return const LoginPage();
        },
      ),

      // =========================
      // APPLICATION SHELL
      // =========================
      ShellRoute(
        builder: (context, state, child) {
          return MainLayout(
            title: _getPageTitle(state.uri.path),
            currentRoute: state.uri.path,
            child: child,
          );
        },

        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) {
              return const Dashboard();
            },
          ),

          // Customers
          GoRoute(
            path: '/customers',
            name: 'customers',
            builder: (context, state) {
              return const CustomersPage();
            },
          ),

          // Products
          GoRoute(
            path: '/products',
            name: 'products',
            builder: (context, state) {
              return const _ComingSoonPage(title: 'Products');
            },
          ),

          // Sales
          GoRoute(
            path: '/sales',
            name: 'sales',
            builder: (context, state) {
              return const SalesPage();
            },
          ),

          // Purchases
          GoRoute(
            path: '/purchases',
            name: 'purchases',
            builder: (context, state) {
              return const PurchasesPage();
            },
          ),

          // Stock
          GoRoute(
            path: '/stock',
            name: 'stock',
            builder: (context, state) {
              return const _ComingSoonPage(title: 'Stock');
            },
          ),

          // Accounting (Trésorerie)
          GoRoute(
            path: '/accounting',
            name: 'accounting',
            builder: (context, state) {
              return const AccountingPage();
            },
          ),

          // Accounts (Plan Comptable)
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            builder: (context, state) {
              return const AccountsPage();
            },
          ),


          // Remises de chèques
          GoRoute(
            path: '/remises-cheques',
            name: 'remises-cheques',
            builder: (context, state) {
              return const RemisesChequesPage();
            },
          ),

          // Users (User Management & Permissions)
          GoRoute(
            path: '/users',
            name: 'users',
            builder: (context, state) {
              return const UsersManagementPage();
            },
          ),

          // Settings
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) {
              return const SettingsPage();
            },
          ),
        ],
      ),
    ],
  );

  static String _getPageTitle(String path) {
    switch (path) {
      case '/dashboard':
        return 'Dashboard';

      case '/customers':
        return 'Customers';

      case '/products':
        return 'Products';

      case '/sales':
        return 'Sales';

      case '/purchases':
        return 'Purchases';

      case '/stock':
        return 'Stock';

      case '/accounting':
        return 'Trésorerie';

      case '/accounts':
        return 'Plan Comptable (Comptes)';


      case '/remises-cheques':
        return 'Remise de Chèques';

      case '/users':
        return 'Gestion des Utilisateurs';

      case '/settings':
        return 'Paramètres';

      default:
        return 'Geoxal';
    }
  }
}

class _ComingSoonPage extends StatelessWidget {
  final String title;

  const _ComingSoonPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title\nComing Soon',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
    );
  }
}
