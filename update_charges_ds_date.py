with open('lib/data/datasources/charges_data_source.dart', 'r', encoding='utf-8') as f:
    text = f.read()

target = """  String _sqlDate(dynamic value) {
    if (value == null) return 'NULL';
    if (value is DateTime) {
      return "'${toSqlDateTime(value)}'";
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) {
      return "'${toSqlDateTime(parsed)}'";
    }
    return 'NULL';
  }"""

replacement = """  String _sqlDate(dynamic value) {
    if (value == null) return 'NULL';
    if (value is DateTime) {
      return "'${toSqlDateOnly(value)}'";
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) {
      return "'${toSqlDateOnly(parsed)}'";
    }
    return 'NULL';
  }"""

text_norm = text.replace('\r\n', '\n')
assert target in text_norm
text_norm = text_norm.replace(target, replacement, 1)

# Also ensure dateDebut and dateFin filter in getCharges use toSqlDateOnly
old_filter = """    if (dateDebut != null) {
      conditions.add("C.DATE_CHARGE >= '${toSqlDateTime(dateDebut)}'");
    }

    if (dateFin != null) {
      conditions.add("C.DATE_CHARGE <= '${toSqlDateTime(dateFin.add(const Duration(days: 1)))}'");
    }"""

new_filter = """    if (dateDebut != null) {
      conditions.add("C.DATE_CHARGE >= '${toSqlDateOnly(dateDebut)}'");
    }

    if (dateFin != null) {
      conditions.add("C.DATE_CHARGE <= '${toSqlDateOnly(dateFin)}'");
    }"""

assert old_filter in text_norm
text_norm = text_norm.replace(old_filter, new_filter, 1)

old_summary_filter = """    if (dateDebut != null) {
      conditions.add("DATE_CHARGE >= '${toSqlDateTime(dateDebut)}'");
    }
    if (dateFin != null) {
      conditions.add("DATE_CHARGE <= '${toSqlDateTime(dateFin.add(const Duration(days: 1)))}'");
    }"""

new_summary_filter = """    if (dateDebut != null) {
      conditions.add("DATE_CHARGE >= '${toSqlDateOnly(dateDebut)}'");
    }
    if (dateFin != null) {
      conditions.add("DATE_CHARGE <= '${toSqlDateOnly(dateFin)}'");
    }"""

assert old_summary_filter in text_norm
text_norm = text_norm.replace(old_summary_filter, new_summary_filter, 1)

with open('lib/data/datasources/charges_data_source.dart', 'w', encoding='utf-8', newline='') as f:
    f.write(text_norm.replace('\n', '\r\n'))

print("Updated charges_data_source.dart to use toSqlDateOnly")

