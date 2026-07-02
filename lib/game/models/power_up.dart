import 'package:flutter/material.dart';

enum PowerUpType { tripleShot, shield, slowMotion, rapidFire, extraLife }

class PowerUp {
  Offset position;
  final PowerUpType type;
  final double speed = 120.0; // Falling speed (pixels per second)
  final double radius = 12.0;
  bool isCollected = false;
  bool isExpired = false;

  PowerUp({
    required this.position,
    required this.type,
  });

  void update(double deltaTime) {
    position += Offset(0, speed * deltaTime);
  }

  Color get color {
    switch (type) {
      case PowerUpType.tripleShot:
        return Colors.greenAccent;
      case PowerUpType.shield:
        return Colors.blueAccent;
      case PowerUpType.slowMotion:
        return Colors.cyanAccent;
      case PowerUpType.rapidFire:
        return Colors.amberAccent;
      case PowerUpType.extraLife:
        return Colors.pinkAccent;
    }
  }

  Color get glowColor {
    return color.withOpacity(0.6);
  }

  String get label {
    switch (type) {
      case PowerUpType.tripleShot:
        return "3X";
      case PowerUpType.shield:
        return "🛡️";
      case PowerUpType.slowMotion:
        return "⏰";
      case PowerUpType.rapidFire:
        return "⚡";
      case PowerUpType.extraLife:
        return "❤️";
    }
  }

  Rect getRect() {
    return Rect.fromCircle(center: position, radius: radius);
  }
}
