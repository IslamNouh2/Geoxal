import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/client_migration_service.dart';

class ClientMigrationTab extends StatefulWidget {
  const ClientMigrationTab({super.key});

  @override
  State<ClientMigrationTab> createState() => _ClientMigrationTabState();
}

class _ClientMigrationTabState extends State<ClientMigrationTab> {
  bool _loading = false;
  MigrationSummary? _summary;
  String? _error;

  bool _isMigrating = false;
  bool _backupBeforeMigrate = true;
  double _progress = 0.0;
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Do NOT block UI during initState. Trigger fetch after initial build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSummary();
    });
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _appendLog(String line) {
    if (mounted) {
      setState(() {
        _logs.add(line);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _loadSummary() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await ClientMigrationService.getMigrationSummary(
        onLog: _appendLog,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
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

  Future<void> _runMigrations() async {
    final pendingCount = _summary?.pendingCount ?? 0;
    if (pendingCount == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Confirmer la Mise à Jour'),
          ],
        ),
        content: Text(
          'Voulez-vous appliquer les $pendingCount mise(s) à jour en attente sur la base de données client ?\n\n'
          '${_backupBeforeMigrate ? "Une copie de sauvegarde de votre fichier .FDB sera automatiquement créée." : ""}',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Démarrer la Migration'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isMigrating = true;
      _logs.clear();
      _progress = 0.0;
    });

    final success = await ClientMigrationService.applyPendingMigrations(
      createBackup: _backupBeforeMigrate,
      onLog: _appendLog,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    setState(() => _isMigrating = false);
    await _loadSummary();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Base de données mise à jour avec succès !'
              : 'La mise à jour a rencontré des erreurs. Vérifiez les logs.',
        ),
        backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Vérification des versions de la base de données...',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              if (_logs.isNotEmpty) ...[
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _buildConsoleCard(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_error != null && _summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text('Erreur: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _summary ?? const MigrationSummary(
      migrations: [],
      appliedCount: 0,
      pendingCount: 0,
      databasePath: '',
      dsnName: 'GEOXAL',
    );
    final isUpToDate = summary.pendingCount == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Status
          _buildStatusBanner(summary, isUpToDate),
          const SizedBox(height: 20),

          // Overview KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Version Actuelle',
                  value: summary.migrations.isNotEmpty
                      ? (summary.migrations.lastWhere((m) => m.isApplied, orElse: () => summary.migrations.first).version)
                      : 'N/A',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  title: 'Scripts Appliqués',
                  value: '${summary.appliedCount} / ${summary.migrations.length}',
                  icon: Icons.layers_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  title: 'Mises à Jour en Attente',
                  value: '${summary.pendingCount}',
                  icon: Icons.pending_actions_rounded,
                  color: isUpToDate ? const Color(0xFF64748B) : const Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Toolbar & Backup option
          _buildActionCard(summary, isUpToDate),
          const SizedBox(height: 24),

          // Migrations List
          _buildMigrationsListCard(summary),
          const SizedBox(height: 24),

          // Logs Console
          _buildConsoleCard(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(MigrationSummary summary, bool isUpToDate) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isUpToDate ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUpToDate ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUpToDate ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUpToDate ? Icons.verified_rounded : Icons.system_update_rounded,
              color: isUpToDate ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUpToDate
                      ? 'Base de Données Client à Jour'
                      : '${summary.pendingCount} Mise(s) à Jour Disponible(s) pour la Base Client',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isUpToDate ? const Color(0xFF166534) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DSN Actif : ${summary.dsnName}  |  Chemin FDB : ${summary.databasePath.isNotEmpty ? summary.databasePath : "Non détecté"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Consolas',
                    color: isUpToDate ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _loading || _isMigrating ? null : _loadSummary,
            icon: _loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Actualiser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(MigrationSummary summary, bool isUpToDate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _backupBeforeMigrate,
            onChanged: _isMigrating ? null : (v) => setState(() => _backupBeforeMigrate = v ?? true),
            activeColor: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sécurité Client : Créer une sauvegarde automatique avant d\'appliquer (.bak)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                Text(
                  'Recommandé pour prévenir toute coupure de courant ou imprévu sur le PC client.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: isUpToDate || _isMigrating || _loading ? null : _runMigrations,
            icon: _isMigrating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.flash_on_rounded, size: 18),
            label: Text(
              _isMigrating ? 'Migration en cours...' : 'Mettre à Jour la Base Client',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationsListCard(MigrationSummary summary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Historique & Fichiers de Migrations SQL',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Text(
                  '${summary.appliedCount}/${summary.migrations.length} appliqués',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (summary.migrations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Aucun fichier de migration trouvé dans database/migrations.'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summary.migrations.length,
              separatorBuilder: (context, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = summary.migrations[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.isApplied ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.isApplied ? Icons.check_rounded : Icons.hourglass_top_rounded,
                      color: item.isApplied ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      size: 16,
                    ),
                  ),
                  title: Text(
                    item.version,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  subtitle: Text(
                    'Fichier: ${item.filename}  (${item.statementsCount} instructions SQL)',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isApplied ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.isApplied ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      item.isApplied ? 'Appliqué' : 'En attente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: item.isApplied ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildConsoleCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                const Text(
                  'Console d\'Exécution en Direct (Terminal Logs)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                if (_isMigrating)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                  tooltip: 'Copier tous les logs',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: _logs.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: _logs.join('\n')));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Logs copiés dans le presse-papiers !'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                              width: 280,
                            ),
                          );
                        },
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Color(0xFF94A3B8)),
                  tooltip: 'Effacer les logs',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: _logs.isEmpty ? null : () => setState(() => _logs.clear()),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'En attente d\'instructions...',
                      style: TextStyle(fontFamily: 'Consolas', fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final line = _logs[index];
                      Color color = const Color(0xFFE2E8F0);
                      if (line.contains('✅') || line.contains('✓')) {
                        color = const Color(0xFF4ADE80);
                      } else if (line.contains('❌') || line.contains('ERREUR')) {
                        color = const Color(0xFFF87171);
                      } else if (line.contains('⚠️')) {
                        color = const Color(0xFFFBBF24);
                      } else if (line.contains('🚀') || line.contains('💾') || line.contains('🔍') || line.contains('📂')) {
                        color = const Color(0xFF38BDF8);
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText(
                          line,
                          style: TextStyle(fontFamily: 'Consolas', fontSize: 11, color: color),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
