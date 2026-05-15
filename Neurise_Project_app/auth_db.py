import hashlib
import hmac
import os
import secrets
import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

import psycopg
from psycopg.types.json import Jsonb
from psycopg.rows import dict_row


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://neurise:neurise_password@localhost:5433/neurise",
)
SAMPLE_DURATION_SECONDS = float(os.getenv("POSE_SAMPLE_DURATION_SECONDS", "0.333"))


class DatabaseUnavailableError(Exception):
    pass


def _connect():
    try:
        return psycopg.connect(DATABASE_URL, row_factory=dict_row)
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error


def _hash_password(password: str, salt: str | None = None) -> str:
    if salt is None:
        salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 120_000)
    return f"pbkdf2_sha256${salt}${digest.hex()}"


def _verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, salt, digest = stored_hash.split("$", 2)
    except ValueError:
        return False

    if algorithm != "pbkdf2_sha256":
        return False

    candidate = _hash_password(password, salt)
    return hmac.compare_digest(candidate, stored_hash)


def _public_user(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "username": row["username"],
        "displayName": row["display_name"],
    }


def ensure_schema():
    with _connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id UUID PRIMARY KEY,
                    username TEXT UNIQUE NOT NULL,
                    display_name TEXT NOT NULL,
                    password_hash TEXT NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    last_login_at TIMESTAMPTZ
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS pose_samples (
                    id BIGSERIAL PRIMARY KEY,
                    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                    is_good BOOLEAN NOT NULL,
                    duration_seconds NUMERIC(8, 3) NOT NULL DEFAULT 0.333,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS pose_baselines (
                    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                    baseline_points JSONB NOT NULL,
                    sample_count INTEGER NOT NULL,
                    threshold NUMERIC(5, 3) NOT NULL DEFAULT 0.1,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS pose_calibration_samples (
                    id BIGSERIAL PRIMARY KEY,
                    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                    keypoints JSONB NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
        conn.commit()


def ensure_admin_user():
    ensure_schema()


def create_user(username: str, display_name: str, password: str) -> dict:
    ensure_schema()
    normalized_username = username.strip()

    if normalized_username.lower() == "admin":
        return {
            "ok": False,
            "status_code": 400,
            "error": "admin 계정은 앱 테스트용으로만 사용합니다. 다른 아이디를 입력해주세요.",
        }

    if not normalized_username:
        return {"ok": False, "status_code": 400, "error": "아이디를 입력해주세요."}

    if not display_name:
        return {"ok": False, "status_code": 400, "error": "이름을 입력해주세요."}

    if len(password) < 4:
        return {"ok": False, "status_code": 400, "error": "비밀번호는 4자 이상이어야 합니다."}

    user_id = uuid.uuid4()
    password_hash = _hash_password(password)

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO users (id, username, display_name, password_hash)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id, username, display_name
                    """,
                    (user_id, normalized_username, display_name, password_hash),
                )
                user = cur.fetchone()
            conn.commit()
    except psycopg.errors.UniqueViolation:
        return {"ok": False, "status_code": 409, "error": "이미 사용 중인 아이디입니다."}
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    return {"ok": True, "user": _public_user(user)}


def authenticate_user(username: str, password: str) -> dict | None:
    ensure_schema()
    normalized_username = username.strip()

    if normalized_username.lower() == "admin":
        return None

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, username, display_name, password_hash
                    FROM users
                    WHERE username = %s
                    """,
                    (normalized_username,),
                )
                user = cur.fetchone()

                if not user or not _verify_password(password, user["password_hash"]):
                    return None

                cur.execute(
                    "UPDATE users SET last_login_at = NOW() WHERE id = %s",
                    (user["id"],),
                )
            conn.commit()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    return _public_user(user)


def record_pose_sample(user_id: str | None, is_good: bool) -> None:
    if not user_id:
        return

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 FROM users WHERE id = %s", (parsed_user_id,))
                if cur.fetchone() is None:
                    return

                cur.execute(
                    """
                    INSERT INTO pose_samples (user_id, is_good, duration_seconds)
                    VALUES (%s, %s, %s)
                    """,
                    (parsed_user_id, is_good, SAMPLE_DURATION_SECONDS),
                )
            conn.commit()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error


def has_pose_baseline(user_id: str) -> bool:
    ensure_schema()

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return False

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 FROM pose_baselines WHERE user_id = %s", (parsed_user_id,))
                return cur.fetchone() is not None
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error


def get_pose_threshold(user_id: str) -> dict | None:
    ensure_schema()

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return None

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 FROM users WHERE id = %s", (parsed_user_id,))
                if cur.fetchone() is None:
                    return None

                cur.execute(
                    """
                    SELECT threshold
                    FROM pose_baselines
                    WHERE user_id = %s
                    """,
                    (parsed_user_id,),
                )
                row = cur.fetchone()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    threshold = float(row["threshold"]) if row else 0.1
    return {"threshold": threshold, "thresholdPercent": round(threshold * 100, 1)}


def update_pose_threshold(user_id: str, threshold_percent: float) -> dict | None:
    ensure_schema()

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return None

    clamped_percent = min(max(threshold_percent, 1.0), 100.0)
    threshold = clamped_percent / 100.0

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 FROM users WHERE id = %s", (parsed_user_id,))
                if cur.fetchone() is None:
                    return None

                cur.execute(
                    """
                    UPDATE pose_baselines
                    SET threshold = %s,
                        updated_at = NOW()
                    WHERE user_id = %s
                    """,
                    (threshold, parsed_user_id),
                )
            conn.commit()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    return {"threshold": threshold, "thresholdPercent": round(threshold * 100, 1)}


def reset_pose_baseline(user_id: str) -> dict | None:
    ensure_schema()

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return None

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 FROM users WHERE id = %s", (parsed_user_id,))
                if cur.fetchone() is None:
                    return None

                cur.execute("DELETE FROM pose_calibration_samples WHERE user_id = %s", (parsed_user_id,))
                cur.execute("DELETE FROM pose_baselines WHERE user_id = %s", (parsed_user_id,))
            conn.commit()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    return {"message": "Pose baseline reset"}


def start_pose_calibration(user_id: str) -> dict | None:
    ensure_schema()

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return None

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 FROM users WHERE id = %s", (parsed_user_id,))
                if cur.fetchone() is None:
                    return None

                cur.execute("DELETE FROM pose_calibration_samples WHERE user_id = %s", (parsed_user_id,))
            conn.commit()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    return {"message": "Pose calibration started"}


def record_calibration_sample(user_id: str | None, keypoints) -> None:
    if not user_id:
        return

    normalized = normalize_pose_points(keypoints)
    if normalized is None:
        return

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 FROM users WHERE id = %s", (parsed_user_id,))
                if cur.fetchone() is None:
                    return

                cur.execute(
                    """
                    INSERT INTO pose_calibration_samples (user_id, keypoints)
                    VALUES (%s, %s)
                    """,
                    (parsed_user_id, Jsonb(normalized)),
                )
            conn.commit()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error


def finish_pose_calibration(user_id: str) -> dict | None:
    ensure_schema()

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return None

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT keypoints
                    FROM pose_calibration_samples
                    WHERE user_id = %s
                    ORDER BY created_at
                    """,
                    (parsed_user_id,),
                )
                rows = cur.fetchall()

                if not rows:
                    return {"ok": False, "message": "보정에 사용할 pose point를 감지하지 못했습니다."}

                baseline = average_pose_points([row["keypoints"] for row in rows])
                cur.execute(
                    """
                    INSERT INTO pose_baselines (user_id, baseline_points, sample_count)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (user_id)
                    DO UPDATE SET
                        baseline_points = EXCLUDED.baseline_points,
                        sample_count = EXCLUDED.sample_count,
                        updated_at = NOW()
                    """,
                    (parsed_user_id, Jsonb(baseline), len(rows)),
                )
                cur.execute("DELETE FROM pose_calibration_samples WHERE user_id = %s", (parsed_user_id,))
            conn.commit()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    return {"ok": True, "message": "Pose calibration completed", "sampleCount": len(rows)}


def predict_bad_posture(user_id: str | None, keypoints, threshold: float = 0.1) -> tuple[bool, float | None]:
    if not user_id:
        return False, None

    normalized = normalize_pose_points(keypoints)
    if normalized is None:
        return True, None

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return False, None

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT baseline_points, threshold
                    FROM pose_baselines
                    WHERE user_id = %s
                    """,
                    (parsed_user_id,),
                )
                baseline_row = cur.fetchone()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    if baseline_row is None:
        return False, None

    baseline = baseline_row["baseline_points"]
    threshold_value = float(baseline_row["threshold"] or threshold)
    difference = mean_pose_difference(normalized, baseline)
    return difference >= threshold_value, difference


def normalize_pose_points(keypoints) -> list[list[float]] | None:
    import numpy as np

    points = np.asarray(keypoints, dtype=float)
    if points.size == 0:
        return None

    points = np.squeeze(points)
    if points.ndim != 2 or points.shape[1] < 2:
        return None

    points = points[:, :2]
    valid_mask = np.isfinite(points).all(axis=1)
    points = points[valid_mask]
    if len(points) < 3:
        return None

    center = points.mean(axis=0)
    centered = points - center
    span = np.ptp(points, axis=0)
    scale = float(max(span.max(), 1.0))
    normalized = centered / scale
    return normalized.round(6).tolist()


def average_pose_points(samples: list) -> list[list[float]]:
    import numpy as np

    arrays = [np.asarray(sample, dtype=float) for sample in samples]
    min_len = min(len(array) for array in arrays)
    stacked = np.stack([array[:min_len] for array in arrays], axis=0)
    return stacked.mean(axis=0).round(6).tolist()


def mean_pose_difference(current, baseline) -> float:
    import numpy as np

    current_array = np.asarray(current, dtype=float)
    baseline_array = np.asarray(baseline, dtype=float)
    point_count = min(len(current_array), len(baseline_array))
    if point_count == 0:
        return 1.0

    distances = np.linalg.norm(current_array[:point_count] - baseline_array[:point_count], axis=1)
    return float(distances.mean())


def get_dashboard(user_id: str) -> dict | None:
    ensure_schema()

    try:
        parsed_user_id = uuid.UUID(user_id)
    except ValueError:
        return None

    today = datetime.now(timezone.utc).date()
    start_day = today - timedelta(days=6)
    previous_start_day = today - timedelta(days=13)

    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, username, display_name
                    FROM users
                    WHERE id = %s
                    """,
                    (parsed_user_id,),
                )
                user = cur.fetchone()
                if user is None:
                    return None

                cur.execute(
                    """
                    SELECT
                        created_at::date AS sample_day,
                        SUM(duration_seconds) AS total_seconds,
                        SUM(CASE WHEN is_good THEN duration_seconds ELSE 0 END) AS good_seconds
                    FROM pose_samples
                    WHERE user_id = %s
                      AND created_at::date >= %s
                    GROUP BY sample_day
                    """,
                    (parsed_user_id, previous_start_day),
                )
                rows = cur.fetchall()
    except psycopg.Error as error:
        raise DatabaseUnavailableError(str(error)) from error

    seconds_by_day = defaultdict(lambda: {"total": 0.0, "good": 0.0})
    for row in rows:
        sample_day = row["sample_day"]
        if isinstance(sample_day, datetime):
            sample_day = sample_day.date()
        seconds_by_day[sample_day]["total"] = float(row["total_seconds"] or 0)
        seconds_by_day[sample_day]["good"] = float(row["good_seconds"] or 0)

    day_labels = ["월", "화", "수", "목", "금", "토", "일"]

    def minutes(seconds: float) -> int:
        if seconds <= 0:
            return 0
        return max(1, round(seconds / 60))

    logs = []
    for offset in range(7):
        current_day = start_day + timedelta(days=offset)
        totals = seconds_by_day[current_day]
        logs.append(
            {
                "day": day_labels[current_day.weekday()],
                "totalMinutes": minutes(totals["total"]),
                "goodPostureMinutes": minutes(totals["good"]),
            }
        )

    previous_week_total = 0
    for offset in range(7):
        current_day = previous_start_day + timedelta(days=offset)
        previous_week_total += minutes(seconds_by_day[current_day]["total"])

    latest_day_with_samples: date | None = None
    for sample_day, totals in seconds_by_day.items():
        if totals["total"] > 0 and (latest_day_with_samples is None or sample_day > latest_day_with_samples):
            latest_day_with_samples = sample_day

    last_totals = seconds_by_day[latest_day_with_samples] if latest_day_with_samples else {"total": 0, "good": 0}

    return {
        "userName": user["display_name"],
        "previousWeekTotalMinutes": previous_week_total,
        "logs": logs,
        "lastSessionTotalMinutes": minutes(last_totals["total"]),
        "lastSessionGoodMinutes": minutes(last_totals["good"]),
    }
