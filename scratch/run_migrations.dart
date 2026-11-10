import 'dart:io';
import 'dart:math';

import 'package:dart_odbc/dart_odbc.dart';
import 'package:geoxal/app/app_config.dart';

/// Executes SQL statements separated by -- @statement.
/// Important: Never split Firebird trigger bodies by semicolons.
List<String> parseMigrationStatements(String raw) {
  final marker = RegExp(r'^\s*--\s*@statement\s*$', multiLine: true);

  if (!marker.hasMatch(raw)) {
    throw FormatException(
      'Missing -- @statement separators. '
      'Refusing unsafe semicolon splitting.',
    );
  }

  return raw
      .split(marker)
      .map((statement) => statement.trim())
      .where((statement) => statement.isNotEmpty)
      .map((statement) {
        // Remove only the final semicolon, not internal ones.
        if (statement.endsWith(';')) {
          return statement.substring(0, statement.length - 1).trim();
        }
        return statement;
      })
      .where((statement) => statement.isNotEmpty)
      .toList();
}

Future<void> main() async {
  final dir = Directory('database/migrations/valid');

  if (!dir.existsSync()) {
    print('ERROR: database/migrations/valid not found.');
    exitCode = 1;
    return;
  }

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    print('No SQL migration files found.');
    return;
  }

  final odbc = DartOdbc(dsn: AppConfig.databaseDataSource);

  var connected = false;
  var failed = false;

  try {
    print('Connecting to Firebird...');

    await odbc.connect(
      username: AppConfig.databaseUserId,
      password: AppConfig.databasePassword,
    );

    connected = true;
    print('Connected successfully.');

    for (final file in files) {
      final filename = file.uri.pathSegments.last;
      final raw = file.readAsStringSync();

      print('\n========================================');
      print('File: $filename');
      print('========================================');

      final statements = parseMigrationStatements(raw);

      print('Statements found: ${statements.length}');

      for (var i = 0; i < statements.length; i++) {
        final stmt = statements[i];

        final preview = stmt
            .replaceAll('\n', ' ')
            .substring(0, min(100, stmt.length));

        print('[$filename] ${i + 1}/${statements.length}:');
        print('  $preview');

        try {
          // Send each complete statement, including full trigger bodies.
          await odbc.execute(stmt);
          print('  OK');
        } catch (e) {
          print('  FAILED: $e');
          failed = true;
          break;
        }
      }

      if (failed) {
        print('\nStopped after the first failed statement.');
        break;
      }
    }
  } catch (e, stack) {
    print('\nMIGRATION RUNNER FAILED');
    print(e);
    print(stack);
    failed = true;
  } finally {
    if (connected) {
      try {
        await odbc.disconnect();
      } catch (e) {
        print('Disconnect warning: $e');
      }
    }
  }

  if (failed) {
    print('\nMigration FAILED.');
    print('Check the database before attempting to rerun.');
    exitCode = 1;
  } else {
    print('\nAll SQL files processed successfully.');
  }
}
