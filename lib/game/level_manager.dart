import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models/drone_enemy.dart';

class LevelManager {
  static List<DroneEnemy> buildLevel(int level, double screenWidth) {
    List<DroneEnemy> drones = [];
    
    // Determine grid columns
    double margin = 30.0;
    double usableWidth = screenWidth - (margin * 2);
    int cols = 5;
    double colWidth = usableWidth / (cols - 1);
    
    // Default speeds based on tier
    double speedX = 40.0 + (level * 3);
    if (speedX > 100.0) speedX = 100.0;

    switch (level) {
      // --- TIER 1: BASICS (Levels 1 - 5) ---
      case 1:
        // 2 Simple rows of normal drones (no shooting in Tier 1)
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < cols; c++) {
            drones.add(DroneEnemy(
              position: Offset(margin + c * colWidth, 70.0 + r * 50.0),
              type: DroneType.normal,
              velocity: Offset(speedX, 0),
              health: 1,
              shootCooldown: 9999.0, // Don't shoot in level 1
            ));
          }
        }
        break;
      case 2:
        // V-Shape normal drones
        List<int> colRows = [0, 1, 2, 1, 0];
        for (int c = 0; c < cols; c++) {
          int rowCount = colRows[c];
          for (int r = 0; r <= rowCount; r++) {
            drones.add(DroneEnemy(
              position: Offset(margin + c * colWidth, 60.0 + r * 50.0),
              type: DroneType.normal,
              velocity: Offset(speedX * 1.1, 0),
              health: 1,
              shootCooldown: 9999.0,
            ));
          }
        }
        break;
      case 3:
        // Checkerboard of Normal & Armored (no shoot)
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < cols; c++) {
            bool isArmored = (r + c) % 2 == 0;
            drones.add(DroneEnemy(
              position: Offset(margin + c * colWidth, 60.0 + r * 45.0),
              type: isArmored ? DroneType.armored : DroneType.normal,
              velocity: Offset(speedX, 0),
              health: isArmored ? 2 : 1,
              shootCooldown: 9999.0,
            ));
          }
        }
        break;
      case 4:
        // Side columns with an explosive core
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < cols; c++) {
            DroneType type = DroneType.normal;
            int hp = 1;
            if (c == 2 && r == 1) {
              type = DroneType.explosive;
            } else if (c == 0 || c == cols - 1) {
              type = DroneType.armored;
              hp = 2;
            }
            drones.add(DroneEnemy(
              position: Offset(margin + c * colWidth, 60.0 + r * 45.0),
              type: type,
              velocity: Offset(speedX * 1.2, 0),
              health: hp,
              shootCooldown: 9999.0,
            ));
          }
        }
        break;
      case 5:
        // TIER 1 BOSS: Commander Drone
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2, 70.0),
          type: DroneType.boss,
          velocity: Offset(60.0, 0),
          width: 72.0,
          height: 48.0,
          health: 40,
          shootCooldown: 2.0,
        ));
        // Add 2 guards
        drones.add(DroneEnemy(
          position: Offset(margin, 130.0),
          type: DroneType.normal,
          velocity: Offset(60.0, 0),
          health: 1,
          shootCooldown: 9999.0,
        ));
        drones.add(DroneEnemy(
          position: Offset(screenWidth - margin, 130.0),
          type: DroneType.normal,
          velocity: Offset(-60.0, 0),
          health: 1,
          shootCooldown: 9999.0,
        ));
        break;

      // --- TIER 2: ENEMY FIRE (Levels 6 - 10) ---
      case 6:
        // Simple rows but with shooting!
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < cols; c++) {
            bool isArmored = c == 0 || c == cols - 1;
            drones.add(DroneEnemy(
              position: Offset(margin + c * colWidth, 70.0 + r * 50.0),
              type: isArmored ? DroneType.armored : DroneType.normal,
              velocity: Offset(speedX, 0),
              health: isArmored ? 2 : 1,
              shootCooldown: 3.0 + c * 0.5,
            ));
          }
        }
        break;
      case 7:
        // Explosive arrows
        // Tip is explosive, wings are normal
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2, 60.0),
          type: DroneType.explosive,
          velocity: Offset(speedX, 0),
          health: 1,
          shootCooldown: 2.5,
        ));
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2 - colWidth, 105.0),
          type: DroneType.normal,
          velocity: Offset(speedX, 0),
          health: 1,
          shootCooldown: 3.5,
        ));
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2 + colWidth, 105.0),
          type: DroneType.normal,
          velocity: Offset(speedX, 0),
          health: 1,
          shootCooldown: 3.5,
        ));
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2 - 2 * colWidth, 150.0),
          type: DroneType.armored,
          velocity: Offset(speedX, 0),
          health: 2,
          shootCooldown: 4.0,
        ));
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2 + 2 * colWidth, 150.0),
          type: DroneType.armored,
          velocity: Offset(speedX, 0),
          health: 2,
          shootCooldown: 4.0,
        ));
        break;
      case 8:
        // Zigzag speed wave
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < cols; c++) {
            drones.add(DroneEnemy(
              position: Offset(margin + c * colWidth, 70.0 + r * 50.0),
              type: (r == 0) ? DroneType.explosive : DroneType.normal,
              velocity: Offset(speedX * 1.4, 0),
              health: 1,
              shootCooldown: 2.0 + r * 1.5,
            ));
          }
        }
        break;
      case 9:
        // Armored front wall
        for (int c = 0; c < cols; c++) {
          drones.add(DroneEnemy(
            position: Offset(margin + c * colWidth, 110.0),
            type: DroneType.armored,
            velocity: Offset(speedX, 0),
            health: 2,
            shootCooldown: 3.5,
          ));
        }
        // Explosive cores behind
        drones.add(DroneEnemy(
          position: Offset(margin + colWidth, 60.0),
          type: DroneType.explosive,
          velocity: Offset(speedX, 0),
          health: 1,
          shootCooldown: 2.5,
        ));
        drones.add(DroneEnemy(
          position: Offset(margin + 3 * colWidth, 60.0),
          type: DroneType.explosive,
          velocity: Offset(speedX, 0),
          health: 1,
          shootCooldown: 2.5,
        ));
        break;
      case 10:
        // TIER 2 BOSS: Shield Destroyer
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2, 70.0),
          type: DroneType.boss,
          velocity: Offset(70.0, 0),
          width: 80.0,
          height: 50.0,
          health: 80,
          shootCooldown: 1.8,
        ));
        // Guarded by explosive wings
        drones.add(DroneEnemy(
          position: Offset(margin, 120.0),
          type: DroneType.explosive,
          velocity: Offset(70.0, 0),
          health: 1,
          shootCooldown: 3.0,
        ));
        drones.add(DroneEnemy(
          position: Offset(screenWidth - margin, 120.0),
          type: DroneType.explosive,
          velocity: Offset(-70.0, 0),
          health: 1,
          shootCooldown: 3.0,
        ));
        break;

      // --- TIER 3: METEOR & DIVE (Levels 11 - 15) ---
      // (Drones have high speeds and dive down slowly, drift velocity.dy > 0)
      case 11:
        // Circle layout
        double centerX = screenWidth / 2;
        double centerY = 130.0;
        double radius = 60.0;
        int count = 8;
        for (int i = 0; i < count; i++) {
          double angle = i * (2 * 3.14159 / count);
          drones.add(DroneEnemy(
            position: Offset(centerX + radius * math.cos(angle), centerY + radius * math.sin(angle)),
            type: (i % 2 == 0) ? DroneType.normal : DroneType.armored,
            velocity: Offset(speedX * 0.8, 10.0), // Drift down slowly
            health: (i % 2 == 0) ? 1 : 2,
            shootCooldown: 2.0 + i * 0.3,
          ));
        }
        break;
      case 12:
        // Double grid of armored and explosive
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < cols; c++) {
            DroneType type = (r + c) % 2 == 0 ? DroneType.armored : DroneType.explosive;
            drones.add(DroneEnemy(
              position: Offset(margin + c * colWidth, 60.0 + r * 45.0),
              type: type,
              velocity: Offset(speedX * 1.1, 12.0), // Drift down
              health: type == DroneType.armored ? 2 : 1,
              shootCooldown: 1.8 + c * 0.4,
            ));
          }
        }
        break;
      case 13:
        // X-Formation
        for (int i = 0; i < cols; i++) {
          // Main diagonal
          drones.add(DroneEnemy(
            position: Offset(margin + i * colWidth, 60.0 + i * 35.0),
            type: i == 2 ? DroneType.explosive : DroneType.armored,
            velocity: Offset(speedX, 15.0),
            health: i == 2 ? 1 : 2,
            shootCooldown: 2.5,
          ));
          // Counter diagonal
          if (i != 2) {
            drones.add(DroneEnemy(
              position: Offset(margin + (cols - 1 - i) * colWidth, 60.0 + i * 35.0),
              type: DroneType.normal,
              velocity: Offset(-speedX, 15.0),
              health: 1,
              shootCooldown: 3.0,
            ));
          }
        }
        break;
      case 14:
        // Sweeping diamond
        List<Offset> positions = [
          Offset(screenWidth / 2, 50),
          Offset(screenWidth / 2 - colWidth, 90),
          Offset(screenWidth / 2 + colWidth, 90),
          Offset(screenWidth / 2 - 2 * colWidth, 130),
          Offset(screenWidth / 2 + 2 * colWidth, 130),
          Offset(screenWidth / 2 - colWidth, 170),
          Offset(screenWidth / 2 + colWidth, 170),
          Offset(screenWidth / 2, 210),
        ];
        for (int i = 0; i < positions.length; i++) {
          bool isCore = i == 0 || i == positions.length - 1;
          drones.add(DroneEnemy(
            position: positions[i],
            type: isCore ? DroneType.explosive : DroneType.armored,
            velocity: Offset(speedX * 1.2, 10.0),
            health: isCore ? 1 : 2,
            shootCooldown: 1.5 + i * 0.3,
          ));
        }
        break;
      case 15:
        // TIER 3 BOSS: Heavy Carrier
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2, 80.0),
          type: DroneType.boss,
          velocity: Offset(80.0, 0),
          width: 84.0,
          height: 52.0,
          health: 120,
          shootCooldown: 1.4,
        ));
        // Spawns with 4 armored guards
        for (int i = 0; i < 4; i++) {
          drones.add(DroneEnemy(
            position: Offset(margin + i * (usableWidth / 3), 160.0),
            type: DroneType.armored,
            velocity: Offset(60.0, 5.0),
            health: 2,
            shootCooldown: 3.0,
          ));
        }
        break;

      // --- TIER 4: COSMIC CHAOS (Levels 16 - 20) ---
      case 16:
        // Giant Grid with multiple Explosives
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < cols; c++) {
            DroneType t = DroneType.normal;
            int hp = 1;
            if (c == 2) {
              t = DroneType.explosive;
            } else if (r == 1) {
              t = DroneType.armored;
              hp = 2;
            }
            drones.add(DroneEnemy(
              position: Offset(margin + c * colWidth, 60.0 + r * 50.0),
              type: t,
              velocity: Offset(speedX * 1.3, 18.0),
              health: hp,
              shootCooldown: 1.2 + c * 0.2,
            ));
          }
        }
        break;
      case 17:
        // Double Sweeping Rows
        for (int c = 0; c < cols; c++) {
          drones.add(DroneEnemy(
            position: Offset(margin + c * colWidth, 60.0),
            type: DroneType.armored,
            velocity: Offset(speedX * 1.4, 20.0),
            health: 2,
            shootCooldown: 1.5,
          ));
          drones.add(DroneEnemy(
            position: Offset(margin + c * colWidth, 120.0),
            type: DroneType.explosive,
            velocity: Offset(-speedX * 1.4, 20.0),
            health: 1,
            shootCooldown: 1.0 + c * 0.3,
          ));
        }
        break;
      case 18:
        // Defense Screen
        for (int c = 0; c < cols; c++) {
          // Front line armored
          drones.add(DroneEnemy(
            position: Offset(margin + c * colWidth, 110.0),
            type: DroneType.armored,
            velocity: Offset(speedX, 22.0),
            health: 2,
            shootCooldown: 2.0,
          ));
          // Back line explosive
          drones.add(DroneEnemy(
            position: Offset(margin + c * colWidth, 60.0),
            type: DroneType.explosive,
            velocity: Offset(speedX, 22.0),
            health: 1,
            shootCooldown: 1.2,
          ));
        }
        break;
      case 19:
        // Cluster Wave
        List<Offset> cluster1 = [
          Offset(margin + colWidth, 60), Offset(margin, 100), Offset(margin + 2 * colWidth, 100), Offset(margin + colWidth, 140)
        ];
        List<Offset> cluster2 = [
          Offset(screenWidth - margin - colWidth, 60), Offset(screenWidth - margin, 100), Offset(screenWidth - margin - 2 * colWidth, 100), Offset(screenWidth - margin - colWidth, 140)
        ];
        for (var pos in cluster1) {
          drones.add(DroneEnemy(
            position: pos,
            type: DroneType.armored,
            velocity: Offset(speedX * 1.1, 15.0),
            health: 2,
            shootCooldown: 1.4,
          ));
        }
        for (var pos in cluster2) {
          drones.add(DroneEnemy(
            position: pos,
            type: DroneType.explosive,
            velocity: Offset(-speedX * 1.1, 15.0),
            health: 1,
            shootCooldown: 1.0,
          ));
        }
        break;
      case 20:
        // FINAL BOSS: Cosmic Carrier (Center - 250 HP)
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2, 80.0),
          type: DroneType.boss,
          velocity: Offset(60.0, 0),
          width: 96.0,
          height: 60.0,
          health: 250,
          shootCooldown: 1.0,
        ));
        // FLANKING BOSS 1: Commander Boss (Left - 60 HP)
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2 - 90.0, 135.0),
          type: DroneType.boss,
          velocity: Offset(45.0, 0),
          width: 64.0,
          height: 44.0,
          health: 60,
          shootCooldown: 1.5,
        ));
        // FLANKING BOSS 2: Shield Destroyer Boss (Right - 60 HP)
        drones.add(DroneEnemy(
          position: Offset(screenWidth / 2 + 90.0, 135.0),
          type: DroneType.boss,
          velocity: Offset(-45.0, 0),
          width: 64.0,
          height: 44.0,
          health: 60,
          shootCooldown: 1.5,
        ));
        // Guarded by explosive cores
        drones.add(DroneEnemy(
          position: Offset(margin, 190.0),
          type: DroneType.explosive,
          velocity: Offset(70.0, 0),
          health: 1,
          shootCooldown: 2.0,
        ));
        drones.add(DroneEnemy(
          position: Offset(screenWidth - margin, 190.0),
          type: DroneType.explosive,
          velocity: Offset(-70.0, 0),
          health: 1,
          shootCooldown: 2.0,
        ));
        break;
      default:
        // Infinite scaling fall back levels
        int numDrones = 5 + (level % 5);
        for (int i = 0; i < numDrones; i++) {
          drones.add(DroneEnemy(
            position: Offset(margin + (i % 5) * colWidth, 60.0 + (i ~/ 5) * 50.0),
            type: i % 3 == 0 ? DroneType.armored : DroneType.normal,
            velocity: Offset(speedX, 10.0),
            health: i % 3 == 0 ? 2 : 1,
            shootCooldown: 2.0,
          ));
        }
    }

    // Programmatically triple the density of regular levels, and add guards to Boss levels
    if (level % 5 != 0) { // Not a boss level
      List<DroneEnemy> extraDrones = [];
      for (var drone in drones) {
        // Drone 2: shifted slightly up-left, clamped Y to avoid spawning low
        double y2 = (drone.position.dy - 30.0).clamp(40.0, 220.0);
        extraDrones.add(DroneEnemy(
          position: Offset(drone.position.dx - 22.0, y2),
          type: drone.type,
          velocity: Offset(-drone.velocity.dx * 1.1, drone.velocity.dy),
          health: drone.health,
          shootCooldown: drone.shootCooldown * 0.85,
        ));
        
        // Drone 3: shifted slightly up-right, clamped Y to avoid spawning low
        double y3 = (drone.position.dy - 60.0).clamp(40.0, 220.0);
        extraDrones.add(DroneEnemy(
          position: Offset(drone.position.dx + 22.0, y3),
          type: drone.type == DroneType.normal ? DroneType.armored : DroneType.normal,
          velocity: Offset(drone.velocity.dx * 0.9, drone.velocity.dy),
          health: drone.health,
          shootCooldown: drone.shootCooldown * 1.15,
        ));
      }
      drones.addAll(extraDrones);
    } else {
      // Boss levels: Add extra guards flanking the Boss
      List<DroneEnemy> extraGuards = [];
      for (var drone in drones) {
        if (drone.type == DroneType.boss) {
          extraGuards.add(DroneEnemy(
            position: Offset(drone.position.dx - 80.0, (drone.position.dy + 50.0).clamp(40.0, 250.0)),
            type: DroneType.armored,
            velocity: Offset(50.0, 0.0),
            health: 3,
            shootCooldown: 2.2,
          ));
          extraGuards.add(DroneEnemy(
            position: Offset(drone.position.dx + 80.0, (drone.position.dy + 50.0).clamp(40.0, 250.0)),
            type: DroneType.armored,
            velocity: Offset(-50.0, 0.0),
            health: 3,
            shootCooldown: 2.2,
          ));
        }
      }
      drones.addAll(extraGuards);
    }
    
    return drones;
  }
}
