#!/usr/bin/env python3
"""TraceYourLyf Desktop - Digital wellbeing tracker."""

import sys
import os
import threading
import logging
import signal
import time

# Add parent to path for package imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from desktop.config import API_HOST, API_PORT, generate_pair_code

PAIR_CODE_ROTATION_SECONDS = 2 * 60 * 60  # 2 hours

from desktop.db.database import init_db, set_pairing_code
from desktop.tracker.macos import tracker
from desktop.tray.tray_app import TrayApp
from desktop.utils.network import get_local_ip

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("traceyourlyf")


def run_api_server():
    """Run the FastAPI server in a thread."""
    import uvicorn
    from desktop.api.server import app
    uvicorn.run(app, host=API_HOST, port=API_PORT, log_level="warning")


def run_pair_code_rotation(tray: TrayApp):
    """Rotate pairing code every 2 hours."""
    while True:
        time.sleep(PAIR_CODE_ROTATION_SECONDS)
        new_code = generate_pair_code()
        set_pairing_code(new_code)
        tray.update_pair_code(new_code)
        logger.info(f"Pairing code rotated: {new_code}")


def main():
    # Initialize database
    logger.info("Initializing database...")
    init_db()

    # Generate pairing code
    pair_code = generate_pair_code()
    set_pairing_code(pair_code)
    local_ip = get_local_ip()

    logger.info(f"=== TraceYourLyf Desktop ===")
    logger.info(f"Pairing Code: {pair_code}")
    logger.info(f"API: http://{local_ip}:{API_PORT}")
    logger.info(f"Code rotates every 2 hours")
    logger.info(f"============================")

    # Start tracker
    tracker.start()

    # Start API server in background thread
    api_thread = threading.Thread(target=run_api_server, daemon=True)
    api_thread.start()

    # Define handlers
    def on_quit():
        logger.info("Shutting down...")
        tracker.stop()
        os._exit(0)

    def on_pause_toggle(is_paused):
        if is_paused:
            tracker.pause()
        else:
            tracker.resume()

    # Handle Ctrl+C
    signal.signal(signal.SIGINT, lambda s, f: on_quit())

    # Build tray
    tray = TrayApp(
        pair_code=pair_code,
        local_ip=local_ip,
        port=API_PORT,
        on_quit=on_quit,
        on_pause_toggle=on_pause_toggle,
    )

    # Start pair code rotation in background
    rotation_thread = threading.Thread(
        target=run_pair_code_rotation, args=(tray,), daemon=True
    )
    rotation_thread.start()

    # Run tray (blocks main thread)
    tray.run()


if __name__ == "__main__":
    main()
