import 'package:geoxal/core/database/database.dart';

void main() async {
  await Database.instance.init();
  final r = await Database.instance.connection.connection!.execute('SELECT ID, CODE, LIBELLE, PARENT_ID, NIVEAU FROM COMPTES ORDER BY NIVEAU, CODE');
  print('Total accounts in DB: ${r.length}');
  for (var x in r) {
    print('${x['CODE'].toString().padRight(6)} | ${x['LIBELLE'].toString().padRight(25)} | parent: ${x['PARENT_ID']} | niv: ${x['NIVEAU']}');
  }
  await Database.instance.close();
}
