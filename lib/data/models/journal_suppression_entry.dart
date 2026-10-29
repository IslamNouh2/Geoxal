class JournalSuppressionEntry {
  final String id;
  final DateTime dateSuppression;
  final String? userSuppression;
  final String movId;
  final DateTime movDate;
  final double movMontant;
  final String movDesignation;
  final String? movSourceId;
  final String? movDestId;
  final String? movSourceCode;
  final String? movSourceLib;
  final String? movDestCode;
  final String? movDestLib;

  const JournalSuppressionEntry({
    required this.id,
    required this.dateSuppression,
    this.userSuppression,
    required this.movId,
    required this.movDate,
    required this.movMontant,
    required this.movDesignation,
    this.movSourceId,
    this.movDestId,
    this.movSourceCode,
    this.movSourceLib,
    this.movDestCode,
    this.movDestLib,
  });

  String get sourceDisplayName =>
      (movSourceCode != null && movSourceCode!.isNotEmpty)
          ? '$movSourceCode - ${movSourceLib ?? ''}'
          : (movSourceId ?? '—');

  String get destDisplayName =>
      (movDestCode != null && movDestCode!.isNotEmpty)
          ? '$movDestCode - ${movDestLib ?? ''}'
          : (movDestId ?? '—');

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  String get formattedDateSuppression =>
      '${_pad2(dateSuppression.day)}/${_pad2(dateSuppression.month)}/${dateSuppression.year} ${_pad2(dateSuppression.hour)}:${_pad2(dateSuppression.minute)}';

  String get formattedMovDate =>
      '${_pad2(movDate.day)}/${_pad2(movDate.month)}/${movDate.year}';
}
