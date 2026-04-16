import sqlite3
import time
from contextlib import contextmanager
from typing import Optional
from urllib.parse import urlparse
from ..config import DB_PATH


@contextmanager
def get_db():
    """Context manager for safe DB connections."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    conn = get_connection()

    # Create base tables
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS usage_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_name TEXT NOT NULL,
            window_title TEXT,
            url TEXT,
            project_path TEXT,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            duration_seconds INTEGER,
            created_at INTEGER DEFAULT (strftime('%s','now'))
        );

        CREATE TABLE IF NOT EXISTS app_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_name TEXT UNIQUE NOT NULL,
            category TEXT NOT NULL DEFAULT 'neutral',
            updated_at INTEGER DEFAULT (strftime('%s','now'))
        );

        CREATE TABLE IF NOT EXISTS paired_devices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            token TEXT UNIQUE NOT NULL,
            device_name TEXT NOT NULL,
            device_id TEXT,
            device_type TEXT DEFAULT 'phone',
            paired_at INTEGER DEFAULT (strftime('%s','now')),
            last_seen INTEGER,
            is_active INTEGER DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS device_config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_usage_start ON usage_records(start_time);
        CREATE INDEX IF NOT EXISTS idx_usage_app ON usage_records(app_name);
    """)

    # Migrations: add columns that may be missing from older versions
    _migrate_add_column(conn, "usage_records", "domain", "TEXT")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_usage_domain ON usage_records(domain)")

    conn.commit()
    conn.close()


def _migrate_add_column(conn, table: str, column: str, col_type: str):
    try:
        conn.execute(f"SELECT {column} FROM {table} LIMIT 1")
    except sqlite3.OperationalError:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}")


# --- Usage Records ---

def _extract_domain(url: Optional[str]) -> Optional[str]:
    if not url:
        return None
    try:
        parsed = urlparse(url)
        domain = parsed.netloc or parsed.path
        # Remove www. prefix
        if domain.startswith("www."):
            domain = domain[4:]
        return domain if domain else None
    except Exception:
        return None


def insert_usage_record(app_name: str, window_title: str = None,
                        url: str = None, project_path: str = None) -> int:
    domain = _extract_domain(url)
    with get_db() as conn:
        cursor = conn.execute(
            "INSERT INTO usage_records (app_name, window_title, url, domain, project_path, start_time) VALUES (?, ?, ?, ?, ?, ?)",
            (app_name, window_title, url, domain, project_path, int(time.time()))
        )
        return cursor.lastrowid


def close_usage_record(record_id: int):
    now = int(time.time())
    with get_db() as conn:
        conn.execute(
            "UPDATE usage_records SET end_time = ?, duration_seconds = (? - start_time) WHERE id = ? AND end_time IS NULL",
            (now, now, record_id)
        )


def get_usage_today() -> list:
    today_start = _today_start_ts()
    conn = get_connection()
    rows = conn.execute(
        """SELECT ur.*, COALESCE(ac.category, 'unclassified') as category
           FROM usage_records ur
           LEFT JOIN app_categories ac ON ur.app_name = ac.app_name
           WHERE ur.start_time >= ? AND ur.duration_seconds >= ?
           ORDER BY ur.start_time DESC""",
        (today_start, 3)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_usage_range(start_ts: int, end_ts: int) -> list:
    conn = get_connection()
    rows = conn.execute(
        """SELECT ur.*, COALESCE(ac.category, 'unclassified') as category
           FROM usage_records ur
           LEFT JOIN app_categories ac ON ur.app_name = ac.app_name
           WHERE ur.start_time >= ? AND ur.start_time < ? AND ur.duration_seconds >= ?
           ORDER BY ur.start_time DESC""",
        (start_ts, end_ts, 3)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_daily_summary(date_ts: int) -> dict:
    import datetime
    date = datetime.date.fromtimestamp(date_ts)
    day_end = _day_end_ts(date)
    conn = get_connection()
    rows = conn.execute(
        """SELECT ur.app_name, ur.domain,
                  SUM(ur.duration_seconds) as total_seconds,
                  COALESCE(ac.category, 'unclassified') as category
           FROM usage_records ur
           LEFT JOIN app_categories ac ON ur.app_name = ac.app_name
           WHERE ur.start_time >= ? AND ur.start_time < ? AND ur.duration_seconds >= ?
           GROUP BY ur.app_name
           ORDER BY total_seconds DESC""",
        (date_ts, day_end, 3)
    ).fetchall()

    # Also get domain breakdown for browsers
    domain_rows = conn.execute(
        """SELECT ur.domain,
                  SUM(ur.duration_seconds) as total_seconds,
                  COALESCE(ac.category, 'unclassified') as category
           FROM usage_records ur
           LEFT JOIN app_categories ac ON ur.app_name = ac.app_name
           WHERE ur.start_time >= ? AND ur.start_time < ?
                 AND ur.duration_seconds >= ? AND ur.domain IS NOT NULL
           GROUP BY ur.domain
           ORDER BY total_seconds DESC""",
        (date_ts, day_end, 3)
    ).fetchall()
    conn.close()

    apps = [dict(r) for r in rows]
    domains = [dict(r) for r in domain_rows]
    total = sum(a['total_seconds'] for a in apps)
    productive = sum(a['total_seconds'] for a in apps if a['category'] == 'productive')
    neutral = sum(a['total_seconds'] for a in apps if a['category'] == 'neutral')
    distraction = sum(a['total_seconds'] for a in apps if a['category'] == 'distraction')
    unclassified = sum(a['total_seconds'] for a in apps if a['category'] == 'unclassified')

    return {
        "date": date_ts,
        "total_seconds": total,
        "productive_seconds": productive,
        "neutral_seconds": neutral,
        "distraction_seconds": distraction,
        "unclassified_seconds": unclassified,
        "top_apps": apps[:10],
        "top_domains": domains[:10],
    }


def get_weekly_summary(week_start_ts: int) -> list:
    import datetime
    start_date = datetime.date.fromtimestamp(week_start_ts)
    summaries = []
    for i in range(7):
        day = start_date + datetime.timedelta(days=i)
        day_ts = _day_start_ts(day)
        summaries.append(get_daily_summary(day_ts))
    return summaries


def get_hourly_breakdown(date_ts: int) -> list:
    import datetime
    date = datetime.date.fromtimestamp(date_ts)
    base = datetime.datetime.combine(date, datetime.time.min)
    conn = get_connection()
    hours = []
    for h in range(24):
        hour_start = int((base + datetime.timedelta(hours=h)).timestamp())
        hour_end = int((base + datetime.timedelta(hours=h + 1)).timestamp())
        row = conn.execute(
            "SELECT COALESCE(SUM(duration_seconds), 0) as total FROM usage_records WHERE start_time >= ? AND start_time < ? AND duration_seconds >= ?",
            (hour_start, hour_end, 3)
        ).fetchone()
        hours.append({"hour": h, "total_seconds": row["total"]})
    conn.close()
    return hours


# --- App Categories ---

def get_all_apps() -> list:
    conn = get_connection()
    rows = conn.execute(
        """SELECT ur.app_name, ur.domain,
                  SUM(ur.duration_seconds) as total_seconds,
                  COALESCE(ac.category, 'unclassified') as category
           FROM usage_records ur
           LEFT JOIN app_categories ac ON ur.app_name = ac.app_name
           WHERE ur.duration_seconds >= ?
           GROUP BY ur.app_name
           ORDER BY total_seconds DESC""",
        (3,)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_all_domains() -> list:
    conn = get_connection()
    rows = conn.execute(
        """SELECT ur.domain, ur.app_name,
                  SUM(ur.duration_seconds) as total_seconds,
                  COALESCE(ac.category, 'unclassified') as category
           FROM usage_records ur
           LEFT JOIN app_categories ac ON ur.app_name = ac.app_name
           WHERE ur.duration_seconds >= ? AND ur.domain IS NOT NULL
           GROUP BY ur.domain
           ORDER BY total_seconds DESC""",
        (3,)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def set_app_category(app_name: str, category: str):
    conn = get_connection()
    conn.execute(
        """INSERT INTO app_categories (app_name, category, updated_at)
           VALUES (?, ?, ?)
           ON CONFLICT(app_name) DO UPDATE SET category = ?, updated_at = ?""",
        (app_name, category, int(time.time()), category, int(time.time()))
    )
    conn.commit()
    conn.close()


# --- Pairing (multi-device) ---

def set_pairing_code(code: str):
    conn = get_connection()
    conn.execute(
        "INSERT OR REPLACE INTO device_config (key, value) VALUES ('pair_code', ?)",
        (code,)
    )
    conn.commit()
    conn.close()


def get_pairing_code() -> Optional[str]:
    conn = get_connection()
    row = conn.execute("SELECT value FROM device_config WHERE key = 'pair_code'").fetchone()
    conn.close()
    return row["value"] if row else None


def add_paired_device(token: str, device_name: str, device_id: str = None,
                      device_type: str = 'phone') -> dict:
    conn = get_connection()
    conn.execute(
        """INSERT INTO paired_devices (token, device_name, device_id, device_type, paired_at, last_seen, is_active)
           VALUES (?, ?, ?, ?, ?, ?, 1)""",
        (token, device_name, device_id, device_type, int(time.time()), int(time.time()))
    )
    conn.commit()
    conn.close()
    return {"token": token, "device_name": device_name, "device_type": device_type}


def get_paired_devices() -> list:
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM paired_devices WHERE is_active = 1 ORDER BY paired_at DESC"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def remove_paired_device(token: str):
    conn = get_connection()
    conn.execute("UPDATE paired_devices SET is_active = 0 WHERE token = ?", (token,))
    conn.commit()
    conn.close()


def verify_token(token: str) -> bool:
    conn = get_connection()
    row = conn.execute(
        "SELECT * FROM paired_devices WHERE token = ? AND is_active = 1", (token,)
    ).fetchone()
    if row:
        conn.execute("UPDATE paired_devices SET last_seen = ? WHERE token = ?",
                      (int(time.time()), token))
        conn.commit()
    conn.close()
    return row is not None


# --- Helpers ---

def _day_start_ts(date: 'datetime.date') -> int:
    """Get start-of-day timestamp using proper calendar math (DST-safe)."""
    import datetime
    return int(datetime.datetime.combine(date, datetime.time.min).timestamp())


def _day_end_ts(date: 'datetime.date') -> int:
    """Get start-of-next-day timestamp (DST-safe)."""
    import datetime
    next_day = date + datetime.timedelta(days=1)
    return int(datetime.datetime.combine(next_day, datetime.time.min).timestamp())


def _today_start_ts() -> int:
    import datetime
    return _day_start_ts(datetime.date.today())


def get_current_record_id() -> Optional[int]:
    conn = get_connection()
    row = conn.execute(
        "SELECT id FROM usage_records WHERE end_time IS NULL ORDER BY id DESC LIMIT 1"
    ).fetchone()
    conn.close()
    return row["id"] if row else None
