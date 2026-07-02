import 'package:flutter/material.dart';

class Asteroid {
  Offset position;
  final Offset velocity;
  final double size;
  int health;
  final int maxHealth;
  bool isDestroyed;
  double rotationAngle;
  final double rotationSpeed;

  Asteroid({
    required this.position,
    required this.velocity,
    required this.size,
    required this.health,
    this.isDestroyed = false,
    this.rotationAngle = 0.0,
    required this.rotationSpeed,
  }) : maxHealth = health;

  void update(double deltaTime) {
    position += velocity * deltaTime;
    rotationAngle += rotationSpeed * deltaTime;
  }

  Rect get rect => Rect.fromLTWH(
        position.dx - size / 2,
        position.dy - size / 2,
        size,
        size,
      );
}
