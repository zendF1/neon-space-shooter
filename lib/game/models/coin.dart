import 'package:flutter/material.dart';

class Coin {
  Offset position;
  final double speed = 140.0; // Falling speed (pixels per second)
  final double radius = 10.0;
  bool isCollected = false;
  double rotationAngle = 0.0; // Rotation for the visual neon effect

  Coin({
    required this.position,
  });

  void update(double deltaTime, {Offset? spaceshipPosition, int magnetLevel = 0}) {
    rotationAngle += 2.5 * deltaTime;
    
    if (magnetLevel > 0 && spaceshipPosition != null) {
      Offset direction = spaceshipPosition - position;
      double distance = direction.distance;
      double magnetRadius = magnetLevel * 75.0; // Lv 1: 75px, Lv 2: 150px, Lv 3: 225px
      
      if (distance < magnetRadius) {
        double pullSpeed = 220.0 + (magnetLevel * 60.0);
        position += Offset(direction.dx / distance, direction.dy / distance) * pullSpeed * deltaTime;
        return;
      }
    }
    
    // Normal falling
    position += Offset(0, speed * deltaTime);
  }

  Color get color => Colors.amberAccent;
  Color get glowColor => Colors.amber.withOpacity(0.5);

  Rect getRect() {
    return Rect.fromCircle(center: position, radius: radius);
  }
}
