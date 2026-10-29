import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  // Use SHA-256 for secure hashing (never store plain-text passwords)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}
