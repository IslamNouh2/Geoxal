import 'dart:math';

/// Generates RFC 4122 version 4 UUIDs without external packages.
class Uuid {
  Uuid._();

  static final Random _random = Random.secure();

  static String v4() {
    final data = List<int>.generate(16, (_) => _random.nextInt(256));
    data[6] = (data[6] & 0x0f) | 0x40;
    data[8] = (data[8] & 0x3f) | 0x80;

    final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
