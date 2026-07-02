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
  double slowTimer = 0.0; // Slow down status effect

  // For trajectories
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

  void update(double deltaTime, double screenWidth, {double? spaceshipX}) {
    if (slowTimer > 0) {
      slowTimer -= deltaTime;
      deltaTime *= 0.5; // Slow down movement and internal timers by 50%
    }
    _timeElapsed += deltaTime;

    switch (type) {
      case DroneType.boss:
        // Boss moves side-to-side and performs occasional swoops towards the player
        double swoopY = 0.0;
        double cycle = _timeElapsed % 12.0; // 12 second loop
        if (cycle > 7.0 && cycle < 11.0) {
          // Swoop down for 4 seconds
          double progress = (cycle - 7.0) / 4.0; // 0.0 to 1.0
          swoopY = 130.0 * math.sin(progress * math.pi); // swoop max depth 130px
        }

        position += Offset(velocity.dx * deltaTime, 0.0);
        position = Offset(
          position.dx,
          initialY + 25.0 * math.sin(_timeElapsed * 1.5) + swoopY,
        );
        break;

      case DroneType.armored:
        // Armored: fast diagonal bouncing within upper bounds (Y: 45 to 260)
        position += Offset(velocity.dx * deltaTime, velocity.dy * deltaTime);
        if (position.dy < 45.0) {
          position = Offset(position.dx, 45.0);
          velocity = Offset(velocity.dx, velocity.dy.abs());
        } else if (position.dy > 260.0) {
          position = Offset(position.dx, 260.0);
          velocity = Offset(velocity.dx, -velocity.dy.abs());
        }
        break;

      case DroneType.explosive:
        // Explosive: erratic wave movement
        position += Offset(
          velocity.dx * deltaTime,
          (velocity.dy + 50.0 * math.sin(_timeElapsed * 5.0)) * deltaTime,
        );
        break;

      case DroneType.normal:
        // Normal: side-to-side with swooping curve
        double horizontalSweep = 30.0 * math.sin(_timeElapsed * 2.5);
        position += Offset(
          (velocity.dx + horizontalSweep) * deltaTime,
          velocity.dy * deltaTime,
        );
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