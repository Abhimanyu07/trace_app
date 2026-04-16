import subprocess
import time
import threading
import logging
from typing import Optional
from ..config import BROWSER_APPS, IDE_APPS, POLL_INTERVAL_SECONDS
from ..db.database import insert_usage_record, close_usage_record

logger = logging.getLogger(__name__)


def get_active_window() -> Optional[dict]:
    """Get the currently active window info using AppleScript."""
    script = '''
    tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
        try
            set windowTitle to name of front window of first application process whose frontmost is true
        on error
            set windowTitle to ""
        end try
    end tell
    return frontApp & "|||" & windowTitle
    '''
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0:
            return None

        parts = result.stdout.strip().split("|||")
        if len(parts) != 2:
            return None

        app_name = parts[0].strip()
        window_title = parts[1].strip()

        info = {
            "app_name": app_name,
            "window_title": window_title,
            "url": None,
            "project_path": None,
        }

        # Extract URL for browser apps
        if app_name in BROWSER_APPS:
            url = _get_browser_url(app_name)
            if url:
                info["url"] = url

        # Extract project info for IDEs
        if app_name in IDE_APPS:
            info["project_path"] = _parse_ide_project(window_title)

        return info
    except (subprocess.TimeoutExpired, Exception) as e:
        logger.debug(f"Failed to get active window: {e}")
        return None


def _get_browser_url(app_name: str) -> Optional[str]:
    """Try to get the active tab URL from a browser."""
    # Map app process names to AppleScript application names
    app_script_names = {
        "Google Chrome": "Google Chrome",
        "Arc": "Arc",
        "Brave Browser": "Brave Browser",
        "Microsoft Edge": "Microsoft Edge",
        "Chromium": "Chromium",
        "Vivaldi": "Vivaldi",
        "Opera": "Opera",
    }

    if app_name == "Safari":
        script = 'tell application "Safari" to get URL of front document'
    elif app_name == "Firefox":
        # Firefox doesn't expose tabs via AppleScript; extract domain from window title
        return None
    elif app_name in app_script_names:
        script_name = app_script_names[app_name]
        script = f'tell application "{script_name}" to get URL of active tab of front window'
    else:
        return None

    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode == 0:
            url = result.stdout.strip()
            return url if url and url != "missing value" else None
    except (subprocess.TimeoutExpired, Exception):
        pass
    return None


def _parse_ide_project(window_title: str) -> Optional[str]:
    """Parse project/file info from IDE window title."""
    # VS Code format: "filename - foldername - Visual Studio Code"
    # Cursor format: "filename - foldername - Cursor"
    if " - " in window_title:
        parts = window_title.split(" - ")
        if len(parts) >= 2:
            return parts[-2].strip()  # folder/project name
    return None


class MacOSTracker:
    def __init__(self):
        self._running = False
        self._paused = False
        self._thread: Optional[threading.Thread] = None
        self._current_record_id: Optional[int] = None
        self._current_window: Optional[dict] = None
        self._last_change_time: float = 0

    def start(self):
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(target=self._track_loop, daemon=True)
        self._thread.start()
        logger.info("macOS tracker started")

    def stop(self):
        self._running = False
        self._close_current_record()
        logger.info("macOS tracker stopped")

    def pause(self):
        self._paused = True
        self._close_current_record()
        logger.info("macOS tracker paused")

    def resume(self):
        self._paused = False
        logger.info("macOS tracker resumed")

    @property
    def is_paused(self) -> bool:
        return self._paused

    def get_current(self) -> Optional[dict]:
        if self._paused:
            return None
        return self._current_window

    def _close_current_record(self):
        if self._current_record_id:
            close_usage_record(self._current_record_id)
            self._current_record_id = None
            self._current_window = None

    def _track_loop(self):
        while self._running:
            try:
                if not self._paused:
                    window = get_active_window()
                    if window:
                        self._process_window(window)
            except Exception as e:
                logger.error(f"Tracker error: {e}")
            time.sleep(POLL_INTERVAL_SECONDS)

    def _process_window(self, window: dict):
        # Check if window changed
        if self._current_window and self._is_same_window(window):
            return

        # Close previous record
        if self._current_record_id:
            close_usage_record(self._current_record_id)

        # Start new record
        self._current_window = window
        self._current_record_id = insert_usage_record(
            app_name=window["app_name"],
            window_title=window["window_title"],
            url=window.get("url"),
            project_path=window.get("project_path"),
        )
        self._last_change_time = time.time()
        logger.debug(f"Tracking: {window['app_name']} - {window.get('window_title', '')[:50]}")

    def _is_same_window(self, window: dict) -> bool:
        if not self._current_window:
            return False
        # Compare app, title, AND url (so browser tab switches are tracked)
        return (
            self._current_window["app_name"] == window["app_name"]
            and self._current_window["window_title"] == window["window_title"]
            and self._current_window.get("url") == window.get("url")
        )


# Global tracker instance
tracker = MacOSTracker()
