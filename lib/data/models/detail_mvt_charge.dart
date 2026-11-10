class DetailMvtCharge {
  final String id;
  final String mouvementTresorerieId;
  final double montant;
  final String chargeId;
  final DateTime dateCreation;

  const DetailMvtCharge({
    required this.id,
    required this.mouvementTresorerieId,
    required this.montant,
    required this.chargeId,
    required this.dateCreation,
  });

  factory DetailMvtCharge.fromMap(Map<String, dynamic> row) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.parse(value.toString().trim());
    }

    double parseAmount(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().trim()) ?? 0;
    }

    return DetailMvtCharge(
      id: row['ID_DETAIL_MVT_CHARGE'].toString().trim(),
      mouvementTresorerieId: row['ID_MVT_TRESOR'].toString().trim(),
      montant: parseAmount(row['TRANCHE_MONTANT']),
      chargeId: row['ID_CHARGE'].toString().trim(),
      dateCreation: parseDate(row['DATE_CREAT']),
    );
  }
}
