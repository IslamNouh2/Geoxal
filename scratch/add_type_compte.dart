import 'package:geoxal/core/database/database.dart';

void main() async {
  await Database.instance.init();
  final conn = Database.instance.connection.connection!;
  try {
    await conn.execute('ALTER TABLE COMPTES ADD TYPE_COMPTE VARCHAR(30)');
    print('Successfully added TYPE_COMPTE column to COMPTES table.');
  } catch (e) {
    print('Column TYPE_COMPTE already exists or note: $e');
  }
  await Database.instance.close();
}
