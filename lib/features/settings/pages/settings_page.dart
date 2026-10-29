import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import '../../accounting/pages/bank_rules_page.dart';
import 'developer_mode_tab.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FocusNode _focusNode = FocusNode();
  int _activeTabIndex = 0;
  bool _isDevModeUnlocked = false;

  List<_SettingsTab> get _currentTabs => [
        const _SettingsTab(
            icon: Icons.gavel_rounded, label: 'Règles Bancaires'),
        if (_isDevModeUnlocked)
          const _SettingsTab(
              icon: Icons.terminal_rounded, label: 'Mode Développeur'),
      ];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _unlockDevMode() {
    setState(() {
      _isDevModeUnlocked = true;
      _activeTabIndex = 1; // Direct jump to Developer tab
    });
  }

  void _promptDevPassword() {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              if (passwordController.text == 'Islam@dev2026') {
                Navigator.of(ctx).pop();
                _unlockDevMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mode Développeur déverrouillé avec succès !'),
                    backgroundColor: Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                setDialogState(() {
                  errorText = 'Mot de passe incorrect.';
                });
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Accès Développeur',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Veuillez entrer le mot de passe administrateur',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: errorText != null
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: TextField(
                          controller: passwordController,
                          obscureText: obscure,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                          onSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Mot de passe...',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: const Color(0xFF64748B),
                              ),
                              onPressed: () =>
                                  setDialogState(() => obscure = !obscure),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FButton(
                            onPress: () => Navigator.of(ctx).pop(),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 8),
                          FButton(
                            onPress: submit,
                            prefix: const Icon(Icons.key_rounded, size: 16),
                            child: const Text('Déverrouiller'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      // Shortcut: Ctrl + L
      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyL) {
        if (_isDevModeUnlocked) {
          // If already visible, make it invisible and return to the main tab
          setState(() {
            _isDevModeUnlocked = false;
            _activeTabIndex = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mode Développeur verrouillé et masqué.'),
              backgroundColor: Color(0xFF475569),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          return KeyEventResult.handled;
        } else {
          // If invisible, prompt for password
          _promptDevPassword();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _currentTabs;
    if (_activeTabIndex >= tabs.length) {
      _activeTabIndex = 0;
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_rounded,
                          color: Color(0xFF18181B), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paramètres',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF09090B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Configuration du système et des règles métier',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF71717A)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_isDevModeUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_open_rounded,
                                size: 14, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Text(
                              'Dev Mode Actif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Tab Navigation Bar ─────────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE4E4E7), width: 1),
                    ),
                  ),
                  child: Row(
                    children: List.generate(tabs.length, (index) {
                      final tab = tabs[index];
                      final isSelected = _activeTabIndex == index;

                      return InkWell(
                        onTap: () => setState(() => _activeTabIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab.icon,
                                size: 16,
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF71717A),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Content ──────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _activeTabIndex,
              children: [
                const BankRulesPage(),
                if (_isDevModeUnlocked) const DeveloperModeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab {
  final IconData icon;
  final String label;
  const _SettingsTab({required this.icon, required this.label});
}
