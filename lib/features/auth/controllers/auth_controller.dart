import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';

class AuthController {
  final AuthRepository _authRepository;
  
  User? _currentUser;
  User? get currentUser => _currentUser;

  AuthController(this._authRepository);

  Future<bool> login(String username, String password) async {
    try {
      final user = await _authRepository.login(username, password);
      if (user != null) {
        _currentUser = user;
        return true;
      }
      return false;
    } catch (e) {
      // Log error (should use AppLogger ideally)
      print('Login error: \$e');
      rethrow;
    }
  }

  void logout() {
    _currentUser = null;
  }
}
