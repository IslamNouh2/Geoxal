/// Service to generate sequential invoice numbers based on a configurable format.
///
/// Supported format variables:
///   {YY}   — last 2 digits of the current year  (e.g. 26)
///   {YYYY} — full 4-digit year                  (e.g. 2026)
///   {MM}   — 2-digit current month              (e.g. 03)
///   {NNN}  — 3-digit zero-padded sequence number (e.g. 001)
///   {NNNN} — 4-digit zero-padded sequence number (e.g. 0001)
///
/// Example: format "FV{YY}/{NNNN}" → "FV26/0001", "FV26/0002", …
class InvoiceNumberService {
  InvoiceNumberService._();

  /// Generates the next invoice number for a given format pattern.
  ///
  /// [formatPattern] — the format string stored in APP_SETTINGS
  ///   (e.g. "FV{YY}/{NNNN}")
  /// [countByPrefix] — async callback that counts existing invoices whose
  ///   NUM_FACTURE starts with the computed prefix (e.g. "FV26/").
  ///   The callback receives the resolved prefix string and must return the count.
  static Future<String> generateNext({
    required String formatPattern,
    required Future<int> Function(String prefix) countByPrefix,
  }) async {
    final now = DateTime.now();

    // Resolve static date variables
    String resolved = _resolveStaticParts(formatPattern, now);

    // Determine padding width from sequence placeholder
    int padWidth = 4; // default
    String seqPlaceholder = '{NNNN}';
    if (resolved.contains('{NNNNN}')) {
      padWidth = 5;
      seqPlaceholder = '{NNNNN}';
    } else if (resolved.contains('{NNNN}')) {
      padWidth = 4;
      seqPlaceholder = '{NNNN}';
    } else if (resolved.contains('{NNN}')) {
      padWidth = 3;
      seqPlaceholder = '{NNN}';
    } else if (resolved.contains('{NN}')) {
      padWidth = 2;
      seqPlaceholder = '{NN}';
    }

    // Extract prefix (everything before the sequence placeholder)
    final seqIndex = resolved.indexOf(seqPlaceholder);
    final prefix = seqIndex >= 0 ? resolved.substring(0, seqIndex) : resolved;

    // Query existing count for this prefix
    final count = await countByPrefix(prefix);
    final nextSeq = (count + 1).toString().padLeft(padWidth, '0');

    // Build final number
    if (seqIndex >= 0) {
      final suffix = resolved.substring(seqIndex + seqPlaceholder.length);
      return '$prefix$nextSeq$suffix';
    } else {
      // No sequence placeholder — just append
      return '$prefix$nextSeq';
    }
  }

  /// Resolves static date variables in a format pattern.
  static String _resolveStaticParts(String pattern, DateTime now) {
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    final mm = now.month.toString().padLeft(2, '0');

    return pattern
        .replaceAll('{YYYY}', yyyy)
        .replaceAll('{YY}', yy)
        .replaceAll('{MM}', mm);
  }

  /// Returns a live preview of what the next invoice number would look like,
  /// using sequence number 1 (for display purposes only).
  static String preview(String formatPattern) {
    final now = DateTime.now();
    String resolved = _resolveStaticParts(formatPattern, now);

    const placeholders = ['{NNNNN}', '{NNNN}', '{NNN}', '{NN}'];
    final pads = [5, 4, 3, 2];

    for (int i = 0; i < placeholders.length; i++) {
      if (resolved.contains(placeholders[i])) {
        return resolved.replaceAll(
          placeholders[i],
          '1'.padLeft(pads[i], '0'),
        );
      }
    }
    return '${resolved}0001'; // fallback
  }
}

