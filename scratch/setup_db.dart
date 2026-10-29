import 'package:geoxal/app/app_config.dart';
import 'package:geoxal/core/security/password_hasher.dart';
import 'package:dart_odbc/dart_odbc.dart';

void main() async {
  final dsn = AppConfig.databaseDataSource;
  final username = AppConfig.databaseUserId;
  final password = AppConfig.databasePassword;

  final odbc = DartOdbc(dsn: dsn);
  
  try {
    print('Connecting to Firebird...');
    await odbc.connect(username: username, password: password);
    print('Connected successfully.');

    // Try dropping table in case it exists with old schema
    try {
      await odbc.execute('DROP TABLE USERS');
      print('Old USERS table dropped.');
    } catch (_) {}

    try {
      await odbc.execute('''
        CREATE TABLE USERS (
          ID VARCHAR(36) NOT NULL PRIMARY KEY,
          USERNAME VARCHAR(50) NOT NULL UNIQUE,
          PASSWORD_HASH VARCHAR(255) NOT NULL,
          ROLE VARCHAR(50) DEFAULT 'USER' NOT NULL,
          IS_ACTIVE CHAR(1) DEFAULT 'O' NOT NULL,
          CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
          UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
        )
      ''');
      print('Table USERS created according to database.md.');
    } catch (e) {
      print('Failed to create USERS table: $e');
      return;
    }

    final adminId = '123e4567-e89b-12d3-a456-426614174000'; // Sample UUID
    final adminUsername = 'admin';
    final adminPasswordHash = PasswordHasher.hashPassword('admin@1234');

    print('Inserting admin user...');
    await odbc.execute(
      'INSERT INTO USERS (ID, USERNAME, PASSWORD_HASH, ROLE, IS_ACTIVE) VALUES (?, ?, ?, ?, ?)',
      params: [adminId, adminUsername, adminPasswordHash, 'ADMIN', 'O'],
    );
    print('Admin user created successfully!');
    
  } catch (e) {
    print('Error: $e');
  } finally {
    try {
      await odbc.disconnect();
    } catch (_) {}
  }
}
