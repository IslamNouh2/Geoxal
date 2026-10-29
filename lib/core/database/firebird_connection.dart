import 'package:dart_odbc/dart_odbc.dart';
import '../../app/app_config.dart';

class FirebirdConnection {
  DartOdbc? _connection;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  DartOdbc? get connection => _connection;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      _connection = DartOdbc(dsn: AppConfig.databaseDataSource);
      await _connection!.connect(
        username: AppConfig.databaseUserId,
        password: AppConfig.databasePassword,
      );
      _isConnected = true;
      print('Successfully connected to Firebird Database (GEOXAL).');
    } catch (e) {
      _isConnected = false;
      print('Failed to connect to Firebird: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected || _connection == null) return;
    
    try {
      await _connection!.disconnect();
      _isConnected = false;
      print('Disconnected from Firebird Database.');
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }
}
