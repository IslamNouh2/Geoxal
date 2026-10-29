import '../../../data/models/user.dart';

/// Holds the currently authenticated user for the app session.
/// In-memory only; cleared when the app restarts.
class Session {
  Session._();

  static User? _user;

  static User? get user => _user;

  static void setUser(User? user) => _user = user;

  static bool get isAuthenticated => _user != null;
}
