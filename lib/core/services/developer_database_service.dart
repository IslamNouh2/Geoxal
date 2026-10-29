import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dart_odbc/dart_odbc.dart';
import '../../app/app_config.dart';

class DatabaseCreationResult {
  final bool success;
  final String message;
  final List<String> logs;

  const DatabaseCreationResult({
    required this.success,
    required this.message,
    required this.logs,
    
  });
}

class DeveloperDatabaseService {
  static const String defaultFbClientPath =
      r'C:\Program Files\Firebird\Firebird_2_5\bin\fbclient.dll';
  static const String defaultIsqlPath =
      r'C:\Program Files\Firebird\Firebird_2_5\bin\isql.exe';
  static const String defaultOdbcDriverPath =
      r'C:\WINDOWS\system32\OdbcFb.dll';

  /// Check system environment prerequisites
  static Future<Map<String, dynamic>> checkSystemStatus() async {
    final isqlExists = await File(defaultIsqlPath).exists();
    final fbClientExists = await File(defaultFbClientPath).exists();
    final odbcDriverExists = await File(defaultOdbcDriverPath).exists();

    // Check registry DSN for GEOXAL
    bool dsnExists = false;
    String currentDbPath = '';
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r"(Get-ItemProperty 'HKCU:\SOFTWARE\ODBC\ODBC.INI\GEOXAL' -ErrorAction SilentlyContinue).Dbname"
      ]);
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        dsnExists = true;
        currentDbPath = res.stdout.toString().trim();
      }
    } catch (_) {}

    return {
      'isqlExists': isqlExists,
      'fbClientExists': fbClientExists,
      'odbcDriverExists': odbcDriverExists,
      'dsnExists': dsnExists,
      'currentDbPath': currentDbPath,
      'isqlPath': defaultIsqlPath,
      'fbClientPath': defaultFbClientPath,
      'odbcDriverPath': defaultOdbcDriverPath,
    };
  }

  /// Create a fresh Firebird Database, execute schema and migrations, and configure ODBC DSN.
  static Future<DatabaseCreationResult> createAndInitializeDatabase({
    required String fdbPath,
    required String dsnName,
    required String user,
    required String password,
    required String charset,
    required int pageSize,
    required bool configureOdbc,
    required bool applySchema,
    required bool applyMigrations,
    void Function(String log)? onLog,
  }) async {
    final logs = <String>[];
    void log(String msg) {
      logs.add(msg);
      if (onLog != null) {
        onLog(msg);
      }
      debugPrint('[DevDbService] $msg');
    }

    try {
      log('Starting database creation process...');
      final targetFile = File(fdbPath);
      final targetDir = targetFile.parent;

      // 1. Ensure target directory exists
      if (!await targetDir.exists()) {
        log('Creating directory: ${targetDir.path}');
        await targetDir.create(recursive: true);
      }

      if (await targetFile.exists()) {
        throw Exception(
            'Target database file already exists: $fdbPath. Please choose another path or backup/remove it first.');
      }

      // 2. Validate isql tool
      final isqlFile = File(defaultIsqlPath);
      if (!await isqlFile.exists()) {
        throw Exception(
            'Firebird isql utility not found at: $defaultIsqlPath. Please install Firebird 2.5.');
      }

      // 3. Create initial empty database via temporary ISQL script
      log('Generating CREATE DATABASE SQL script...');
      final tempDir = Directory.systemTemp;
      final createSqlFile = File(
          '${tempDir.path}\\create_db_${DateTime.now().millisecondsSinceEpoch}.sql');

      // Escaping backslashes for Firebird SQL path string
      final escapedDbPath = fdbPath.replaceAll(r'\', r'\\');

      final createSqlContent = StringBuffer();
      createSqlContent.writeln(
          "CREATE DATABASE '$escapedDbPath' USER '$user' PASSWORD '$password' PAGE_SIZE $pageSize DEFAULT CHARACTER SET $charset;");
      createSqlContent.writeln('COMMIT;');
      createSqlContent.writeln('EXIT;');

      await createSqlFile.writeAsString(createSqlContent.toString());
      log('Created temporary script at: ${createSqlFile.path}');

      log('Executing CREATE DATABASE via isql.exe...');
      final createResult = await Process.run(defaultIsqlPath, [
        '-q',
        '-i',
        createSqlFile.path,
      ]);

      try {
        await createSqlFile.delete();
      } catch (_) {}

      if (!await targetFile.exists()) {
        log('isql stderr: ${createResult.stderr}');
        log('isql stdout: ${createResult.stdout}');
        throw Exception(
            'Failed to create database file. Output: ${createResult.stderr.toString().isNotEmpty ? createResult.stderr : createResult.stdout}');
      }
      log('✓ Database file created successfully: $fdbPath');

      // 4. Apply schema_complete.sql if requested
      if (applySchema) {
        log('Applying database/schema_complete.sql...');
        final schemaFile = File('database/schema_complete.sql');
        if (await schemaFile.exists()) {
          final res = await _runIsqlScript(
            fdbPath: fdbPath,
            user: user,
            password: password,
            scriptFile: schemaFile,
            log: log,
          );
          if (!res) {
            log('⚠️ Warning: Some statements in schema_complete.sql reported notices/warnings.');
          } else {
            log('✓ Base schema applied successfully.');
          }
        } else {
          log('⚠️ Warning: database/schema_complete.sql not found at expected location.');
        }
      }

      // 5. Apply migrations if requested
      if (applyMigrations) {
        log('Applying migration scripts...');
        final migrationsDir = Directory('database/migrations');
        if (await migrationsDir.exists()) {
          final migrationFiles = migrationsDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.sql'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

          for (final mFile in migrationFiles) {
            log('Executing migration: ${mFile.path.split(Platform.pathSeparator).last}');
            await _runIsqlScript(
              fdbPath: fdbPath,
              user: user,
              password: password,
              scriptFile: mFile,
              log: log,
            );
          }
          log('✓ Migrations executed.');
        }
      }

      // 6. Configure Windows ODBC DSN
      if (configureOdbc) {
        log('Configuring Windows ODBC User DSN "$dsnName"...');
        final odbcSuccess = await configureOdbcDsn(
          dsnName: dsnName,
          fdbPath: fdbPath,
          charset: charset,
          log: log,
        );
        if (!odbcSuccess) {
          log('⚠️ Warning: Could not complete automatic ODBC DSN registration.');
        } else {
          log('✓ ODBC User DSN "$dsnName" configured successfully in Windows registry.');
        }
      }

      log('🎉 All operations completed successfully!');
      return DatabaseCreationResult(
        success: true,
        message: 'Base de données créée et configurée avec succès.',
        logs: logs,
      );
    } catch (e, st) {
      log('❌ ERROR: $e');
      debugPrint('$st');
      return DatabaseCreationResult(
        success: false,
        message: e.toString(),
        logs: logs,
      );
    }
  }

  /// Create a new database by copying an existing template database (GEOVIDE.FDB)
  /// and automatically configuring the Windows ODBC DSN.
  static Future<DatabaseCreationResult> createDatabaseFromTemplate({
    required String templatePath,
    String? targetDirectory,
    String? explicitTargetFilePath,
    required String dsnName,
    required String charset,
    bool configureOdbc = true,
    void Function(String log)? onLog,
  }) async {
    final logs = <String>[];
    void log(String msg) {
      logs.add(msg);
      if (onLog != null) {
        onLog(msg);
      }
      debugPrint('[DevDbService] $msg');
    }

    try {
      log('--- Création à partir du modèle template ---');
      final templateFile = File(templatePath);
      if (!await templateFile.exists()) {
        throw Exception(
            'Fichier modèle introuvable : "$templatePath".\nVeuillez vérifier le chemin du template GEOVIDE.FDB.');
      }

      // Compute final targetFilePath
      late final String targetFilePath;
      final cleanDsn = dsnName.trim();

      if (explicitTargetFilePath != null &&
          explicitTargetFilePath.trim().isNotEmpty) {
        targetFilePath = explicitTargetFilePath.trim();
        final targetDir = File(targetFilePath).parent;
        if (!await targetDir.exists()) {
          log('Création du dossier de destination : ${targetDir.path}');
          await targetDir.create(recursive: true);
        }
      } else if (targetDirectory != null && targetDirectory.trim().isNotEmpty) {
        final targetDir = Directory(targetDirectory.trim());
        if (!await targetDir.exists()) {
          log('Création du dossier de destination : ${targetDir.path}');
          await targetDir.create(recursive: true);
        }

        final targetFileName = cleanDsn.toUpperCase().endsWith('.FDB')
            ? cleanDsn
            : '$cleanDsn.FDB';

        targetFilePath = targetDir.path.endsWith(r'\') || targetDir.path.endsWith('/')
            ? '${targetDir.path}$targetFileName'
            : '${targetDir.path}\\$targetFileName';
      } else {
        throw Exception('Veuillez spécifier le chemin complet ou le dossier de la nouvelle base.');
      }

      final targetFile = File(targetFilePath);
      if (await targetFile.exists()) {
        throw Exception(
            'Le fichier cible existe déjà : "$targetFilePath".\nVeuillez choisir un autre nom de base ou un autre dossier.');
      }

      log('Copie du modèle "${templateFile.path}" vers "$targetFilePath"...');
      await templateFile.copy(targetFilePath);

      if (!await targetFile.exists()) {
        throw Exception('Échec de copie du fichier template vers "$targetFilePath".');
      }

      final fileSize = await targetFile.length();
      log('✓ Fichier copié avec succès (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} Mo).');

      if (configureOdbc) {
        log('Configuration de la source ODBC Windows (DSN) : "$cleanDsn"...');
        final odbcSuccess = await configureOdbcDsn(
          dsnName: cleanDsn,
          fdbPath: targetFilePath,
          charset: charset,
          log: log,
        );

        if (!odbcSuccess) {
          log('⚠️ Avertissement : Impossible d\'enregistrer le DSN ODBC dans la base de registre.');
        } else {
          log('✓ Source de données ODBC (DSN) "$cleanDsn" configurée avec succès !');
        }
      }

      log('🎉 Nouvelle base de données prête à l\'emploi !');
      return DatabaseCreationResult(
        success: true,
        message: 'Base de données "$cleanDsn" créée et configurée avec succès.',
        logs: logs,
      );
    } catch (e, st) {
      log('❌ ERREUR : $e');
      debugPrint('$st');
      return DatabaseCreationResult(
        success: false,
        message: e.toString(),
        logs: logs,
      );
    }
  }

  /// Run an SQL script file against the target database via isql
  static Future<bool> _runIsqlScript({
    required String fdbPath,
    required String user,
    required String password,
    required File scriptFile,
    required void Function(String) log,
  }) async {
    final scriptContent = await scriptFile.readAsString();
    final tempDir = Directory.systemTemp;
    final tempRunner = File(
        '${tempDir.path}\\run_script_${DateTime.now().millisecondsSinceEpoch}.sql');

    final escapedDbPath = fdbPath.replaceAll(r'\', r'\\');
    final runnerContent = StringBuffer();
    runnerContent.writeln(
        "CONNECT '$escapedDbPath' USER '$user' PASSWORD '$password';");
    runnerContent.writeln(scriptContent);
    runnerContent.writeln('COMMIT;');
    runnerContent.writeln('EXIT;');

    await tempRunner.writeAsString(runnerContent.toString());

    final res = await Process.run(defaultIsqlPath, [
      '-q',
      '-i',
      tempRunner.path,
    ]);

    try {
      await tempRunner.delete();
    } catch (_) {}

    final errStr = res.stderr.toString().trim();
    if (errStr.isNotEmpty) {
      log('isql info/warning: $errStr');
    }
    return res.exitCode == 0;
  }

  /// Configures or updates the User DSN in the Windows Registry
  static Future<bool> configureOdbcDsn({
    required String dsnName,
    required String fdbPath,
    required String charset,
    required void Function(String) log,
  }) async {
    try {
      final regScript = '''
\$dsn = "$dsnName"
\$db = "$fdbPath"
\$charset = "$charset"
\$driver = "$defaultOdbcDriverPath"
\$client = "$defaultFbClientPath"

# 1. Register in ODBC Data Sources
\$sourcesPath = "HKCU:\\SOFTWARE\\ODBC\\ODBC.INI\\ODBC Data Sources"
if (!(Test-Path \$sourcesPath)) {
    New-Item -Path \$sourcesPath -Force | Out-Null
}
Set-ItemProperty -Path \$sourcesPath -Name \$dsn -Value "Firebird/InterBase(r) driver"

# 2. Register DSN configuration details
\$dsnPath = "HKCU:\\SOFTWARE\\ODBC\\ODBC.INI\\\$dsn"
if (!(Test-Path \$dsnPath)) {
    New-Item -Path \$dsnPath -Force | Out-Null
}

Set-ItemProperty -Path \$dsnPath -Name "Driver" -Value \$driver
Set-ItemProperty -Path \$dsnPath -Name "Dbname" -Value \$db
Set-ItemProperty -Path \$dsnPath -Name "Client" -Value \$client
Set-ItemProperty -Path \$dsnPath -Name "User" -Value ""
Set-ItemProperty -Path \$dsnPath -Name "Role" -Value ""
Set-ItemProperty -Path \$dsnPath -Name "CharacterSet" -Value \$charset
Set-ItemProperty -Path \$dsnPath -Name "JdbcDriver" -Value "IscDbc"
Set-ItemProperty -Path \$dsnPath -Name "ReadOnly" -Value "N"
Set-ItemProperty -Path \$dsnPath -Name "NoWait" -Value "N"
Set-ItemProperty -Path \$dsnPath -Name "Dialect" -Value "3"
Set-ItemProperty -Path \$dsnPath -Name "QuotedIdentifier" -Value "Y"
Set-ItemProperty -Path \$dsnPath -Name "SensitiveIdentifier" -Value "N"
Set-ItemProperty -Path \$dsnPath -Name "AutoQuotedIdentifier" -Value "N"
Set-ItemProperty -Path \$dsnPath -Name "Password" -Value "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
''';

      final res = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        regScript,
      ]);

      if (res.exitCode != 0) {
        log('Registry update error: ${res.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      log('Failed to configure ODBC DSN: $e');
      return false;
    }
  }

  /// Test connection to the DSN using dart_odbc
  static Future<bool> testOdbcConnection(String dsnName) async {
    try {
      final conn = DartOdbc(dsn: dsnName);
      await conn.connect(
        username: AppConfig.databaseUserId,
        password: AppConfig.databasePassword,
      );
      await conn.disconnect();
      return true;
    } catch (e) {
      debugPrint('Test connection failed: $e');
      return false;
    }
  }

  /// Compares the schema of two Firebird databases (tables & columns)
  static Future<Map<String, dynamic>> compareDatabaseSchemas({
    required String activeDbPath,
    required String templateDbPath,
    void Function(String log)? onLog,
  }) async {
    void log(String msg) {
      if (onLog != null) onLog(msg);
      debugPrint('[SchemaCompare] $msg');
    }

    try {
      log('Analyse des structures de tables et colonnes...');
      final sActive = await _extractSchemaFields(activeDbPath);
      final sTemplate = await _extractSchemaFields(templateDbPath);

      final missingInTemplate = <String, List<String>>{};
      final missingInActive = <String, List<String>>{};
      final commonTables = <String>[];

      final allTables = {...sActive.keys, ...sTemplate.keys}.toList()..sort();

      for (final table in allTables) {
        final activeCols = sActive[table] ?? <String>{};
        final templateCols = sTemplate[table] ?? <String>{};

        if (!sTemplate.containsKey(table)) {
          missingInTemplate[table] = activeCols.toList()..sort();
          log('❌ Table manquante dans le modèle : $table');
        } else if (!sActive.containsKey(table)) {
          missingInActive[table] = templateCols.toList()..sort();
          log('⚠️ Table présente dans le modèle mais absente de la base active : $table');
        } else {
          commonTables.add(table);
          final diffTemplate = activeCols.difference(templateCols);
          final diffActive = templateCols.difference(activeCols);

          if (diffTemplate.isNotEmpty) {
            missingInTemplate[table] = diffTemplate.toList()..sort();
            log('❌ Table $table : colonnes manquantes dans le modèle -> $diffTemplate');
          }
          if (diffActive.isNotEmpty) {
            missingInActive[table] = diffActive.toList()..sort();
            log('⚠️ Table $table : colonnes en plus dans le modèle -> $diffActive');
          }
        }
      }

      final isSynced = missingInTemplate.isEmpty && missingInActive.isEmpty;
      if (isSynced) {
        log('✅ Les schémas de la base active et du modèle GEOVIDE sont 100% identiques !');
      }

      return {
        'isSynced': isSynced,
        'missingInTemplate': missingInTemplate,
        'missingInActive': missingInActive,
        'totalTables': allTables.length,
        'commonTablesCount': commonTables.length,
      };
    } catch (e) {
      log('Erreur lors de la comparaison des schémas : $e');
      return {
        'isSynced': false,
        'error': e.toString(),
        'missingInTemplate': <String, List<String>>{},
        'missingInActive': <String, List<String>>{},
      };
    }
  }

  static Future<Map<String, Set<String>>> _extractSchemaFields(String dbPath) async {
    final temp = File('${Directory.systemTemp.path}\\schema_${DateTime.now().microsecondsSinceEpoch}.sql');
    await temp.writeAsString('''
CONNECT '$dbPath' USER 'SYSDBA' PASSWORD 'masterkey';
SET HEADING OFF;
SELECT TRIM(R.RDB\$RELATION_NAME), TRIM(F.RDB\$FIELD_NAME)
FROM RDB\$RELATION_FIELDS F
JOIN RDB\$RELATIONS R ON F.RDB\$RELATION_NAME = R.RDB\$RELATION_NAME
WHERE R.RDB\$SYSTEM_FLAG = 0
ORDER BY 1, 2;
EXIT;
''');

    final res = await Process.run(defaultIsqlPath, ['-q', '-i', temp.path]);
    try { await temp.delete(); } catch (_) {}

    final map = <String, Set<String>>{};
    for (final line in res.stdout.toString().split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final table = parts[0];
        final field = parts[1];
        map.putIfAbsent(table, () => <String>{}).add(field);
      }
    }
    return map;
  }

  /// Executes an SQL migration script simultaneously on both active DB and GEOVIDE template DB.
  static Future<DatabaseCreationResult> applyDualMigration({
    required String activeDbPath,
    required String templateDbPath,
    required String sqlContent,
    String? migrationName,
    void Function(String log)? onLog,
  }) async {
    final logs = <String>[];
    void log(String msg) {
      logs.add(msg);
      if (onLog != null) onLog(msg);
      debugPrint('[DualMigration] $msg');
    }

    try {
      final label = migrationName ?? 'Migration personnalisée';
      log('--- Démarrage de la migration double : $label ---');

      final tempFile = File('${Directory.systemTemp.path}\\dual_mig_${DateTime.now().millisecondsSinceEpoch}.sql');
      await tempFile.writeAsString(sqlContent);

      // 1. Apply to active DB
      log('1. Application sur la base active : $activeDbPath');
      final okActive = await _runIsqlScript(
        fdbPath: activeDbPath,
        user: AppConfig.databaseUserId,
        password: AppConfig.databasePassword,
        scriptFile: tempFile,
        log: log,
      );

      // 2. Apply to template DB
      log('2. Application sur le modèle template : $templateDbPath');
      final okTemplate = await _runIsqlScript(
        fdbPath: templateDbPath,
        user: AppConfig.databaseUserId,
        password: AppConfig.databasePassword,
        scriptFile: tempFile,
        log: log,
      );

      try { await tempFile.delete(); } catch (_) {}

      final allOk = okActive && okTemplate;
      final msg = allOk
          ? 'Migration appliquée avec succès sur la base active et le modèle GEOVIDE !'
          : 'Migration terminée avec des avertissements (vérifiez les logs ci-dessous).';

      log(allOk ? '🎉 $msg' : '⚠️ $msg');
      return DatabaseCreationResult(
        success: allOk,
        message: msg,
        logs: logs,
      );
    } catch (e) {
      log('❌ Erreur lors de la double migration : $e');
      return DatabaseCreationResult(
        success: false,
        message: e.toString(),
        logs: logs,
      );
    }
  }
}

