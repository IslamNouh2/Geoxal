import 'dart:io';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../../../core/services/developer_database_service.dart';

class DeveloperModeTab extends StatefulWidget {
  const DeveloperModeTab({super.key});

  @override
  State<DeveloperModeTab> createState() => _DeveloperModeTabState();
}

class _DeveloperModeTabState extends State<DeveloperModeTab> {
  // Mode selection: 0 = Modèle Template (GEOVIDE.FDB), 1 = Initialisation SQL Vierge
  int _selectedMode = 0;

  // Controllers for Template Clone Mode
  final _templatePathController =
      TextEditingController(text: r'E:\Geoxal\database\GEOVIDE.FDB');
  final _targetFolderController =
      TextEditingController(text: r'F:\GEOXAL PROJECT');
  final _targetFilePathController =
      TextEditingController(text: r'F:\GEOXAL PROJECT\GEOXAL_NOUVELLE.FDB');
  final _templateDsnController = TextEditingController(text: 'GEOXAL_NOUVELLE');
  final _templateCharsetController = TextEditingController(text: 'WIN1251');
  bool _templateConfigureOdbc = true;

  // Controllers for Scratch Initialization Mode
  final _pathController =
      TextEditingController(text: r'C:\GEOXAL_DATA\GEOXAL.FDB');
  final _dsnController = TextEditingController(text: 'GEOXAL');
  final _userController = TextEditingController(text: 'SYSDBA');
  final _passwordController = TextEditingController(text: 'masterkey');
  final _charsetController = TextEditingController(text: 'WIN1251');
  final _pageSizeController = TextEditingController(text: '16384');
  bool _configureOdbc = true;
  bool _applySchema = true;
  bool _applyMigrations = true;

  // Diagnostics state
  bool _checkingStatus = true;
  Map<String, dynamic>? _systemStatus;
  bool _testingConnection = false;
  String? _testConnectionResult;

  // Execution state
  bool _isCreating = false;
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  // Controllers for Migration & Schema Sync (Mode 2)
  final _activeDbPathController =
      TextEditingController(text: r'F:\GEOXAL PROJECT\GEOXAL.FDB');
  final _migrationSqlController = TextEditingController(
      text: '-- Écrivez votre script SQL de migration ici\n-- Ex: ALTER TABLE COMPTES ADD NOUVEAU_CHAMP VARCHAR(50);');
  final _migrationFilePathController = TextEditingController();
  bool _isComparing = false;
  bool _loadingFile = false;
  Map<String, dynamic>? _compareResult;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _templatePathController.dispose();
    _targetFolderController.dispose();
    _targetFilePathController.dispose();
    _templateDsnController.dispose();
    _templateCharsetController.dispose();

    _pathController.dispose();
    _dsnController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _charsetController.dispose();
    _pageSizeController.dispose();
    _logScrollController.dispose();

    _activeDbPathController.dispose();
    _migrationSqlController.dispose();
    _migrationFilePathController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    setState(() => _checkingStatus = true);
    final status = await DeveloperDatabaseService.checkSystemStatus();
    if (mounted) {
      setState(() {
        _systemStatus = status;
        _checkingStatus = false;
      });
    }
  }

  Future<void> _testActiveOdbc() async {
    setState(() {
      _testingConnection = true;
      _testConnectionResult = null;
    });

    final dsn = _selectedMode == 0
        ? _templateDsnController.text.trim()
        : _dsnController.text.trim();
    final ok = await DeveloperDatabaseService.testOdbcConnection(dsn);

    if (mounted) {
      setState(() {
        _testingConnection = false;
        _testConnectionResult = ok
            ? 'Connexion ODBC "$dsn" réussie !'
            : 'Échec de connexion ODBC "$dsn".';
      });
    }
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
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // 1. Create from Template Mode (GEOVIDE.FDB -> Copy & Rename to DSN Name -> Setup ODBC)
  Future<void> _createFromTemplate() async {
    final templatePath = _templatePathController.text.trim();
    final targetFilePath = _targetFilePathController.text.trim();
    final dsnName = _templateDsnController.text.trim();

    if (templatePath.isEmpty || targetFilePath.isEmpty || dsnName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Veuillez renseigner le chemin du modèle, le chemin de la nouvelle base et le nom DSN.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
      _logs.clear();
      _logs.add('Démarrage du clonage depuis le modèle template...');
    });

    final result = await DeveloperDatabaseService.createDatabaseFromTemplate(
      templatePath: templatePath,
      explicitTargetFilePath: targetFilePath,
      dsnName: dsnName,
      charset: _templateCharsetController.text.trim(),
      configureOdbc: _templateConfigureOdbc,
      onLog: _appendLog,
    );

    if (mounted) {
      setState(() {
        _isCreating = false;
      });
      await _refreshStatus();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626),
        ),
      );
    }
  }

  // 2. Create blank database from SQL scripts
  Future<void> _createBlankDatabase() async {
    final fdbPath = _pathController.text.trim();
    final dsnName = _dsnController.text.trim();

    if (fdbPath.isEmpty || dsnName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le chemin FDB et le nom DSN.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
      _logs.clear();
      _logs.add('Démarrage de la création vierge...');
    });

    final pageSize = int.tryParse(_pageSizeController.text.trim()) ?? 16384;

    final result = await DeveloperDatabaseService.createAndInitializeDatabase(
      fdbPath: fdbPath,
      dsnName: dsnName,
      user: _userController.text.trim(),
      password: _passwordController.text.trim(),
      charset: _charsetController.text.trim(),
      pageSize: pageSize,
      configureOdbc: _configureOdbc,
      applySchema: _applySchema,
      applyMigrations: _applyMigrations,
      onLog: _appendLog,
    );

    if (mounted) {
      setState(() {
        _isCreating = false;
      });
      await _refreshStatus();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626),
        ),
      );
    }
  }

  // 3. Compare active DB with GEOVIDE template
  Future<void> _compareWithTemplate() async {
    final activeDb = _activeDbPathController.text.trim();
    final templateDb = _templatePathController.text.trim();

    if (activeDb.isEmpty || templateDb.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le chemin de la base active et du modèle GEOVIDE.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isComparing = true;
      _logs.clear();
      _logs.add('Démarrage de la comparaison des schémas...');
    });

    final res = await DeveloperDatabaseService.compareDatabaseSchemas(
      activeDbPath: activeDb,
      templateDbPath: templateDb,
      onLog: _appendLog,
    );

    if (mounted) {
      setState(() {
        _isComparing = false;
        _compareResult = res;
      });
    }
  }

  // ── File picker via PowerShell (Windows) ─────────────────────────────────
  Future<void> _browseMigrationFile() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "Add-Type -AssemblyName System.Windows.Forms; "
            r"$d = New-Object System.Windows.Forms.OpenFileDialog; "
            r"$d.Filter = 'SQL files (*.sql)|*.sql|All files (*.*)|*.*'; "
            r"$d.Title = 'Sélectionner un fichier de migration SQL'; "
            r"if ($d.ShowDialog() -eq 'OK') { Write-Output $d.FileName }",
      ]);
      final path = result.stdout.toString().trim();
      if (path.isNotEmpty) {
        setState(() => _migrationFilePathController.text = path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur ouverture fichier: $e')),
        );
      }
    }
  }

  Future<void> _loadMigrationFromFile() async {
    final path = _migrationFilePathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir ou sélectionner un chemin de fichier.')),
      );
      return;
    }
    setState(() => _loadingFile = true);
    try {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fichier introuvable : $path')),
          );
        }
        return;
      }
      final content = await file.readAsString();
      setState(() => _migrationSqlController.text = content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Fichier chargé : ${path.split(r'\').last}'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lecture fichier: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFile = false);
    }
  }

  // 4. Apply Dual Migration (Active DB + GEOVIDE) with Confirmation
  Future<void> _confirmAndApplyDualMigration() async {
    final sql = _migrationSqlController.text.trim();
    final activeDb = _activeDbPathController.text.trim();
    final templateDb = _templatePathController.text.trim();

    if (sql.isEmpty || sql.startsWith('-- Écrivez votre')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir les instructions SQL de la migration.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Confirmation dialog before starting process
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 10),
            Text('Confirmation de Migration Double', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Êtes-vous sûr de vouloir exécuter ce script SQL de migration ?\nIl sera appliqué simultanément sur :',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Base Active : $activeDb', style: const TextStyle(fontSize: 11, fontFamily: 'Consolas', fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('2. Modèle Template : $templateDb', style: const TextStyle(fontSize: 11, fontFamily: 'Consolas', fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Script SQL :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sql,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: Color(0xFF38BDF8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FButton(
            onPress: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 8),
          FButton(
            onPress: () => Navigator.of(ctx).pop(true),
            prefix: const Icon(Icons.play_arrow_rounded, size: 16),
            child: const Text('Confirmer & Exécuter'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isCreating = true;
      _logs.clear();
      _logs.add('Exécution confirmée de la migration sur les 2 bases...');
    });

    final res = await DeveloperDatabaseService.applyDualMigration(
      activeDbPath: activeDb,
      templateDbPath: templateDb,
      sqlContent: sql,
      onLog: _appendLog,
    );

    if (mounted) {
      setState(() => _isCreating = false);
      // Auto re-compare
      await _compareWithTemplate();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Banner ──────────────────────────────────────────
          _buildHeaderBanner(),
          const SizedBox(height: 24),

          // ── System Diagnostics ────────────────────────────────────
          _buildSystemStatusCard(),
          const SizedBox(height: 24),

          // ── Method Selection (Mode Selector) ──────────────────────
          _buildModeSelector(),
          const SizedBox(height: 20),

          // ── Form based on selected mode ───────────────────────────
          if (_selectedMode == 0)
            _buildTemplateCloneFormCard()
          else if (_selectedMode == 1)
            _buildScratchCreationFormCard()
          else
            _buildMigrationSyncFormCard(),
          const SizedBox(height: 24),

          // ── Live Logs Console ─────────────────────────────────────
          if (_logs.isNotEmpty || _isCreating || _isComparing) _buildConsoleCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.terminal_rounded,
                color: Color(0xFF2563EB), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode Développeur — Gestion Base de Données & Pilote ODBC',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dupliquez un modèle pré-rempli (ex: GEOVIDE.FDB) avec configuration ODBC instantanée, ou générez une base vierge via scripts SQL.',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey[700]),
                ),
              ],
            ),
          ),
          FButton(
            onPress: _checkingStatus ? null : _refreshStatus,
            prefix: const Icon(Icons.refresh_rounded, size: 16),
            child: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety_outlined,
                    size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                const Text(
                  'Diagnostic Système & Environnement Windows',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                if (_testingConnection)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FButton(
                    onPress: _testActiveOdbc,
                    prefix: const Icon(Icons.cable_rounded, size: 14),
                    child: const Text('Tester Connexion ODBC'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const FDivider(),
            const SizedBox(height: 14),
            if (_checkingStatus)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _buildStatusPill(
                    label: 'Outil isql.exe Firebird',
                    ok: _systemStatus?['isqlExists'] == true,
                    info: _systemStatus?['isqlPath'] ?? '',
                  ),
                  _buildStatusPill(
                    label: 'Client fbclient.dll',
                    ok: _systemStatus?['fbClientExists'] == true,
                    info: _systemStatus?['fbClientPath'] ?? '',
                  ),
                  _buildStatusPill(
                    label: 'Driver ODBC (OdbcFb.dll)',
                    ok: _systemStatus?['odbcDriverExists'] == true,
                    info: _systemStatus?['odbcDriverPath'] ?? '',
                  ),
                  _buildStatusPill(
                    label: 'DSN Windows "GEOXAL"',
                    ok: _systemStatus?['dsnExists'] == true,
                    info: _systemStatus?['currentDbPath'] ?? 'Non configuré',
                  ),
                ],
              ),
              if (_testConnectionResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _testConnectionResult!.contains('réussie')
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _testConnectionResult!.contains('réussie')
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _testConnectionResult!.contains('réussie')
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        size: 16,
                        color: _testConnectionResult!.contains('réussie')
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _testConnectionResult!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _testConnectionResult!.contains('réussie')
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool ok,
    required String info,
  }) {
    return Container(
      width: 270,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        ok ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            info,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Consolas',
              color: Color(0xFF475569),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedMode = 0),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _selectedMode == 0
                    ? const Color(0xFFEFF6FF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedMode == 0
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                  width: _selectedMode == 0 ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.content_copy_rounded,
                    color: _selectedMode == 0
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloner depuis Modèle (Recommandé)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedMode == 0
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Copier GEOVIDE.FDB, renommer selon le DSN et associer l\'ODBC',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedMode == 0)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2563EB), size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedMode = 1),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _selectedMode == 1
                    ? const Color(0xFFEFF6FF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedMode == 1
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                  width: _selectedMode == 1 ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.code_rounded,
                    color: _selectedMode == 1
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Création Vierge par Script SQL',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedMode == 1
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Exécuter CREATE DATABASE + schema_complete.sql + migrations',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedMode == 1)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2563EB), size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedMode = 2),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _selectedMode == 2
                    ? const Color(0xFFEFF6FF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedMode == 2
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                  width: _selectedMode == 2 ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sync_alt_rounded,
                    color: _selectedMode == 2
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Migration & Synchro GEOVIDE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedMode == 2
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Comparer schémas et migrer simultanément sur les 2 bases',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedMode == 2)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2563EB), size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mode 3 : Migration & Comparison with GEOVIDE ──────────────────────
  Widget _buildMigrationSyncFormCard() {
    final comp = _compareResult;
    final isSynced = comp?['isSynced'] == true;
    final missingInTemplate = comp?['missingInTemplate'] as Map<String, List<String>>?;
    final missingInActive = comp?['missingInActive'] as Map<String, List<String>>?;

    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt_rounded, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                const Text(
                  'Comparaison de Schémas & Migration Double (Base Active + GEOVIDE)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                FButton(
                  onPress: _isComparing ? null : _compareWithTemplate,
                  prefix: _isComparing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.compare_arrows_rounded, size: 16),
                  child: Text(_isComparing ? 'Comparaison...' : 'Vérifier Différences Schémas'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FDivider(),
            const SizedBox(height: 18),

            // Paths of the two databases
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    label: 'Base Active GEOXAL (.FDB)',
                    controller: _activeDbPathController,
                    hint: r'F:\GEOXAL PROJECT\GEOXAL.FDB',
                    icon: Icons.storage_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInput(
                    label: 'Modèle Template GEOVIDE (.FDB)',
                    controller: _templatePathController,
                    hint: r'E:\Geoxal\database\GEOVIDE.FDB',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Schema Comparison Status Box
            if (comp != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSynced ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSynced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSynced ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: isSynced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSynced
                              ? 'Les deux bases sont parfaitement synchronisées (100% identiques) !'
                              : 'Des différences de schéma ont été détectées :',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSynced ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                    if (!isSynced) ...[
                      const SizedBox(height: 10),
                      if (missingInTemplate != null && missingInTemplate.isNotEmpty) ...[
                        const Text('Éléments présents dans la Base Active mais absents de GEOVIDE :',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B))),
                        for (final entry in missingInTemplate.entries)
                          Padding(
                            padding: const EdgeInsets.only(left: 14, top: 2),
                            child: Text('• ${entry.key} : ${entry.value.join(", ")}',
                                style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: Color(0xFF7F1D1D))),
                          ),
                        const SizedBox(height: 8),
                      ],
                      if (missingInActive != null && missingInActive.isNotEmpty) ...[
                        const Text('Éléments présents dans GEOVIDE mais absents de la Base Active :',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                        for (final entry in missingInActive.entries)
                          Padding(
                            padding: const EdgeInsets.only(left: 14, top: 2),
                            child: Text('• ${entry.key} : ${entry.value.join(", ")}',
                                style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: Color(0xFF92400E))),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── File SQL Loader ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Text(
                        'Charger depuis un fichier .sql',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _migrationFilePathController,
                          style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                          decoration: InputDecoration(
                            hintText: r'E:\Geoxal\database\migrations\V005_add_transaction_mode_and_devise.sql',
                            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _browseMigrationFile,
                        icon: const Icon(Icons.folder_rounded, size: 16),
                        label: const Text('Parcourir'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          side: const BorderSide(color: Color(0xFF94A3B8)),
                          foregroundColor: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _loadingFile ? null : _loadMigrationFromFile,
                        icon: _loadingFile
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download_rounded, size: 16),
                        label: const Text("Charger dans l'éditeur"),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Le contenu du fichier sera copié dans l'éditeur SQL ci-dessous. Vérifiez avant d'exécuter.",
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Migration SQL Input Editor
            const Text(
              'Script SQL de Migration Double :',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: _migrationSqlController,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'ALTER TABLE ... ADD ...;',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 18),


            // Execute button with confirmation
            Align(
              alignment: Alignment.centerRight,
              child: FButton(
                onPress: _isCreating ? null : _confirmAndApplyDualMigration,
                prefix: _isCreating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch_rounded, size: 16),
                child: Text(_isCreating
                    ? 'Exécution sur les 2 bases en cours...'
                    : 'Appliquer sur Active DB + GEOVIDE (avec confirmation)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode 1 : Clone from GEOVIDE.FDB ───────────────────────────────────
  Widget _buildTemplateCloneFormCard() {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.copy_all_rounded,
                    size: 20, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text(
                  'Duplication du Modèle & Configuration Source ODBC',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FDivider(),
            const SizedBox(height: 18),

            // Source template path
            _buildInput(
              label: 'Chemin du modèle source avec données par défaut (GEOVIDE.FDB)',
              controller: _templatePathController,
              hint: r'F:\GEOXAL PROJECT\GEOVIDE.FDB',
              icon: Icons.file_present_rounded,
            ),
            const SizedBox(height: 16),

            // Target Full Path & DSN Name
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildInput(
                    label: 'Chemin complet de la nouvelle base (.FDB)',
                    controller: _targetFilePathController,
                    hint: r'F:\GEOXAL PROJECT\GEOXAL_NOUVELLE.FDB',
                    icon: Icons.folder_open_rounded,
                    onChanged: (val) {
                      // Automatically deduce DSN name if user writes path
                      final file = val.split(RegExp(r'[\\/]')).last;
                      final dsnCandidate = file.replaceAll(RegExp(r'\.fdb$', caseSensitive: false), '');
                      if (dsnCandidate.isNotEmpty && dsnCandidate != _templateDsnController.text) {
                        _templateDsnController.text = dsnCandidate;
                      }
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildInput(
                    label: 'Nom de la nouvelle base / Source ODBC (DSN)',
                    controller: _templateDsnController,
                    hint: 'GEOXAL_NOUVELLE',
                    icon: Icons.dns_rounded,
                    onChanged: (newDsn) {
                      // Automatically update target file name if user edits DSN
                      final currentPath = _targetFilePathController.text;
                      final lastSeparator = currentPath.lastIndexOf(RegExp(r'[\\/]'));
                      if (lastSeparator != -1) {
                        final dir = currentPath.substring(0, lastSeparator + 1);
                        final cleanDsn = newDsn.trim();
                        final ext = cleanDsn.toUpperCase().endsWith('.FDB') ? cleanDsn : '$cleanDsn.FDB';
                        _targetFilePathController.text = '$dir$ext';
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live confirmation card of configured path
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Text(
                    'Base de destination & DSN : ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155)),
                  ),
                  Expanded(
                    child: Text(
                      '${_targetFilePathController.text.trim()}  ➜  DSN [${_templateDsnController.text.trim()}]',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Consolas',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Additional params
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    label: 'Jeu de Caractères ODBC (Charset)',
                    controller: _templateCharsetController,
                    hint: 'WIN1251',
                    icon: Icons.font_download_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: FCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: FCheckbox(
                          value: _templateConfigureOdbc,
                          label: const Text('Configurer le DSN ODBC Windows'),
                          description:
                              const Text('Enregistrer dans la base de registre'),
                          onChange: (v) =>
                              setState(() => _templateConfigureOdbc = v),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Button
            Align(
              alignment: Alignment.centerRight,
              child: FButton(
                onPress: _isCreating ? null : _createFromTemplate,
                prefix: _isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.copy_rounded, size: 18),
                child: Text(_isCreating
                    ? 'Copie et configuration en cours...'
                    : 'Créer la Base & Configurer ODBC'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode 2 : Scratch initialization ──────────────────────────────────
  Widget _buildScratchCreationFormCard() {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 20, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text(
                  'Configuration & Création Vierge par Script SQL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FDivider(),
            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildInput(
                    label: 'Chemin du fichier Base (.FDB)',
                    controller: _pathController,
                    hint: r'C:\GEOXAL_DATA\GEOXAL.FDB',
                    icon: Icons.folder_open_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildInput(
                    label: 'Nom de la Source ODBC (DSN)',
                    controller: _dsnController,
                    hint: 'GEOXAL',
                    icon: Icons.dns_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    label: 'Utilisateur Firebird',
                    controller: _userController,
                    hint: 'SYSDBA',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInput(
                    label: 'Mot de passe',
                    controller: _passwordController,
                    hint: 'masterkey',
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInput(
                    label: 'Jeu de Caractères (Charset)',
                    controller: _charsetController,
                    hint: 'WIN1251',
                    icon: Icons.font_download_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInput(
                    label: 'Taille de Page (Page Size)',
                    controller: _pageSizeController,
                    hint: '16384',
                    icon: Icons.grid_view_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Options d\'initialisation :',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: FCheckbox(
                        value: _applySchema,
                        label: const Text('Exécuter schema_complete.sql'),
                        description:
                            const Text('Tables, Triggers, Procédures de base'),
                        onChange: (v) => setState(() => _applySchema = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: FCheckbox(
                        value: _applyMigrations,
                        label: const Text('Appliquer les Migrations'),
                        description:
                            const Text('V001 à V004 + charset transliteration'),
                        onChange: (v) => setState(() => _applyMigrations = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: FCheckbox(
                        value: _configureOdbc,
                        label: const Text('Configurer DSN ODBC Windows'),
                        description:
                            const Text('Enregistrer le DSN dans la Registry'),
                        onChange: (v) => setState(() => _configureOdbc = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerRight,
              child: FButton(
                onPress: _isCreating ? null : _createBlankDatabase,
                prefix: _isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                child: Text(_isCreating
                    ? 'Création en cours...'
                    : 'Générer la Base par Script SQL'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleCard() {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, size: 18, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Text(
                  'Journal d\'exécution & Logs en direct',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  tooltip: 'Effacer les logs',
                  onPressed: () => setState(() => _logs.clear()),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color color = const Color(0xFFE2E8F0);
                  if (log.startsWith('✓')) color = const Color(0xFF4ADE80);
                  if (log.startsWith('⚠️')) color = const Color(0xFFFBBF24);
                  if (log.startsWith('❌')) color = const Color(0xFFF87171);
                  if (log.startsWith('🎉')) color = const Color(0xFF60A5FA);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
