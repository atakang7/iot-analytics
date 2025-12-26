import psycopg2
from psycopg2.extras import RealDictCursor, execute_values
from contextlib import contextmanager
from common.config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD


def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )


@contextmanager
def get_cursor(dict_cursor=False):
    conn = get_connection()
    try:
        cursor = conn.cursor(cursor_factory=RealDictCursor if dict_cursor else None)
        yield cursor
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()
        conn.close()


def insert_one(table: str, data: dict):
    cols = ", ".join(data.keys())
    placeholders = ", ".join(["%s"] * len(data))
    sql = f"INSERT INTO {table} ({cols}) VALUES ({placeholders})"
    with get_cursor() as cur:
        cur.execute(sql, list(data.values()))


def insert_many(table: str, rows: list[dict]):
    if not rows:
        return
    cols = list(rows[0].keys())
    sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES %s"
    values = [[row[c] for c in cols] for row in rows]
    with get_cursor() as cur:
        execute_values(cur, sql, values)


def upsert_one(table: str, data: dict, conflict_cols: list[str]):
    cols = list(data.keys())
    placeholders = ", ".join(["%s"] * len(cols))
    update_cols = [c for c in cols if c not in conflict_cols]
    update_clause = ", ".join([f"{c} = EXCLUDED.{c}" for c in update_cols])
    sql = f"""
        INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders})
        ON CONFLICT ({', '.join(conflict_cols)}) DO UPDATE SET {update_clause}
    """
    with get_cursor() as cur:
        cur.execute(sql, list(data.values()))


def query(sql: str, params: tuple = None) -> list[dict]:
    with get_cursor(dict_cursor=True) as cur:
        cur.execute(sql, params)
        return cur.fetchall()


def execute(sql: str, params: tuple = None):
    with get_cursor() as cur:
        cur.execute(sql, params)
