String _pad2(int v) => v.toString().padLeft(2, '0');
String _pad4(int v) => v.toString().padLeft(4, '0');

/// 'yyyy-MM-dd HH:mm:ss' for binding parameters as Firebird TIMESTAMP strings.
String toSqlDateTime(DateTime d) => '${_pad4(d.year)}-${_pad2(d.month)}-${_pad2(d.day)} 00:00:00';

/// 'dd/MM/yyyy' for display.
String formatDate(DateTime d) => '${_pad2(d.day)}/${_pad2(d.month)}/${d.year}';

/// 'dd/MM/yyyy HH:mm' for display.
String formatDateTime(DateTime d) =>
    '${_pad2(d.day)}/${_pad2(d.month)}/${d.year} ${_pad2(d.hour)}:${_pad2(d.minute)}';

/// Parses 'yyyy-MM-dd' (with optional time) from a filter field.
DateTime? tryParseFilterDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final parsed = DateTime.tryParse(s);
  if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
  return null;
}

/// 1234567.89 -> '1,234,567.89 DA'
String formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  final neg = fixed.startsWith('-');
  final abs = neg ? fixed.substring(1) : fixed;
  final parts = abs.split('.');
  var intStr = parts[0];

  final chunks = <String>[];
  while (intStr.length > 3) {
    chunks.insert(0, intStr.substring(intStr.length - 3));
    intStr = intStr.substring(0, intStr.length - 3);
  }
  chunks.insert(0, intStr);

  return '${neg ? '-' : ''}${chunks.join(',')}.${parts[1]} DA';
}

/// Corrects common mojibake characters returned when CP1252 / ISO-8859-1 strings are read as UTF-8 or vice-versa
String cleanMojibake(String input) {
  if (input.isEmpty) return input;
  return input
      .replaceAll('Ch\u00ED\u00A8que', 'Chèque')
      .replaceAll('Ch\u00ED\u00A8', 'Chè')
      .replaceAll('Ch\u00ED\u00A9que', 'Chèque')
      .replaceAll('ch\u00ED\u00A8que', 'chèque')
      .replaceAll('ch\u00ED\u00A8', 'chè')
      .replaceAll('ch\u00ED\u00A9', 'ché')
      .replaceAll('\u00CD\u00A9mis', 'émis')
      .replaceAll('\u00CD\u00A9', 'é')
      .replaceAll('\u00CD\u00A8', 'è')
      .replaceAll('\u00CD\u00AA', 'ê')
      .replaceAll('\u00CD\u00A0', 'à')
      .replaceAll('espl\u00ED\u00A8ces', 'espèces')
      .replaceAll('espl\u00ED\u00A8', 'espè')
      .replaceAll('esp\u00ED\u00A8ces', 'espèces')
      .replaceAll('r\u00ED\u00A8gle', 'règle')
      .replaceAll('R\u00ED\u00A8gle', 'Règle')
      .replaceAll('Bar\u00ED\u00A8me', 'Barème')
      .replaceAll('bar\u00ED\u00A8me', 'barème')
      .replaceAll('op\u00ED\u00A9ration', 'opération')
      .replaceAll('Op\u00ED\u00A9ration', 'Opération')
      .replaceAll('Ã©', 'é')
      .replaceAll('Ã¨', 'è')
      .replaceAll('Ãª', 'ê')
      .replaceAll('Ã ', 'à')
      .replaceAll('Ã§', 'ç')
      .replaceAll('Ã¹', 'ù')
      .replaceAll('Ã‰', 'É')
      .replaceAll('Ãˆ', 'È')
      .replaceAll('Remise Cheque', 'Remise Chèque')
      .replaceAll('remise cheque', 'remise chèque')
      .replaceAll('Paiement cheque', 'Paiement chèque')
      .replaceAll('paiement cheque', 'paiement chèque')
      .replaceAll('Versement de cheque', 'Versement de chèque')
      .replaceAll('versement de cheque', 'versement de chèque')
      .replaceAll('Versement especes', 'Versement espèces')
      .replaceAll('versement especes', 'versement espèces')
      .replaceAll('Cheque impaye', 'Chèque impayé')
      .replaceAll('cheque impaye', 'chèque impayé')
      .replaceAll('cheque emis', 'chèque émis')
      .replaceAll('Cheque emis', 'Chèque émis')
      .replaceAll('Virement emis', 'Virement émis')
      .replaceAll('virement emis', 'virement émis')
      .replaceAll('Virement recu', 'Virement reçu')
      .replaceAll('virement recu', 'virement reçu')
      .replaceAll('RTGS emis', 'RTGS émis')
      .replaceAll('RTGS recu', 'RTGS reçu')
      .replaceAll('teleservices', 'téléservices')
      .replaceAll('Bareme', 'Barème')
      .replaceAll('bareme', 'barème')
      .replaceAll('operation', 'opération')
      .replaceAll('Operation', 'Opération')
      .replaceAll('Regle', 'Règle')
      .replaceAll('regle', 'règle');
}

