import 'package:flutter/material.dart';

import 'sidebar.dart';
import 'navbar.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),

      body: Row(
        children: [
          // =========================
          // FIXED SIDEBAR
          // =========================

          Sidebar(
            currentRoute: currentRoute,
          ),

          // =========================
          // RIGHT SIDE
          // =========================

          Expanded(
            child: Column(
              children: [
                // FIXED NAVBAR
                Navbar(
                  title: title,
                ),

                // PAGE CONTENT
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}