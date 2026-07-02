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

  void update(double deltaTime, double screenWidth, double screenHeight, {double? spaceshipX}) {
    if (slowTimer > 0) {
      slowTimer -= deltaTime;
      deltaTime *= 0.5; // Slow down movement and internal timers by 50%
    }
    _timeElapsed += deltaTime;

    switch (type) {
      case DroneType.boss:
        // Free space-flight trajectory: targets entire width and upper 70% of screen height
        double targetX = (screenWidth / 2) + (screenWidth / 3) * math.sin(_timeElapsed * 0.8) + (screenWidth / 6) * math.cos(_timeElapsed * 1.7);
        double maxBossY = screenHeight > 100.0 ? screenHeight * 0.70 : 450.0;
        double targetY = (maxBossY * 0.55) + (maxBossY * 0.4) * math.sin(_timeElapsed * 0.5) + (maxBossY * 0.1) * math.cos(_timeElapsed * 1.2);
        
        // Smoothly interpolate position towards dynamic target for a lifelike space-flight look
        position = Offset(
          position.dx + (targetX - position.dx) * 1.6 * deltaTime,
          position.dy + (targetY - position.dy) * 1.6 * deltaTime,
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