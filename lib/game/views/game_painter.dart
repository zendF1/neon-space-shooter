import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game_manager.dart';
import '../models/drone_enemy.dart';

class GamePainter extends CustomPainter {
  final GameManager manager;

  GamePainter({required this.manager}) : super(repaint: manager);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Screen Shake
    if (manager.shakeOffset != Offset.zero) {
      canvas.save();
      canvas.translate(manager.shakeOffset.dx, manager.shakeOffset.dy);
    }

    // 2. Stars scrolling background
    _drawStarfield(canvas, size);

    // 3. Power-ups
    _drawPowerUps(canvas);

    // 4. Coins
    _drawCoins(canvas);

    // 5. Player spaceship & Thrusters
    _drawSpaceship(canvas);

    // 6. Laser bullets (player and enemy)
    _drawLasers(canvas);

    // 6b. Homing missiles
    _drawHomingMissiles(canvas);

    // 7. Drones & Bosses
    _drawDrones(canvas);

    // 8. Explosion Particles
    _drawParticles(canvas);

    // 9. Floating texts
    _drawFloatingTexts(canvas);

    // Restore shake
    if (manager.shakeOffset != Offset.zero) {
      canvas.restore();
    }
  }

  void _drawStarfield(Canvas canvas, Size size) {
    // Background Dark Space Gradient
    final Paint bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF07050F), Color(0xFF130E26)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid pattern (subtle cyan)
    final Paint gridPaint = Paint()
      ..color = const Color(0x0600FFFF)
      ..strokeWidth = 1.0;
    
    double gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Stars
    for (int i = 0; i < manager.stars.length; i++) {
      Offset pos = manager.stars[i];
      double speed = manager.starSpeeds[i];
      
      // Map speed to brightness & size
      double radius = speed * 1.5;
      Color starColor = Colors.white.withOpacity(0.3 + 0.7 * speed);

      final Paint starPaint = Paint()
        ..color = starColor
        ..style = PaintingStyle.fill;

      // Draw star
      canvas.drawCircle(pos, radius, starPaint);

      // Add a tiny glow to fast foreground stars
      if (speed > 0.8) {
        final Paint starGlow = Paint()
          ..color = starColor.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawCircle(pos, radius * 2.0, starGlow);
      }
    }
  }

  void _drawSpaceship(Canvas canvas) {
    var ship = manager.spaceship;
    
    if (manager.spritesLoaded && manager.spriteImages.containsKey(ship.skinId)) {
      final ui.Image? img = manager.spriteImages[ship.skinId];
      if (img != null) {
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          ship.rect,
          Paint()..blendMode = BlendMode.screen,
        );
      }
    } else {
      // 1. Draw thruster flame
      double flameFlicker = 10.0 + 12.0 * math.sin(DateTime.now().millisecondsSinceEpoch * 0.04);
      Path flamePath = Path();
      flamePath.moveTo(ship.positionX - ship.width / 6, ship.positionY + ship.height / 3);
      flamePath.lineTo(ship.positionX, ship.positionY + ship.height / 3 + flameFlicker);
      flamePath.lineTo(ship.positionX + ship.width / 6, ship.positionY + ship.height / 3);
      flamePath.close();

      final Paint flamePaint = Paint()
        ..color = Colors.orangeAccent.withOpacity(0.8)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawPath(flamePath, flamePaint);

      final Paint flameCore = Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(Offset(ship.positionX, ship.positionY + ship.height / 3), 4.0, flameCore);

      // 2. Spaceship path based on skin
      Path shipPath = Path();
      if (ship.skinId == 'ship_gold') {
        // Golden Valkyrie skin (Sharp sweeping wings, dual fuselage)
        shipPath.moveTo(ship.positionX, ship.positionY - ship.height / 2);
        shipPath.lineTo(ship.positionX - ship.width / 3, ship.positionY - ship.height / 8);
        shipPath.lineTo(ship.positionX - ship.width / 2, ship.positionY + ship.height / 2);
        shipPath.lineTo(ship.positionX - ship.width / 8, ship.positionY + ship.height / 4);
        shipPath.lineTo(ship.positionX, ship.positionY + ship.height / 8);
        shipPath.lineTo(ship.positionX + ship.width / 8, ship.positionY + ship.height / 4);
        shipPath.lineTo(ship.positionX + ship.width / 2, ship.positionY + ship.height / 2);
        shipPath.lineTo(ship.positionX + ship.width / 3, ship.positionY - ship.height / 8);
        shipPath.close();
      } else if (ship.skinId == 'ship_cyan') {
        // Plasma Vector skin (Delta fighter shape)
        shipPath.moveTo(ship.positionX, ship.positionY - ship.height / 2);
        shipPath.lineTo(ship.positionX - ship.width / 2, ship.positionY + ship.height / 3);
        shipPath.lineTo(ship.positionX - ship.width / 4, ship.positionY + ship.height / 3);
        shipPath.lineTo(ship.positionX, ship.positionY - ship.height / 8);
        shipPath.lineTo(ship.positionX + ship.width / 4, ship.positionY + ship.height / 3);
        shipPath.lineTo(ship.positionX + ship.width / 2, ship.positionY + ship.height / 3);
        shipPath.close();
      } else {
        // default: ship_pink (sleek jet star)
        shipPath.moveTo(ship.positionX, ship.positionY - ship.height / 2);
        shipPath.lineTo(ship.positionX - ship.width / 2, ship.positionY + ship.height / 2);
        shipPath.lineTo(ship.positionX - ship.width / 6, ship.positionY + ship.height / 4);
        shipPath.lineTo(ship.positionX + ship.width / 6, ship.positionY + ship.height / 4);
        shipPath.lineTo(ship.positionX + ship.width / 2, ship.positionY + ship.height / 2);
        shipPath.close();
      }

      final Paint glowPaint = Paint()
        ..color = ship.glowColor
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
      canvas.drawPath(shipPath, glowPaint);

      final Paint linePaint = Paint()
        ..color = ship.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(shipPath, linePaint);

      // Inner details (sleek cockpit)
      Path cockpit = Path();
      cockpit.moveTo(ship.positionX, ship.positionY - ship.height / 4);
      cockpit.lineTo(ship.positionX - 4.0, ship.positionY + 4.0);
      cockpit.lineTo(ship.positionX + 4.0, ship.positionY + 4.0);
      cockpit.close();
      canvas.drawPath(cockpit, Paint()..color = Colors.white.withOpacity(0.8)..style = PaintingStyle.fill);
    }

    // 3. Shield bubble
    if (ship.shieldActive) {
      double waveRadius = ship.width * 0.85 + 2.0 * math.sin(DateTime.now().millisecondsSinceEpoch * 0.01);
      final Paint shieldGlow = Paint()
        ..color = const Color(0x3300FFFF)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawCircle(Offset(ship.positionX, ship.positionY), waveRadius, shieldGlow);

      final Paint shieldRing = Paint()
        ..color = const Color(0xFF00FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(ship.positionX, ship.positionY), waveRadius, shieldRing);
    }
  }

  void _drawLasers(Canvas canvas) {
    // Player bullets
    for (var laser in manager.laserBullets) {
      if (manager.spritesLoaded && manager.spriteImages.containsKey('bullet_player')) {
        final ui.Image? img = manager.spriteImages['bullet_player'];
        if (img != null) {
          double drawW = laser.width < 10.0 ? 32.0 : laser.width * 2.6;
          double drawH = laser.height * 2.4;
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(
              center: laser.position,
              width: drawW,
              height: drawH,
            ),
            Paint()..blendMode = BlendMode.screen,
          );
        }
      } else {
        final Paint laserPaint = Paint()..style = PaintingStyle.fill..color = laser.color;
        final Paint glowPaint = Paint()..style = PaintingStyle.fill..color = laser.glowColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawRect(laser.rect, glowPaint);
        canvas.drawRect(laser.rect, laserPaint);

        // Core white brightness
        canvas.drawRect(
          Rect.fromLTWH(laser.rect.left + 1, laser.rect.top, laser.rect.width - 2, laser.rect.height),
          Paint()..color = Colors.white..style = PaintingStyle.fill,
        );
      }
    }

    // Enemy bullets
    for (var laser in manager.enemyLasers) {
      if (manager.spritesLoaded && manager.spriteImages.containsKey('bullet_enemy')) {
        final ui.Image? img = manager.spriteImages['bullet_enemy'];
        if (img != null) {
          double drawW = laser.width < 10.0 ? 28.0 : laser.width * 2.4;
          double drawH = laser.height * 1.5;
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(
              center: laser.position,
              width: drawW,
              height: drawH,
            ),
            Paint()..blendMode = BlendMode.screen,
          );
        }
      } else {
        final Paint laserPaint = Paint()..style = PaintingStyle.fill..color = laser.color;
        final Paint glowPaint = Paint()..style = PaintingStyle.fill..color = laser.glowColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawRect(laser.rect, glowPaint);
        canvas.drawRect(laser.rect, laserPaint);

        // Core brightness
        canvas.drawRect(
          Rect.fromLTWH(laser.rect.left + 1, laser.rect.top, laser.rect.width - 2, laser.rect.height),
          Paint()..color = Colors.white..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _drawHomingMissiles(Canvas canvas) {
    for (var missile in manager.missiles) {
      if (missile.isDestroyed) continue;

      Offset pos = missile.position;
      Rect r = missile.rect;

      if (manager.spritesLoaded && manager.spriteImages.containsKey('missile')) {
        final ui.Image? img = manager.spriteImages['missile'];
        if (img != null) {
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          // Rotate missile according to its movement direction
          double angle = math.atan2(missile.velocity.dy, missile.velocity.dx) + math.pi / 2;
          canvas.rotate(angle);
          
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(center: Offset.zero, width: r.width * 4.2, height: r.height * 2.0),
            Paint()..blendMode = BlendMode.screen,
          );
          canvas.restore();
        }
      } else {
        final Paint glowPaint = Paint()
          ..color = Colors.amberAccent.withOpacity(0.6)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawRect(r, glowPaint);

        final Paint missilePaint = Paint()
          ..color = Colors.amberAccent
          ..style = PaintingStyle.fill;
        canvas.drawRect(r, missilePaint);
      }
    }
  }

  void _drawDrones(Canvas canvas) {
    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    for (var drone in manager.drones) {
      if (drone.isDestroyed) continue;

      String spriteKey = 'drone_normal';
      switch (drone.type) {
        case DroneType.boss:
          spriteKey = 'drone_boss';
          break;
        case DroneType.armored:
          spriteKey = 'drone_armored';
          break;
        case DroneType.explosive:
          spriteKey = 'drone_explosive';
          break;
        case DroneType.normal:
          spriteKey = 'drone_normal';
          break;
      }

      if (manager.spritesLoaded && manager.spriteImages.containsKey(spriteKey)) {
        final ui.Image? img = manager.spriteImages[spriteKey];
        if (img != null) {
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            drone.rect,
            Paint()..blendMode = BlendMode.screen,
          );
        }
      } else {
        Path dronePath = Path();
        Rect r = drone.rect;

        switch (drone.type) {
          case DroneType.boss:
            // Boss: Large intimidating cruiser shape
            dronePath.moveTo(drone.position.dx, drone.position.dy + r.height / 2);
            dronePath.lineTo(r.left, r.top);
            dronePath.lineTo(r.left + r.width / 4, r.top + r.height / 6);
            dronePath.lineTo(drone.position.dx, r.top - r.height / 4);
            dronePath.lineTo(r.right - r.width / 4, r.top + r.height / 6);
            dronePath.lineTo(r.right, r.top);
            dronePath.close();
            break;
          case DroneType.armored:
            // Armored: Hexagon structure
            dronePath.moveTo(drone.position.dx, r.top);
            dronePath.lineTo(r.right, r.top + r.height / 3);
            dronePath.lineTo(r.right, r.bottom - r.height / 3);
            dronePath.moveTo(drone.position.dx, r.bottom);
            dronePath.lineTo(r.left, r.bottom - r.height / 3);
            dronePath.lineTo(r.left, r.top + r.height / 3);
            dronePath.close();
            break;
          case DroneType.explosive:
            // Explosive: Star or Spiked cross
            dronePath.moveTo(drone.position.dx, r.top);
            dronePath.lineTo(drone.position.dx - r.width / 6, drone.position.dy - r.height / 6);
            dronePath.lineTo(r.left, drone.position.dy);
            dronePath.lineTo(drone.position.dx - r.width / 6, drone.position.dy + r.height / 6);
            dronePath.lineTo(drone.position.dx, r.bottom);
            dronePath.lineTo(drone.position.dx + r.width / 6, drone.position.dy + r.height / 6);
            dronePath.lineTo(r.right, drone.position.dy);
            dronePath.lineTo(drone.position.dx + r.width / 6, drone.position.dy - r.height / 6);
            dronePath.close();
            break;
          case DroneType.normal:
            // Normal: Diamond shape
            dronePath.moveTo(drone.position.dx, r.top);
            dronePath.lineTo(r.right, drone.position.dy);
            dronePath.lineTo(drone.position.dx, r.bottom);
            dronePath.lineTo(r.left, drone.position.dy);
            dronePath.close();
            break;
        }

        // Draw neon colors
        glowPaint.color = drone.glowColor;
        canvas.drawPath(dronePath, glowPaint);

        fillPaint.color = Color.alphaBlend(drone.color.withOpacity(0.12), const Color(0xFF0E0B1A));
        canvas.drawPath(dronePath, fillPaint);

        borderPaint.color = drone.color;
        canvas.drawPath(dronePath, borderPaint);
      }

      // Boss HP Bar overlay
      if (drone.type == DroneType.boss) {
        double barW = drone.width;
        double barH = 4.0;
        Rect barRect = Rect.fromLTWH(
          drone.position.dx - barW / 2,
          drone.position.dy - drone.height / 2 - 12.0,
          barW,
          barH,
        );
        canvas.drawRect(barRect, Paint()..color = Colors.red.withOpacity(0.3)..style = PaintingStyle.fill);
        double healthPct = drone.health / drone.maxHealth;
        canvas.drawRect(
          Rect.fromLTWH(barRect.left, barRect.top, barW * healthPct, barH),
          Paint()..color = const Color(0xFFBD00FF)..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _drawPowerUps(Canvas canvas) {
    for (var powerUp in manager.powerUps) {
      if (powerUp.isCollected || powerUp.isExpired) continue;

      Offset pos = powerUp.position;
      double r = powerUp.radius;

      // Draw outer glowing neon ring
      final Paint glowPaint = Paint()
        ..color = powerUp.glowColor
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawCircle(pos, r * 1.3, glowPaint);

      final Paint ringPaint = Paint()
        ..color = powerUp.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(pos, r, ringPaint);

      // Dark center
      canvas.drawCircle(pos, r - 1.0, Paint()..color = const Color(0xFF130E26)..style = PaintingStyle.fill);

      // Icon text label
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: powerUp.label,
          style: TextStyle(
            color: powerUp.color,
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  void _drawCoins(Canvas canvas) {
    for (var coin in manager.fallingCoins) {
      if (coin.isCollected) continue;

      Offset pos = coin.position;
      double r = coin.radius;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(coin.rotationAngle);

      if (manager.spritesLoaded && manager.spriteImages.containsKey('coin')) {
        final ui.Image? img = manager.spriteImages['coin'];
        if (img != null) {
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(center: Offset.zero, width: r * 2.8, height: r * 2.8),
            Paint()..blendMode = BlendMode.screen,
          );
        }
      } else {
        final Paint glowPaint = Paint()
          ..color = coin.glowColor
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r * 1.5), glowPaint);

        final Paint borderPaint = Paint()
          ..color = coin.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.4, height: r * 1.4), borderPaint);
      }

      canvas.restore();
    }
  }

  void _drawParticles(Canvas canvas) {
    for (var p in manager.particleSystem.particles) {
      final Paint pPaint = Paint()
        ..color = p.color.withOpacity(p.life)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, p.size * (0.5 + 0.5 * p.life), pPaint);
    }
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (var ft in manager.floatingTexts) {
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withOpacity(ft.life),
            fontSize: 12.0 + 3.0 * ft.life,
            fontWeight: FontWeight.w800,
            fontFamily: 'Outfit',
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(ft.life * 0.8),
                blurRadius: 4.0,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        ft.position - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
