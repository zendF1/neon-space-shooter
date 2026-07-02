import 'package:flutter/material.dart';

enum WingmanSide { left, right }

class Wingman {
  final String id; // 'laser', 'ice', 'magnet'
  final WingmanSide side;
  Offset position;
  double shootCooldown = 0.0;

  Wingman({
    required this.id,
    required this.side,
    required this.position,
  });

  void update(double deltaTime, Offset spaceshipPos) {
    // Position target relative to spaceship wings
    double targetX = side == WingmanSide.left ? spaceshipPos.dx - 36.0 : spaceshipPos.dx + 36.0;
    double targetY = spaceshipPos.dy + 12.0;

    // Smooth LERP movement to lag behind slightly (feels more dynamic)
    position = Offset(
      position.dx + (targetX - position.dx) * 14.0 * deltaTime,
      position.dy + (targetY - position.dy) * 14.0 * deltaTime,
    );

    if (shootCooldown > 0) {
      shootCooldown -= deltaTime;
    }
  }

  Color get color {
    if (id == 'ice') return const Color(0xFF00E5FF); // Ice Cyan
    if (id == 'magnet') return const Color(0xFF00FF66); // Magnet Green
    return const Color(0xFFFF007F); // Laser Pink
  }
}
