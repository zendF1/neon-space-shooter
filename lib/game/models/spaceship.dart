import 'package:flutter/material.dart';

class Spaceship {
  double positionX; // Center X position
  double positionY; // Center Y position
  double width;
  double height;
  Color color;
  Color glowColor;

  // Power-up States
  bool shieldActive = false;
  double tripleShotTimer = 0.0;
  double rapidFireTimer = 0.0;

  // Upgrade levels
  int mainCannonLevel = 1;
  int homingMissileLevel = 0;
  int shieldMaxLevel = 1;
  int magnetLevel = 0;

  // Active shield health
  int shieldHealth = 0;

  // Cosmetic skin details
  String skinId;

  Spaceship({
    required this.positionX,
    required this.positionY,
    this.width = 48.0,
    this.height = 48.0,
    this.color = const Color(0xFFFF007F), // Neon Pink default
    this.glowColor = const Color(0x99FF007F),
    this.skinId = 'ship_pink',
  });

  void move(double deltaX, double deltaY, double screenWidth, double screenHeight) {
    positionX += deltaX;
    positionY += deltaY;
    
    // Keep spaceship within screen boundaries with margin
    double halfWidth = width / 2;
    double halfHeight = height / 2;
    
    if (positionX - halfWidth < 12.0) {
      positionX = 12.0 + halfWidth;
    } else if (positionX + halfWidth > screenWidth - 12.0) {
      positionX = screenWidth - 12.0 - halfWidth;
    }

    // Limit Y-movement: player can move in the lower 60% of the screen
    double minY = screenHeight * 0.40;
    double maxY = screenHeight - 40.0;
    if (positionY - halfHeight < minY) {
      positionY = minY + halfHeight;
    } else if (positionY + halfHeight > maxY) {
      positionY = maxY - halfHeight;
    }
  }

  void updatePowerUps(double deltaTime) {
    if (tripleShotTimer > 0) {
      tripleShotTimer -= deltaTime;
    }
    if (rapidFireTimer > 0) {
      rapidFireTimer -= deltaTime;
    }
  }

  Rect get rect => Rect.fromLTWH(
        positionX - width / 2,
        positionY - height / 2,
        width,
        height,
      );
}
