import 'package:flutter/material.dart';

class LaserBullet {
  Offset position;
  final Offset velocity;
  final bool isEnemy;
  final double width;
  final double height;
  bool isDestroyed;
  final Color color;
  final Color glowColor;

  LaserBullet({
    required this.position,
    required this.velocity,
    required this.isEnemy,
    this.width = 4.0,
    this.height = 18.0,
    this.isDestroyed = false,
    this.color = const Color(0xFF00FFFF), // Cyan default
    this.glowColor = const Color(0x9900FFFF),
  });

  void update(double deltaTime) {
    position += velocity * deltaTime;
  }

  Rect get rect => Rect.fromLTWH(
        position.dx - width / 2,
        position.dy - height / 2,
        width,
        height,
      );
}