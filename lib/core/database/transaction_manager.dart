import 'package:dart_odbc/dart_odbc.dart';
import 'firebird_connection.dart';

class TransactionManager {
  final FirebirdConnection _connectionManager;

  TransactionManager(this._connectionManager);

  // Executes a block of operations within a transaction.
  // Rolls back if an exception occurs, otherwise commits.
  Future<T> runInTransaction<T>(Future<T> Function(DartOdbc connection) action) async {
    final conn = _connectionManager.connection;
    if (conn == null || !_connectionManager.isConnected) {
      throw Exception('Cannot start transaction: No active database connection.');
    }

    try {
      await conn.execute('SET TRANSACTION');
      final result = await action(conn);
      await conn.execute('COMMIT');
      return result;
    } catch (e) {
      await conn.execute('ROLLBACK');
      print('Transaction rolled back due to error: $e');
      rethrow;
    }
  }
}
