import 'package:dart_odbc/dart_odbc.dart';
import 'package:geoxal/app/app_config.dart';
import 'package:geoxal/core/database/database.dart';
import 'package:geoxal/data/datasources/user_datasource.dart';
import 'package:geoxal/data/repositories/auth_repository.dart';

void main() async {
  print('Connecting to DB...');
  await Database.instance.init();
  print('Connected to DB.');

  final userDs = UserDataSource(Database.instance);
  final authRepo = AuthRepository(userDs);

  print('Authenticating admin / admin@1234 ...');
  try {
    final user = await authRepo.login('admin', 'admin@1234');
    print('User result: $user');
    if (user != null) {
      print('User ID: ${user.id}, Username: ${user.username}, Role: ${user.role}');
    } else {
      print('User is null! Let us inspect USERS table directly:');
      final conn = Database.instance.connection.connection;
      final rows = await conn!.execute('SELECT * FROM USERS');
      for (final r in rows) {
        print('ROW: $r');
      }
    }
  } catch (e, stack) {
    print('Exception during login: $e');
    print(stack);
  } finally {
    await Database.instance.close();
  }
}
