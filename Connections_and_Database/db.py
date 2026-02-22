import pyodbc

# =========================================================
# Database configuration
# =========================================================

DRIVER = "ODBC Driver 17 for SQL Server"
SERVER = r"LAPTOP-P881SO0E\MSSQLSERVER01"
DATABASE = "SRMS_DB"

CONNECTION_STRING = (
    f"DRIVER={{{DRIVER}}};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    f"Trusted_Connection=yes;"
)


# =========================================================
# Custom Exception
# =========================================================

class DbError(Exception):
    """Clean database exception for UI handling."""
    pass


# =========================================================
# Connection Helper
# =========================================================

def get_connection():
    """
    Create and return a SQL Server connection.
    """
    try:
        return pyodbc.connect(CONNECTION_STRING)
    except Exception as e:
        raise DbError(f"Database connection failed: {e}") from e


# =========================================================
# Internal Helpers
# =========================================================

def _normalize_row(columns, row):
    """
    Convert pyodbc row → dict
    Handles VARBINARY / memoryview safely.
    """
    result = {}
    for i, col in enumerate(columns):
        val = row[i]
        if isinstance(val, memoryview):
            val = val.tobytes()
        result[col] = val
    return result


def _build_sp_exec(sp_name, param_count):
    """
    Build EXEC sp_name ?,?,? dynamically.
    """
    if param_count == 0:
        return f"EXEC {sp_name}"
    placeholders = ", ".join("?" for _ in range(param_count))
    return f"EXEC {sp_name} {placeholders}"


# =========================================================
# SELECT Helpers
# =========================================================

def execute_query(query, params=None):
    """
    Execute SELECT returning multiple rows.
    Returns list[dict]
    """
    conn = get_connection()
    cursor = None

    try:
        cursor = conn.cursor()
        cursor.execute(query, params or ())
        columns = [c[0] for c in cursor.description] if cursor.description else []
        rows = cursor.fetchall()
        return [_normalize_row(columns, r) for r in rows]

    except Exception as e:
        raise DbError(f"Query failed: {e}") from e

    finally:
        if cursor:
            cursor.close()
        conn.close()


def execute_single_row(query, params=None):
    """
    Execute SELECT returning single row or None.
    """
    conn = get_connection()
    cursor = None

    try:
        cursor = conn.cursor()
        cursor.execute(query, params or ())
        row = cursor.fetchone()
        if not row:
            return None

        columns = [c[0] for c in cursor.description] if cursor.description else []
        return _normalize_row(columns, row)

    except Exception as e:
        raise DbError(f"Single-row query failed: {e}") from e

    finally:
        if cursor:
            cursor.close()
        conn.close()


def execute_scalar(query, params=None):
    """
    Execute SELECT returning single scalar value.
    """
    conn = get_connection()
    cursor = None

    try:
        cursor = conn.cursor()
        cursor.execute(query, params or ())
        row = cursor.fetchone()
        return row[0] if row else None

    except Exception as e:
        raise DbError(f"Scalar query failed: {e}") from e

    finally:
        if cursor:
            cursor.close()
        conn.close()


# =========================================================
# NON-QUERY Helper (INSERT / UPDATE / DELETE)
# =========================================================

def execute_non_query(query, params=None):
    """
    Execute non-select statement.
    Returns affected row count.
    """
    conn = get_connection()
    cursor = None

    try:
        cursor = conn.cursor()
        cursor.execute(query, params or ())
        affected = cursor.rowcount
        conn.commit()
        return affected

    except Exception as e:
        conn.rollback()
        raise DbError(f"Non-query failed: {e}") from e

    finally:
        if cursor:
            cursor.close()
        conn.close()


# =========================================================
# STORED PROCEDURE HELPERS (MAIN API)
# =========================================================

def call_sp_rows(sp_name, params=None):
    """
    Call SP that returns multiple rows.
    """
    params = tuple(params or ())
    query = _build_sp_exec(sp_name, len(params))
    return execute_query(query, params)


def call_sp_single_row(sp_name, params=None):
    """
    Call SP that returns single row.
    """
    params = tuple(params or ())
    query = _build_sp_exec(sp_name, len(params))
    return execute_single_row(query, params)


def call_sp_scalar(sp_name, params=None):
    """
    Call SP that returns scalar value.
    """
    params = tuple(params or ())
    query = _build_sp_exec(sp_name, len(params))
    return execute_scalar(query, params)


def call_sp_non_query(sp_name, params=None):
    """
    Call SP that performs INSERT / UPDATE / DELETE.
    Returns affected rows count.
    """
    params = tuple(params or ())
    query = _build_sp_exec(sp_name, len(params))
    return execute_non_query(query, params)
