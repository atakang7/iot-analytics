"""Transactional TimescaleDB access helpers.

Only SQL identifiers go through psycopg2.sql.Identifier; data is always bound.
"""
from contextlib import contextmanager

import psycopg2
from psycopg2 import sql
from psycopg2.extras import RealDictCursor, execute_values

from common.config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD


def get_connection():
    if not DB_PASSWORD:
        raise RuntimeError("DB_PASSWORD must be configured before opening a database connection")
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=10,
    )


@contextmanager
def get_cursor(dict_cursor=False):
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor if dict_cursor else None) as cursor:
            yield cursor
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def _identifiers(values):
    return sql.SQL(", ").join(sql.Identifier(value) for value in values)


def insert_one(table: str, data: dict):
    columns = list(data)
    statement = sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
        sql.Identifier(table),
        _identifiers(columns),
        sql.SQL(", ").join(sql.Placeholder() for _ in columns),
    )
    with get_cursor() as cursor:
        cursor.execute(statement, list(data.values()))


def insert_many(table: str, rows: list[dict]):
    if not rows:
        return
    columns = list(rows[0])
    statement = sql.SQL("INSERT INTO {} ({}) VALUES %s").format(
        sql.Identifier(table), _identifiers(columns)
    )
    with get_cursor() as cursor:
        execute_values(cursor, statement.as_string(cursor), [[row[c] for c in columns] for row in rows])


def upsert_one(table: str, data: dict, conflict_cols: list[str]):
    columns = list(data)
    update_cols = [column for column in columns if column not in conflict_cols]
    assignment = sql.SQL(", ").join(
        sql.SQL("{} = EXCLUDED.{}").format(sql.Identifier(c), sql.Identifier(c))
        for c in update_cols
    )
    action = (
        sql.SQL("DO UPDATE SET {}").format(assignment)
        if update_cols else sql.SQL("DO NOTHING")
    )
    statement = sql.SQL("INSERT INTO {} ({}) VALUES ({}) ON CONFLICT ({}) {}").format(
        sql.Identifier(table),
        _identifiers(columns),
        sql.SQL(", ").join(sql.Placeholder() for _ in columns),
        _identifiers(conflict_cols),
        action,
    )
    with get_cursor() as cursor:
        cursor.execute(statement, [data[c] for c in columns])


def query(statement: str, params: tuple = None) -> list[dict]:
    with get_cursor(dict_cursor=True) as cursor:
        cursor.execute(statement, params)
        return cursor.fetchall()


def execute(statement: str, params: tuple = None):
    with get_cursor() as cursor:
        cursor.execute(statement, params)
