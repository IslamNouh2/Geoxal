import pyodbc
conn = pyodbc.connect('DSN=GEOXAL;UID=SYSDBA;PWD=masterkey')
cursor = conn.cursor()

sql = """
      INSERT INTO CHARGES (
        ID_CHARGE,
        USER_ID,
        REF_CHARGE,
        DATE_CHARGE,
        COMPTE_ID,
        CATEGORIE_CHARGE,
        CURRENCY_CODE,
        TAUX_CHANGE,
        OK_AMORTISSABLE,
        MONTANT_CHARGE,
        MONTANT_REGLE,
        DESIGNATION,
        OBSERVATION,
        DATE_DEBUT_CONSOMMATION,
        DATE_FIN_CONSOMMATION,
        DATE_DEBUT_AMORTISSEMENT,
        DATE_FIN_AMORTISSEMENT,
        ID_MVT_TRESOR
      ) VALUES (
        'test-id-123',
        'SYSTEM',
        'CHG-2026-TEST',
        '2026-11-07 00:00:00',
        '1da58460-b65c-424c-9aab-0dec93e46b84',
        'SIMPLE',
        'DZD',
        1.0,
        'N',
        1500.0,
        0.0,
        'eau',
        NULL,
        '2026-09-01 00:00:00',
        '2026-12-31 00:00:00',
        NULL,
        NULL,
        NULL
      )
"""
try:
    cursor.execute(sql)
    conn.rollback()
    print("Direct insert with timestamp string worked")
except Exception as e:
    print("Direct insert with timestamp string failed:", e)

sql_date_only = """
      INSERT INTO CHARGES (
        ID_CHARGE,
        USER_ID,
        REF_CHARGE,
        DATE_CHARGE,
        COMPTE_ID,
        CATEGORIE_CHARGE,
        CURRENCY_CODE,
        TAUX_CHANGE,
        OK_AMORTISSABLE,
        MONTANT_CHARGE,
        MONTANT_REGLE,
        DESIGNATION,
        OBSERVATION,
        DATE_DEBUT_CONSOMMATION,
        DATE_FIN_CONSOMMATION,
        DATE_DEBUT_AMORTISSEMENT,
        DATE_FIN_AMORTISSEMENT,
        ID_MVT_TRESOR
      ) VALUES (
        'test-id-123',
        'SYSTEM',
        'CHG-2026-TEST',
        '2026-11-07',
        '1da58460-b65c-424c-9aab-0dec93e46b84',
        'SIMPLE',
        'DZD',
        1.0,
        'N',
        1500.0,
        0.0,
        'eau',
        NULL,
        '2026-09-01',
        '2026-12-31',
        NULL,
        NULL,
        NULL
      )
"""
try:
    cursor.execute(sql_date_only)
    conn.rollback()
    print("Direct insert with pure YYYY-MM-DD worked!")
except Exception as e:
    print("Direct insert with pure YYYY-MM-DD failed:", e)

conn.close()

