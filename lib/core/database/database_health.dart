import 'firebird_connection.dart';

class DatabaseHealth {
  final FirebirdConnection _connectionManager;

  DatabaseHealth(this._connectionManager);

  Future<bool> checkHealth() async {
    if (!_connectionManager.isConnected) {
      return false;
    }
    
    try {
      final conn = _connectionManager.connection;
      if (conn != null) {
        // A simple query to check if the database responds
        final result = await conn.execute('SELECT 1 FROM RDB\$DATABASE');
        return result.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }
}
