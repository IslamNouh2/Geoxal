import 'package:dart_odbc/dart_odbc.dart';
import 'package:geoxal/app/app_config.dart';
import 'package:geoxal/core/database/database.dart';
import 'package:geoxal/data/datasources/finance_datasource.dart';
import 'package:geoxal/data/datasources/tiers_datasource.dart';
import 'package:geoxal/data/datasources/vente_datasource.dart';
import 'package:geoxal/data/datasources/achat_datasource.dart';
import 'package:geoxal/data/repositories/finance_repository.dart';
import 'package:geoxal/data/repositories/tiers_repository.dart';
import 'package:geoxal/data/repositories/vente_repository.dart';
import 'package:geoxal/data/repositories/achat_repository.dart';

void main() async {
  print('=== STARTING INTEGRATION TEST ===');
  final db = Database.instance;
  await db.init();
  print('DB Connected successfully.');

  final financeRepo = FinanceRepository(FinanceDataSource(db));
  final tiersRepo = TiersRepository(TiersDataSource(db));
  final venteRepo = VenteRepository(VenteDataSource(db));
  final achatRepo = AchatRepository(AchatDataSource(db));

  // 1. Check Accounts
  final accounts = await financeRepo.getAccounts();
  print('Loaded ${accounts.length} accounts from tree.');
  assert(accounts.isNotEmpty);

  // Find leaf accounts (Caisse principale and Salaire)
  final caisse = accounts.firstWhere((a) => a.code == '531');
  final salaire = accounts.firstWhere((a) => a.code == '60');
  print('Source Account: ${caisse.displayName}');
  print('Dest Account: ${salaire.displayName}');

  // 2. Test Movement creation
  await financeRepo.createMovement(
    date: DateTime.now(),
    compteSourceId: caisse.id,
    compteDestId: salaire.id,
    montant: 25000.0,
    designation: 'Paiement salaire Ahmed (test)',
    userId: '123e4567-e89b-12d3-a456-426614174000',
  );
  print('Treasury Movement created successfully!');

  final movements = await financeRepo.getMovements();
  print('Movements count: ${movements.length}');
  final lastMov = movements.first;
  print(' - ${lastMov.sourceDisplayName} -> ${lastMov.destDisplayName} : ${lastMov.montant} DA (${lastMov.designation})');

  final stats = await financeRepo.getStats();
  print('Total Treasury Movements: ${stats.countMovements}, Total: ${stats.totalMontant} DA');

  // 3. Test Tiers
  final clients = await tiersRepo.getClients();
  final fournisseurs = await tiersRepo.getFournisseurs();
  print('Clients: ${clients.length}, Fournisseurs: ${fournisseurs.length}');
  assert(clients.isNotEmpty && fournisseurs.isNotEmpty);
  final client = clients.first;
  final fournisseur = fournisseurs.first;

  // 4. Test Facture Vente
  final nextFV = await venteRepo.getNextNumFacture();
  print('Next FV number: $nextFV');
  final fv = await venteRepo.createFactureVente(
    tiersId: client.id,
    numFacture: nextFV,
    dateFacture: DateTime.now(),
    montant: 45000.0,
    designation: 'Vente matériel informatique',
    userId: '123e4567-e89b-12d3-a456-426614174000',
  );
  print('Created Facture Vente: ${fv.numFacture} for ${fv.montant} DA');

  final sales = await venteRepo.getFacturesVente();
  print('Total Sales Invoices: ${sales.length}, Latest: ${sales.first.numFacture} (${sales.first.clientNom})');

  // 5. Test Facture Achat
  final nextFA = await achatRepo.getNextNumFacture();
  print('Next FA number: $nextFA');
  final fa = await achatRepo.createFactureAchat(
    tiersId: fournisseur.id,
    numFacture: nextFA,
    dateFacture: DateTime.now(),
    montant: 32000.0,
    designation: 'Achat consommables et fournitures',
    userId: '123e4567-e89b-12d3-a456-426614174000',
  );
  print('Created Facture Achat: ${fa.numFacture} for ${fa.montant} DA');

  final purchases = await achatRepo.getFacturesAchat();
  print('Total Purchase Invoices: ${purchases.length}, Latest: ${purchases.first.numFacture} (${purchases.first.fournisseurNom})');

  await db.close();
  print('=== ALL TESTS PASSED WITH 100% SUCCESS ===');
}
