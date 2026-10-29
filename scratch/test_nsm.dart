import 'package:geoxal/core/database/database.dart';
import 'package:geoxal/data/datasources/finance_datasource.dart';
import 'package:geoxal/data/models/compte.dart';

void main() async {
  print('=== STARTING NSM TEST SUITE ===');
  await Database.instance.init();
  final ds = FinanceDataSource(Database.instance);

  // 1. Initial State Check
  var accounts = await ds.getAccounts();
  print('Initial accounts count: ${accounts.length}');

  // Validate NSM consistency of current tree
  void validateTree(List<Compte> list) {
    for (final a in list) {
      assert(a.bg < a.bd, 'Invalid bounds for ${a.code}: BG ${a.bg} >= BD ${a.bd}');
      assert((a.bd - a.bg) % 2 == 1, 'Invalid width for ${a.code}: BD - BG must be odd');
    }
    // Check no duplicate BG or BD
    final allB = <int>{};
    for (final a in list) {
      assert(!allB.contains(a.bg), 'Duplicate BG: ${a.bg}');
      allB.add(a.bg);
      assert(!allB.contains(a.bd), 'Duplicate BD: ${a.bd}');
      allB.add(a.bd);
    }
    // Check sequence 1 .. 2N
    final expectedMax = list.length * 2;
    for (int i = 1; i <= expectedMax; i++) {
      assert(allB.contains(i), 'Missing boundary value $i in sequence 1..$expectedMax');
    }
  }

  validateTree(accounts);
  print('PASS: Initial tree passes 100% NSM boundary integrity check (1..2N contiguous).');

  // 2. Querying Ancestors, Descendants, Direct Children
  final caisseMobile = accounts.firstWhere((a) => a.code == '532');
  final ancestors = await ds.getAncestors(caisseMobile.id);
  print('Ancestors of 532 (Caisse mobile): ${ancestors.map((a) => '${a.code} (NIV ${a.niveau})').join(' -> ')}');
  assert(ancestors.length == 3); // 0 -> 5 -> 53

  final caisseEtBanque = accounts.firstWhere((a) => a.code == '5');
  final descendants = await ds.getDescendants(caisseEtBanque.id);
  print('Descendants of 5 (Caisse et banque): ${descendants.map((a) => a.code).join(', ')}');
  assert(descendants.length == 5); // 51, 512, 53, 531, 532

  final directChildren = await ds.getDirectChildren(caisseEtBanque.id);
  print('Direct children of 5: ${directChildren.map((a) => a.code).join(', ')}');
  assert(directChildren.length == 2); // 51, 53

  // 3. Create a Sub-Account (NSM Insert)
  // Let us create a new child under 53 (Caisse), e.g. 533 "Caisse annexe"
  final caisseParent = accounts.firstWhere((a) => a.code == '53');
  final newId = 'test-caisse-533-${DateTime.now().millisecondsSinceEpoch}';
  final newCompte = Compte(
    id: newId,
    code: '533',
    libelle: 'Caisse annexe',
    compteFr: 'caisse annexe',
    niveau: caisseParent.niveau + 1,
    bg: 0,
    bd: 0,
  );

  print('Creating new child compte 533 under 53...');
  await ds.createAccount(newCompte, parentBg: caisseParent.bg, parentBd: caisseParent.bd);

  accounts = await ds.getAccounts();
  validateTree(accounts);
  final inserted = accounts.firstWhere((a) => a.id == newId);
  print('PASS: Inserted 533 -> BG: ${inserted.bg}, BD: ${inserted.bd}, NIV: ${inserted.niveau}');
  assert(inserted.niveau == caisseParent.niveau + 1);
  assert(caisseParent.bg < inserted.bg && caisseParent.bd > inserted.bd);

  // 4. Update the Account
  print('Updating account 533...');
  final updatedCompte = Compte(
    id: newId,
    code: '533-UPD',
    libelle: 'Caisse annexe modifiee',
    compteFr: 'caisse annexe modifiee',
    niveau: inserted.niveau,
    bg: inserted.bg,
    bd: inserted.bd,
  );
  await ds.updateAccount(updatedCompte);
  final afterUpdate = (await ds.getAccounts()).firstWhere((a) => a.id == newId);
  assert(afterUpdate.code == '533-UPD');
  print('PASS: Account updated successfully: ${afterUpdate.displayName}');

  // 5. Move Account (NSM Move Subtree)
  // Let us move 533 from 53 (Caisse) to 51 (Banque)
  final banqueParent = accounts.firstWhere((a) => a.code == '51');
  print('Moving account 533 under 51 (Banque)...');
  await ds.moveAccount(newId, targetParentId: banqueParent.id);

  accounts = await ds.getAccounts();
  validateTree(accounts);
  final afterMove = accounts.firstWhere((a) => a.id == newId);
  final currentAncestors = await ds.getAncestors(newId);
  print('New ancestors of 533 after move: ${currentAncestors.map((a) => a.code).join(' -> ')}');
  assert(currentAncestors.any((a) => a.code == '51'));
  assert(!currentAncestors.any((a) => a.code == '53'));
  assert(afterMove.niveau == banqueParent.niveau + 1);
  print('PASS: Account moved successfully under 51 with valid boundaries (BG: ${afterMove.bg}, BD: ${afterMove.bd})');

  // 6. Delete Account (NSM Delete & Close Gap)
  print('Deleting test account 533...');
  await ds.deleteAccount(newId);

  accounts = await ds.getAccounts();
  validateTree(accounts);
  assert(!accounts.any((a) => a.id == newId));
  print('PASS: Account deleted and tree gap closed with 100% integrity!');

  await Database.instance.close();
  print('=== ALL NSM TESTS COMPLETED SUCCESSFULLY WITH 100% PASS ===');
}
