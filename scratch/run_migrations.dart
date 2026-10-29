import 'dart:io';
import 'dart:math';

import 'package:dart_odbc/dart_odbc.dart';
import 'package:geoxal/app/app_config.dart';

/// One-off migration runner (same style as scratch/setup_db.dart).
/// Executes every statement of database/migrations/*.sql in filename order.
/// Run from the project root:  dart run scratch/run_migrations.dart
void main() async {
  final dir = Directory('database/migrations');
  if (!dir.existsSync()) {
    print('No database/migrations directory found.');
    return;
  }

  final files = dir
      .listSync()
      .whereType<File>()
      .toList()
    ..sort((a, b) => a.uri.path.compareTo(b.uri.path));

  if (files.isEmpty) {
    print('No migration files found.');
    return;
  }

  final odbc = DartOdbc(dsn: AppConfig.databaseDataSource);
  var failed = false;

  try {
    print('Connecting to Firebird...');
    await odbc.connect(
      username: AppConfig.databaseUserId,
      password: AppConfig.databasePassword,
    );
    print('Connected successfully.');

    for (final file in files) {
      final raw = file.readAsStringSync();
      final clean = raw.replaceAll(RegExp(r'--[^\n]*'), '');

      for (final rawStmt in clean.split(';')) {
        final stmt = rawStmt.trim();
        if (stmt.isEmpty) continue;

        final preview = stmt
            .replaceAll('\n', ' ')
            .substring(0, min(70, stmt.length));
        print('>> ${file.uri.pathSegments.last}: $preview');

        try {
          await odbc.execute(stmt);
        } catch (e) {
          print('   FAILED: $e');
          failed = true;
          break;
        }
      }
      if (failed) break;
    }
  } finally {
    try {
      await odbc.disconnect();
    } catch (_) {}
  }

  print(failed ? 'Migration FAILED.' : 'All migrations executed.');
}
