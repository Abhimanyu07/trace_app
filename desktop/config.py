import os
import random
import string
import uuid
import platform

APP_NAME = "TraceYourLyf"
VERSION = "0.2.0"

# Paths
DATA_DIR = os.path.join(os.path.expanduser("~"), ".traceyourlyf")
DB_PATH = os.path.join(DATA_DIR, "tracker.db")
DEVICE_ID_FILE = os.path.join(DATA_DIR, "device_id")

# API
API_HOST = "0.0.0.0"
API_PORT = 8742

# Tracker
POLL_INTERVAL_SECONDS = 2
MIN_RECORD_DURATION_SECONDS = 3
IDLE_TIMEOUT_SECONDS = 300  # 5 minutes

# Pairing
PAIR_CODE_LENGTH = 6

# Browsers (app names to detect URLs from)
BROWSER_APPS = {
    "Google Chrome",
    "Arc",
    "Safari",
    "Microsoft Edge",
    "Brave Browser",
    "Firefox",
    "Opera",
    "Vivaldi",
    "Chromium",
}

# IDE apps (to detect project/file info)
IDE_APPS = {
    "Code",  # VS Code shows as "Code"
    "Visual Studio Code",
    "Cursor",
    "WebStorm",
    "IntelliJ IDEA",
    "PyCharm",
    "Android Studio",
}


def generate_pair_code() -> str:
    return ''.join(random.choices(string.digits, k=PAIR_CODE_LENGTH))


def get_device_id() -> str:
    """Get or generate a persistent unique device ID."""
    if os.path.exists(DEVICE_ID_FILE):
        with open(DEVICE_ID_FILE, 'r') as f:
            return f.read().strip()
    device_id = str(uuid.uuid4())[:8]
    with open(DEVICE_ID_FILE, 'w') as f:
        f.write(device_id)
    return device_id


def get_device_name() -> str:
    return platform.node() or "Desktop"


# Ensure data dir exists
os.makedirs(DATA_DIR, exist_ok=True)
