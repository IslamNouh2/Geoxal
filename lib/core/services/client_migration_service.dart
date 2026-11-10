import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/database/database.dart';

class MigrationFileItem {
  final String version;
  final String filename;
  final String filePath;
  final bool isApplied;
  final String? appliedNotes;
  final int statementsCount;

  const MigrationFileItem({
    required this.version,
    required this.filename,
    required this.filePath,
    required this.isApplied,
    this.appliedNotes,
    required this.statementsCount,
  });
}

class MigrationSummary {
  final List<MigrationFileItem> migrations;
  final int appliedCount;
  final int pendingCount;
  final String databasePath;
  final String dsnName;

  const MigrationSummary({
    required this.migrations,
    required this.appliedCount,
    required this.pendingCount,
    required this.databasePath,
    required this.dsnName,
  });
}

class ClientMigrationService {
  /// Quick statement count without heavy regex or parsing
  static int countStatements(String raw) {
    int count = 0;
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed == '-- @statement' || trimmed == '--@statement') {
        count++;
      }
    }
    return count > 0 ? count : 1;
  }

  /// Whether a statement is a client-side / isql shell directive that should be ignored by ODBC
  static bool isShellDirective(String stmt) {
    final upper = stmt.toUpperCase().trim();
    if (upper == 'COMMIT' ||
        upper == 'EXIT' ||
        upper == 'QUIT' ||
        upper.startsWith('SET SQL DIALECT') ||
        upper.startsWith('SET NAMES') ||
        upper.startsWith('CONNECT ') ||
        upper.startsWith('DISCONNECT')) {
      return true;
    }
    return false;
  }

  /// Parse SQL statements safely separated by -- @statement or semicolon
  static List<String> parseStatements(String raw) {
    final marker = RegExp(r'^\s*--\s*@statement\s*$', multiLine: true);
    final commentOnly = RegExp(r'^(/\*[\s\S]*?\*/|--[^\n]*\n*|\s*)+$');

    List<String> rawStatements;
    if (marker.hasMatch(raw)) {
      rawStatements = raw.split(marker);
    } else {
      rawStatements = raw.split(';');
    }

    return rawStatements
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !commentOnly.hasMatch(s))
        .map((s) {
          if (s.endsWith(';')) {
            return s.substring(0, s.length - 1).trim();
          }
          return s;
        })
        .where((s) => s.isNotEmpty && !isShellDirective(s))
        .toList();
  }

  /// Scan migrations directory and database SCHEMA_MIGRATIONS table using Database.instance
  static Future<MigrationSummary> getMigrationSummary({
    String dsn = 'GEOXAL',
    String migrationsDir = 'database/migrations',
    void Function(String log)? onLog,
  }) async {
    final appliedVersions = <String, String>{};

    onLog?.call('🔍 Connexion à la base de données (SCHEMA_MIGRATIONS)...');

    try {
      if (!Database.instance.connection.isConnected) {
        await Database.instance.init();
      }

      final conn = Database.instance.connection.connection;
      if (conn != null) {
        final res = await conn.execute(
          'SELECT VERSION, SUCCESS, NOTES FROM SCHEMA_MIGRATIONS',
        );
        for (final row in res) {
          final ver = row['VERSION']?.toString().trim();
          final success = row['SUCCESS']?.toString().trim();
          final notes = row['NOTES']?.toString().trim() ?? '';
          if (ver != null && success == 'O') {
            appliedVersions[ver] = notes;
          }
        }
        onLog?.call('📋 ${appliedVersions.length} migration(s) déjà enregistrée(s).');
      }
    } catch (e) {
      onLog?.call('⚠️ Lecture SCHEMA_MIGRATIONS : $e');
      debugPrint('[ClientMigrationService] Error: $e');
    }

    // Read directory
    onLog?.call('📂 Lecture des fichiers SQL...');
    final dir = Directory(migrationsDir);
    final items = <MigrationFileItem>[];

    if (dir.existsSync()) {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      onLog?.call('📄 ${files.length} fichier(s) SQL trouvé(s).');

      for (final file in files) {
        final filename = file.uri.pathSegments.last;
        final versionName = filename.replaceAll('.sql', '');

        int stmtCount = 1;
        try {
          final raw = file.readAsStringSync();
          stmtCount = countStatements(raw);
        } catch (_) {}

        final isApplied = appliedVersions.containsKey(versionName);
        items.add(MigrationFileItem(
          version: versionName,
          filename: filename,
          filePath: file.path,
          isApplied: isApplied,
          appliedNotes: appliedVersions[versionName],
          statementsCount: stmtCount,
        ));
      }
    }

    final appliedCount = items.where((i) => i.isApplied).length;
    final pendingCount = items.where((i) => !i.isApplied).length;

    if (pendingCount > 0) {
      onLog?.call('⚠️ $pendingCount mise(s) à jour en attente.');
    } else {
      onLog?.call('✅ Base de données à jour.');
    }

    return MigrationSummary(
      migrations: items,
      appliedCount: appliedCount,
      pendingCount: pendingCount,
      databasePath: 'GEOXAL.FDB',
      dsnName: dsn,
    );
  }

  /// Create a timestamped backup copy of the client database
  static Future<String?> backupDatabase(String dbPath, {void Function(String msg)? onLog}) async {
    try {
      final file = File(dbPath);
      if (!await file.exists()) {
        onLog?.call('ℹ️ Fichier FDB introuvable à : $dbPath');
        return null;
      }

      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final backupPath = '${file.parent.path}\\${file.uri.pathSegments.last.replaceAll('.FDB', '')}_BACKUP_$dateStr.FDB';

      onLog?.call('💾 Création de la copie de sauvegarde : $backupPath');
      await file.copy(backupPath);
      onLog?.call('✅ Sauvegarde créée avec succès.');
      return backupPath;
    } catch (e) {
      onLog?.call('⚠️ Erreur lors de la sauvegarde : $e');
      return null;
    }
  }

  /// Apply all pending migrations sequentially using the shared Database connection
  static Future<bool> applyPendingMigrations({
    String dsn = 'GEOXAL',
    bool createBackup = true,
    void Function(String log)? onLog,
    void Function(double progress)? onProgress,
  }) async {
    final summary = await getMigrationSummary(dsn: dsn, onLog: onLog);
    final pending = summary.migrations.where((m) => !m.isApplied).toList();

    if (pending.isEmpty) {
      onLog?.call('✨ Aucune migration en attente. Votre base de données est déjà à jour !');
      onProgress?.call(1.0);
      return true;
    }

    onLog?.call('\n🚀 DÉMARRAGE DE LA MIGRATION (${pending.length} script(s) en attente)');

    if (createBackup && summary.databasePath.isNotEmpty) {
      await backupDatabase(summary.databasePath, onLog: onLog);
    }

    try {
      if (!Database.instance.connection.isConnected) {
        await Database.instance.init();
      }
      final conn = Database.instance.connection.connection;
      if (conn == null) {
        onLog?.call('❌ Impossible d\'obtenir la connexion active.');
        return false;
      }

      onLog?.call('🔗 Connexion active à Firebird vérifiée.');

      for (int i = 0; i < pending.length; i++) {
        final item = pending[i];
        onLog?.call('\n📂 [${i + 1}/${pending.length}] Exécution de ${item.filename}...');

        final file = File(item.filePath);
        final raw = await file.readAsString();
        final statements = parseStatements(raw);

        for (int s = 0; s < statements.length; s++) {
          final stmt = statements[s];
          final preview = stmt.replaceAll('\n', ' ');
          final shortPreview = preview.length > 70 ? '${preview.substring(0, 70)}...' : preview;

          if (isShellDirective(stmt)) {
            onLog?.call('   ✓ [${s + 1}/${statements.length}] $shortPreview (Directive ignorée)');
            continue;
          }

          try {
            await conn.execute(stmt);
            onLog?.call('   ✓ [${s + 1}/${statements.length}] $shortPreview');
          } catch (e) {
            final errStr = e.toString();
            final isAlreadyExists = errStr.contains('already exists') ||
                errStr.contains('violation of PRIMARY or UNIQUE KEY') ||
                errStr.contains('-607') ||
                errStr.contains('-803');

            if (isAlreadyExists) {
              onLog?.call('   ⚠️ Déjà existant / Ignoré [${s + 1}/${statements.length}] : $shortPreview');
            } else {
              onLog?.call('   ❌ ERREUR SQL [${s + 1}/${statements.length}] : $shortPreview');
              onLog?.call('      Détail de l\'erreur : $errStr');
              return false;
            }
          }
        }

        // Ensure record in SCHEMA_MIGRATIONS
        try {
          final match = RegExp(r'^V0*(\d+)').firstMatch(item.version);
          final id = match != null ? int.parse(match.group(1)!) : (100 + i + 1);

          await conn.execute(
            "INSERT INTO SCHEMA_MIGRATIONS (ID, VERSION, SUCCESS, NOTES) "
            "VALUES ($id, '${item.version}', 'O', 'Applied via Client Migration Manager')",
          );
          onLog?.call('📝 Enregistré dans SCHEMA_MIGRATIONS (ID: $id, Version: ${item.version})');
        } catch (e) {
          debugPrint('Error inserting schema migration record: $e');
        }

        onLog?.call('✅ Fichier ${item.filename} terminé avec succès !');
        onProgress?.call((i + 1) / pending.length);
      }

      onLog?.call('\n🎉 TOUTES LES MIGRATIONS ONT ÉTÉ APPLIQUÉES AVEC SUCCÈS !');
      return true;
    } catch (e) {
      onLog?.call('❌ Échec critique de la migration : $e');
      return false;
    }
  }
}
