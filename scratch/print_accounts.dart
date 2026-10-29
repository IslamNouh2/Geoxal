import 'package:geoxal/core/database/database.dart';
import 'package:geoxal/data/datasources/finance_datasource.dart';

void main() async {
  await Database.instance.init();
  final list = await FinanceDataSource(Database.instance).getAccounts();
  print('Total accounts: ${list.length}');
  for (final a in list) {
    print('code: ${a.code.padRight(6)} | bg: ${a.bg.toString().padRight(4)} | bd: ${a.bd.toString().padRight(4)} | niv: ${a.niveau} | leaf: ${a.isLeaf.toString().padRight(5)} | ${a.displayName}');
  }
  await Database.instance.close();
}
