"""
Initialise les tables Gold dans l'instance Snowflake Postgres.
Variables d'environnement requises :
  GOLD_PG_HOST     : hostname de l'instance Snowflake Postgres
  GOLD_PG_USER     : utilisateur PostgreSQL
  GOLD_PG_PASSWORD : mot de passe
  GOLD_PG_DATABASE : nom de la base (ex: gold)
  GOLD_PG_PORT     : port (défaut 5432)
"""

import os
import glob
import psycopg2

conn = psycopg2.connect(
    host=os.environ['GOLD_PG_HOST'],
    port=int(os.environ.get('GOLD_PG_PORT', 5432)),
    dbname=os.environ['GOLD_PG_DATABASE'],
    user=os.environ['GOLD_PG_USER'],
    password=os.environ['GOLD_PG_PASSWORD'],
    sslmode='require',
)

cursor = conn.cursor()

for filepath in sorted(glob.glob('Snowflake/GOLD_DDL/*.sql')):
    with open(filepath, 'r', encoding='utf-8') as f:
        sql = f.read()

    print(f'[GOLD DDL] Exécution : {filepath}')
    cursor.execute(sql)
    print(f'[GOLD DDL] OK : {filepath}')

conn.commit()
cursor.close()
conn.close()

print('[GOLD DDL] Toutes les tables Gold initialisées.')
