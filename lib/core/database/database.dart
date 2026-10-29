import 'firebird_connection.dart';
import 'transaction_manager.dart';
import 'database_health.dart';

class Database {
  final FirebirdConnection connection;
  final TransactionManager transactionManager;
  final DatabaseHealth health;

  Database._({
    required this.connection,
    required this.transactionManager,
    required this.health,
  });

  static Database? _instance;

  static Database get instance {
    if (_instance == null) {
      final conn = FirebirdConnection();
      _instance = Database._(
        connection: conn,
        transactionManager: TransactionManager(conn),
        health: DatabaseHealth(conn),
      );
    }
    return _instance!;
  }

  Future<void> init() async {
    await connection.connect();
  }

  Future<void> close() async {
    await connection.disconnect();
  }
}
