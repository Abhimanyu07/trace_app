import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Generates a colored icon for desktop applications.
/// Uses known app icons for popular apps, falls back to a letter-based icon.
class AppIconWidget extends StatelessWidget {
  final String appName;
  final double size;

  const AppIconWidget({super.key, required this.appName, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final knownIcon = _getKnownAppIcon();
    if (knownIcon != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: knownIcon.bgColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Icon(knownIcon.icon, color: knownIcon.bgColor, size: size * 0.55),
      );
    }

    // Letter-based fallback
    final letter = appName.isNotEmpty ? appName[0].toUpperCase() : '?';
    final color = _colorFromName(appName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: color,
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
            fontFamily: 'Gilroy',
          ),
        ),
      ),
    );
  }

  _KnownAppIcon? _getKnownAppIcon() {
    final name = appName.toLowerCase();
    if (name.contains('chrome')) {
      return _KnownAppIcon(Icons.language, const Color(0xFF4285F4));
    }
    if (name.contains('safari')) {
      return _KnownAppIcon(Icons.explore, const Color(0xFF006CFF));
    }
    if (name.contains('firefox')) {
      return _KnownAppIcon(Icons.local_fire_department, const Color(0xFFFF7139));
    }
    if (name.contains('arc')) {
      return _KnownAppIcon(Icons.language, const Color(0xFF6E5AE6));
    }
    if (name.contains('code') || name.contains('visual studio')) {
      return _KnownAppIcon(Icons.code, const Color(0xFF007ACC));
    }
    if (name.contains('cursor')) {
      return _KnownAppIcon(Icons.code, const Color(0xFF6366F1));
    }
    if (name.contains('terminal') || name.contains('iterm')) {
      return _KnownAppIcon(Icons.terminal, const Color(0xFF4CAF50));
    }
    if (name.contains('finder')) {
      return _KnownAppIcon(Icons.folder, const Color(0xFF1A73E8));
    }
    if (name.contains('slack')) {
      return _KnownAppIcon(Icons.tag, const Color(0xFF4A154B));
    }
    if (name.contains('whatsapp')) {
      return _KnownAppIcon(Icons.chat, const Color(0xFF25D366));
    }
    if (name.contains('telegram')) {
      return _KnownAppIcon(Icons.send, const Color(0xFF0088CC));
    }
    if (name.contains('discord')) {
      return _KnownAppIcon(Icons.headset_mic, const Color(0xFF5865F2));
    }
    if (name.contains('spotify')) {
      return _KnownAppIcon(Icons.music_note, const Color(0xFF1DB954));
    }
    if (name.contains('mail') || name.contains('outlook')) {
      return _KnownAppIcon(Icons.email, const Color(0xFF0078D4));
    }
    if (name.contains('notion')) {
      return _KnownAppIcon(Icons.note, const Color(0xFFFFFFFF));
    }
    if (name.contains('figma')) {
      return _KnownAppIcon(Icons.draw, const Color(0xFFF24E1E));
    }
    if (name.contains('keynote')) {
      return _KnownAppIcon(Icons.slideshow, const Color(0xFF0091FF));
    }
    if (name.contains('webex') || name.contains('zoom') || name.contains('teams')) {
      return _KnownAppIcon(Icons.videocam, const Color(0xFF2196F3));
    }
    if (name.contains('preview')) {
      return _KnownAppIcon(Icons.image, const Color(0xFF9C27B0));
    }
    if (name.contains('system preferences') || name.contains('settings')) {
      return _KnownAppIcon(Icons.settings, const Color(0xFF757575));
    }
    if (name.contains('android studio')) {
      return _KnownAppIcon(Icons.android, const Color(0xFF3DDC84));
    }
    if (name.contains('xcode')) {
      return _KnownAppIcon(Icons.build, const Color(0xFF147EFB));
    }
    return null;
  }

  Color _colorFromName(String name) {
    final colors = [
      AppColors.primary,
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
      const Color(0xFF06B6D4),
    ];
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }
}

class _KnownAppIcon {
  final IconData icon;
  final Color bgColor;
  _KnownAppIcon(this.icon, this.bgColor);
}
