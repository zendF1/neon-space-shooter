import 'package:flutter/material.dart';
import 'drone_enemy.dart';

class HomingMissile {
  Offset position;
  Offset velocity;
  DroneEnemy? target;
  bool isDestroyed = false;
  final double width;
  final double height;
  final double damage = 2.0; // Missiles deal double damage!

  HomingMissile({
    required this.position,
    this.velocity = const Offset(0.0, -150.0),
    this.width = 10.0,
    this.height = 24.0,
  });

  void update(double deltaTime, List<DroneEnemy> drones) {
    // 1. Target validation/acquisition
    if (target == null || target!.isDestroyed || target!.health <= 0) {
      target = _findClosestTarget(drones);
    }

    // 2. Steering behavior
    if (target != null) {
      Offset directionVec = target!.position - position;
      double dist = directionVec.distance;
      if (dist > 0.0) {
        directionVec = Offset(directionVec.dx / dist, directionVec.dy / dist);
        
        // Homing target speed
        double speed = 420.0;
        Offset desiredVelocity = directionVec * speed;
        
        // Interpolate velocity steering (high lerp factor for sharp turns)
        velocity = Offset(
          velocity.dx + (desiredVelocity.dx - velocity.dx) * 12.0 * deltaTime,
          velocity.dy + (desiredVelocity.dy - velocity.dy) * 12.0 * deltaTime,
        );
      }
    } else {
      // If no target, gradually steer straight up
      velocity = Offset(
        velocity.dx + (0.0 - velocity.dx) * 4.0 * deltaTime,
        velocity.dy + (-350.0 - velocity.dy) * 4.0 * deltaTime,
      );
    }

    // 3. Move position
    position += velocity * deltaTime;
  }

  DroneEnemy? _findClosestTarget(List<DroneEnemy> drones) {
    DroneEnemy? closest;
    double minDist = 99999.0;
    
    for (var drone in drones) {
      if (drone.isDestroyed || drone.health <= 0) continue;
      double dist = (drone.position - position).distance;
      if (dist < minDist) {
        minDist = dist;
        closest = drone;
      }
    }
    return closest;
  }

  Rect get rect => Rect.fromLTWH(
        position.dx - width / 2,
        position.dy - height / 2,
        width,
        height,
      );
}
