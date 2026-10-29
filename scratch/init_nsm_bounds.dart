import 'package:geoxal/core/database/database.dart';

class Node {
  final String id;
  final String code;
  final String libelle;
  final String? parentId;
  final List<Node> children = [];
  int bg = 0;
  int bd = 0;
  int niveau = 1;

  Node(this.id, this.code, this.libelle, this.parentId);
}

void main() async {
  await Database.instance.init();
  final db = Database.instance.connection.connection!;

  final rows = await db.execute('SELECT ID, CODE, LIBELLE, PARENT_ID FROM COMPTES');
  final nodes = <String, Node>{};
  for (final r in rows) {
    final id = r['ID'].toString();
    nodes[id] = Node(
      id,
      r['CODE'].toString().trim(),
      r['LIBELLE'].toString().trim(),
      r['PARENT_ID']?.toString().trim(),
    );
  }

  // Build tree
  Node? root;
  for (final n in nodes.values) {
    if (n.parentId == null || !nodes.containsKey(n.parentId)) {
      root = n;
    } else {
      nodes[n.parentId]!.children.add(n);
    }
  }

  // Sort children by code
  for (final n in nodes.values) {
    n.children.sort((a, b) => a.code.compareTo(b.code));
  }

  // Assign BG, BD, NIVEAU with DFS traversal
  int counter = 1;
  void dfs(Node current, int currentNiveau) {
    current.niveau = currentNiveau;
    current.bg = counter++;
    for (final child in current.children) {
      dfs(child, currentNiveau + 1);
    }
    current.bd = counter++;
  }

  if (root != null) {
    dfs(root, 1);
  }

  print('Updating COMPTES with valid NSM bounds (BG, BD, NIVEAU)...');
  for (final n in nodes.values) {
    await db.execute(
      'UPDATE COMPTES SET BG = ${n.bg}, BD = ${n.bd}, NIVEAU = ${n.niveau} WHERE ID = \'${n.id}\'',
    );
    print('Account ${n.code.padRight(6)} (${n.libelle.padRight(25)}) -> BG: ${n.bg.toString().padRight(3)} BD: ${n.bd.toString().padRight(3)} NIV: ${n.niveau}');
  }

  print('NSM bounds successfully initialized for all accounts!');
  await Database.instance.close();
}
