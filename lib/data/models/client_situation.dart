class ClientSituationMovement {
  final String id;
  final DateTime date;
  final String type; // 'FACTURE' ou 'REGLEMENT'
  final String reference; // N° Facture ou N° Règlement
  final double debit; // Facture (ce que le client doit)
  final double credit; // Règlement (ce que le client a payé)
  final double soldeProgressif;
  final String modePaiement;
  final String? observation;

  const ClientSituationMovement({
    required this.id,
    required this.date,
    required this.type,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.soldeProgressif,
    required this.modePaiement,
    this.observation,
  });
}

class ClientSituation {
  final String tiersId;
  final String clientNom;
  final double totalFactures;
  final double totalReglements;
  final double solde; // totalFactures - totalReglements (positif = client nous doit)
  final List<ClientSituationMovement> mouvements;

  const ClientSituation({
    required this.tiersId,
    required this.clientNom,
    required this.totalFactures,
    required this.totalReglements,
    required this.solde,
    required this.mouvements,
  });
}

