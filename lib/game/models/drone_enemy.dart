import 'dart:math' as math;
import 'package:flutter/material.dart';

enum DroneType { normal, armored, explosive, boss }

class DroneEnemy {
  Offset position;
  Offset velocity;
  final double width;
  final double height;
  int health;
  final int maxHealth;
  double shootCooldown;
  bool isDestroyed;
  final DroneType type;

  // For boss hover
  double _timeElapsed = 0.0;
  final double initialY;

  DroneEnemy({
    required this.position,
    required this.type,
    required this.velocity,
    this.width = 44.0,
    this.height = 36.0,
    required this.health,
    this.shootCooldown = 3.0,
    this.isDestroyed = false,
  })  : maxHealth = health,
        initialY = position.dy;

  void update(double deltaTime, double screenWidth) {
    _timeElapsed += deltaTime;

    switch (type) {
      case DroneType.boss:
        // Boss moves horizontally and hovers vertically using sine wave
        position += Offset(velocity.dx * deltaTime, 0.0);
        position = Offset(
          position.dx,
          initialY + 20.0 * math.sin(_timeElapsed * 1.5),
        );
        break;
      default:
        // Regular drones drift horizontally and vertically
        position += Offset(velocity.dx * deltaTime, velocity.dy * deltaTime);
        break;
    }

    // Standard horizontal bounce boundaries
    double halfWidth = width / 2;
    if (position.dx - halfWidth < 8.0) {
      position = Offset(8.0 + halfWidth, position.dy);
      velocity = Offset(velocity.dx.abs(), velocity.dy); // Bounce right
    } else if (position.dx + halfWidth > screenWidth - 8.0) {
      position = Offset(screenWidth - 8.0 - halfWidth, position.dy);
      velocity = Offset(-velocity.dx.abs(), velocity.dy); // Bounce left
    }

    // Cooldown check for firing
    if (shootCooldown > 0) {
      shootCooldown -= deltaTime;
    }
  }

  Color get color {
    switch (type) {
      case DroneType.normal:
        return const Color(0xFF00FFCC); // Neon Cyan-Green
      case DroneType.armored:
        return const Color(0xFFFFCC00); // Neon Gold
      case DroneType.explosive:
        return const Color(0xFFFF3333); // Neon Red
      case DroneType.boss:
        return const Color(0xFFBD00FF); // Neon Purple
    }
  }

  Color get glowColor {
    switch (type) {
      case DroneType.normal:
        return const Color(0x9900FFCC);
      case DroneType.armored:
        return const Color(0x99FFCC00);
      case DroneType.explosive:
        return const Color(0x99FF3333);
      case DroneType.boss:
        return const Color(0x99BD00FF);
    }
  }

  Rect get rect => Rect.fromLTWH(
        position.dx - width / 2,
        position.dy - height / 2,
        width,
        height,
      );
}