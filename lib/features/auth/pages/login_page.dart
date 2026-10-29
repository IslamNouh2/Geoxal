import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/database.dart';
import '../../../../core/security/session.dart';
import '../../../../data/datasources/user_datasource.dart';
import '../../../../data/repositories/auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin@1234');

  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    debugPrint('[LOGIN] _handleLogin triggered');
    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('[LOGIN] validation failed');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[LOGIN] Checking DB connection status: ${Database.instance.connection.isConnected}');
      if (!Database.instance.connection.isConnected) {
        debugPrint('[LOGIN] DB not connected, calling init()...');
        await Database.instance.init();
      }

      debugPrint('[LOGIN] Calling authRepo.login...');
      final authRepo = AuthRepository(UserDataSource(Database.instance));
      final user = await authRepo.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );
      debugPrint('[LOGIN] authRepo.login result: $user');

      if (user != null) {
        debugPrint('[LOGIN] Setting session user: ${user.username}');
        Session.setUser(user);
        if (!mounted) return;
        debugPrint('[LOGIN] Navigating to /dashboard ...');
        context.go('/dashboard');
      } else {
        debugPrint('[LOGIN] Invalid credentials');
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = 'Identifiants invalides. Vérifiez le nom d\'utilisateur et le mot de passe.';
        });
      }
    } catch (e, stack) {
      debugPrint('[LOGIN ERROR] $e');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Erreur de connexion à la base de données: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 16,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo
                        Center(
                          child: Image.asset(
                            'assets/images/Logo-2.png',
                           width: 250,
                            height: 80,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                       const SizedBox(height: 8),

                      //  const Text(
                      //     'Geoxal ERP',
                      //     textAlign: TextAlign.center,
                      //     style: TextStyle(
                      //       fontSize: 24,
                      //       fontWeight: FontWeight.w800,
                      //       color: Color(0xFF1E293B),
                      //       letterSpacing: -0.5,
                      //     ),
                      //   ),
                        const SizedBox(height: 6),
                        const Text(
                          'Connectez-vous à votre espace de gestion',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 28),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Username
                        const Text(
                          'Nom d\'utilisateur',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            hintText: 'admin',
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nom d\'utilisateur requis' : null,
                        ),

                        const SizedBox(height: 18),

                        // Password
                        const Text(
                          'Mot de passe',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Mot de passe requis' : null,
                        ),

                        const SizedBox(height: 26),

                        // Login button
                        ElevatedButton(
                          onPressed: _loading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Se connecter',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}