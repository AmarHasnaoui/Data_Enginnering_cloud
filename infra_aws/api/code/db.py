import os
import psycopg2
from psycopg2.extras import RealDictCursor

# Connexion réutilisée entre les invocations Lambda (warm start)
_conn = None

def get_conn():
    global _conn
    try:
        if _conn is None or _conn.closed:
            raise Exception("reconnect")
        _conn.cursor().execute("SELECT 1")
    except Exception:
        _conn = psycopg2.connect(
            host=os.environ["GOLD_PG_HOST"],
            port=int(os.environ.get("GOLD_PG_PORT", 5432)),
            dbname=os.environ["GOLD_PG_DATABASE"],
            user=os.environ["GOLD_PG_USER"],
            password=os.environ["GOLD_PG_PASSWORD"],
            sslmode="require",
            connect_timeout=10,
        )
    return _conn


def query(sql: str, params: tuple = ()) -> list[dict]:
    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params)
        return [dict(row) for row in cur.fetchall()]
