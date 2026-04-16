import pystray
from PIL import Image, ImageDraw
import logging

logger = logging.getLogger(__name__)


def _create_icon_image(paused: bool = False) -> Image.Image:
    """Create a simple icon for the menu bar. Orange when tracking, grey when paused."""
    size = 22
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    color = (120, 120, 120, 255) if paused else (232, 137, 29, 255)
    draw.ellipse([2, 2, size - 2, size - 2], fill=color)
    return img


class TrayApp:
    def __init__(self, pair_code: str, local_ip: str, port: int,
                 on_quit=None, on_pause_toggle=None):
        self._pair_code = pair_code
        self._local_ip = local_ip
        self._port = port
        self._on_quit = on_quit
        self._on_pause_toggle = on_pause_toggle
        self._icon = None
        self._is_paused = False
        self._status = "Tracking"

    def _build_menu(self):
        status_label = "Paused" if self._is_paused else "Tracking"
        pause_label = "Resume Tracking" if self._is_paused else "Pause Tracking"

        return pystray.Menu(
            pystray.MenuItem(f"Status: {status_label}", None, enabled=False),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(f"IP: {self._local_ip}:{self._port}", None, enabled=False),
            pystray.MenuItem(f"Pair Code: {self._pair_code}", None, enabled=False),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(pause_label, self._toggle_pause),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit TraceYourLyf", self._quit),
        )

    def _toggle_pause(self, icon, item):
        self._is_paused = not self._is_paused
        self._status = "Paused" if self._is_paused else "Tracking"
        logger.info(f"Tracker {'paused' if self._is_paused else 'resumed'}")

        # Update icon color and menu
        icon.icon = _create_icon_image(paused=self._is_paused)
        icon.menu = self._build_menu()

        if self._on_pause_toggle:
            self._on_pause_toggle(self._is_paused)

    def _quit(self, icon, item):
        logger.info("Quit requested from tray")
        icon.stop()
        if self._on_quit:
            self._on_quit()

    def update_status(self, status: str):
        self._status = status
        if self._icon:
            self._icon.menu = self._build_menu()

    @property
    def is_paused(self) -> bool:
        return self._is_paused

    def run(self):
        """Run the tray icon. This blocks the calling thread."""
        self._icon = pystray.Icon(
            "TraceYourLyf",
            _create_icon_image(),
            "TraceYourLyf",
            menu=self._build_menu(),
        )
        logger.info("Starting system tray icon")
        self._icon.run()
