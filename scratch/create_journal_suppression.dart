/// Run this once to create the JOURNAL_SUPPRESSION table in Firebird.
/// Usage: dart run scratch/create_journal_suppression.dart
library;

import 'dart:io';

import 'package:dart_odbc/dart_odbc.dart';

void main() async {
  print('Connecting to GEOXAL...');
  final odbc = DartOdbc(dsn: 'GEOXAL');
  await odbc.connect(username: 'SYSDBA', password: 'masterkey');
  print('Connected.');

  const sql = '''
    CREATE TABLE JOURNAL_SUPPRESSION (
      ID               VARCHAR(36)    NOT NULL,
      DATE_SUPPRESSION TIMESTAMP      NOT NULL,
      USER_SUPPRESSION VARCHAR(36),
      MOV_ID           VARCHAR(36)    NOT NULL,
      MOV_DATE         TIMESTAMP      NOT NULL,
      MOV_MONTANT      NUMERIC(15,2)  NOT NULL,
      MOV_DESIGNATION  VARCHAR(500),
      MOV_SOURCE_ID    VARCHAR(36),
      MOV_DEST_ID      VARCHAR(36),
      MOV_SOURCE_CODE  VARCHAR(50),
      MOV_SOURCE_LIB   VARCHAR(200),
      MOV_DEST_CODE    VARCHAR(50),
      MOV_DEST_LIB     VARCHAR(200),
      CONSTRAINT PK_JOURNAL_SUPP PRIMARY KEY (ID)
    )
  ''';

  try {
    await odbc.execute(sql);
    print('✅ Table JOURNAL_SUPPRESSION created successfully.');
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('already exists') || msg.contains('335544351') || msg.contains('table already exists')) {
      print('ℹ️  Table JOURNAL_SUPPRESSION already exists — skipping.');
    } else {
      print('❌ Error: $e');
      await odbc.disconnect();
      exit(1);
    }
  }

  await odbc.disconnect();
  print('Done.');
}
