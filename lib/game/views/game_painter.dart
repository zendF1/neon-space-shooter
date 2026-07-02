import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game_manager.dart';
import '../models/drone_enemy.dart';

class GamePainter extends CustomPainter {
  final GameManager manager;

  // Static Paint pooling to completely avoid GC allocations in paint loops
  static final Paint _bgPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _gridPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _starPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _bulletPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowPaint = Paint()..style = PaintingStyle.fill;

  // Cached shader parameters to avoid allocating LinearGradient shaders every frame
  static double? _cachedWidth;
  static double? _cachedHeight;
  static int? _cachedLevel;
  static Shader? _cachedShader;

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

    // 2b. Draw Gravity Black Holes
    _drawBlackHoles(canvas);

    // 2c. Draw Asteroids
    _drawAsteroids(canvas);

    // 3. Power-ups
    _drawPowerUps(canvas);

    // 4. Coins
    _drawCoins(canvas);

    // 4b. Draw Wingmen companion drones
    _drawWingmen(canvas);

    // 5. Player spaceship & Thrusters
    _drawSpaceship(canvas);

    // 5b. Draw Ultimate Skill effects
    _drawUltimateEffects(canvas);

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
    // Divide levels into 4 zones (every 5 levels represents a zone theme)
    int zone = (((manager.level - 1) ~/ 5) + 1).clamp(1, 4);

    // Rebuild shader only on screen size or level theme change
    if (_cachedWidth != size.width || _cachedHeight != size.height || _cachedLevel != manager.level) {
      _cachedWidth = size.width;
      _cachedHeight = size.height;
      _cachedLevel = manager.level;

      List<Color> colors;
      if (zone == 1) {
        colors = [const Color(0xFF07050F), const Color(0xFF130E26)];
      } else if (zone == 2) {
        colors = [const Color(0xFF0E031A), const Color(0xFF030107)];
      } else if (zone == 3) {
        colors = [const Color(0xFF2D0700), const Color(0xFF090100)];
      } else {
        colors = [const Color(0xFF01010B), const Color(0xFF03061A)];
      }

      _cachedShader = LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    if (_cachedShader != null) {
      _bgPaint.shader = _cachedShader;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);
    }

    // Grid color and stroke based on Map Zone theme
    Color gridColor;
    if (zone == 1) {
      gridColor = const Color(0x0600FFFF); // Subtle cyan grid
    } else if (zone == 2) {
      gridColor = const Color(0x0C00FFFF); // Bold neon grid
    } else if (zone == 3) {
      gridColor = const Color(0x08FF5500); // Solar orange grid
    } else {
      gridColor = const Color(0x040055FF); // Warp space deep blue grid
    }

    _gridPaint.color = gridColor;
    _gridPaint.strokeWidth = 1.0;

    double gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }

    // Draw Stars (optimized - NO MaskFilter.blur inside loops)
    for (int i = 0; i < manager.stars.length; i++) {
      Offset pos = manager.stars[i];
      double speed = manager.starSpeeds[i];

      double radius = speed * 1.5;
      Color starColor;

      if (zone == 3) {
        // Solar flare zone features orange/amber stars
        starColor = Color.lerp(Colors.amberAccent, Colors.deepOrangeAccent, speed)!.withOpacity(0.3 + 0.7 * speed);
      } else {
        starColor = Colors.white.withOpacity(0.3 + 0.7 * speed);
      }

      _starPaint.color = starColor;

      if (zone == 4) {
        // Hyper Warp zone stars stretch into vertical streaks to simulate cosmic travel speed!
        double tailLen = radius * 12.0;
        _starPaint.strokeWidth = radius;
        canvas.drawLine(pos, Offset(pos.dx, pos.dy + tailLen), _starPaint);
      } else {
        canvas.drawCircle(pos, radius, _starPaint);
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
          double drawW = laser.width < 10.0 ? 64.0 : laser.width * 5.2;
          double drawH = laser.height * 4.8;
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
        Rect drawRect = Rect.fromCenter(center: laser.position, width: laser.width * 2.0, height: laser.height * 2.0);
        _bulletPaint.color = laser.color;
        _glowPaint.color = laser.glowColor;
        _glowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawRect(drawRect, _glowPaint);
        canvas.drawRect(drawRect, _bulletPaint);

        // Core white brightness
        _bulletPaint.color = Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(drawRect.left + 2, drawRect.top, drawRect.width - 4, drawRect.height),
          _bulletPaint,
        );
      }
    }

    // Enemy bullets
    for (var laser in manager.enemyLasers) {
      if (manager.spritesLoaded && manager.spriteImages.containsKey('bullet_enemy')) {
        final ui.Image? img = manager.spriteImages['bullet_enemy'];
        if (img != null) {
          double drawW = laser.width < 10.0 ? 56.0 : laser.width * 4.8;
          double drawH = laser.height * 3.0;
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
        Rect drawRect = Rect.fromCenter(center: laser.position, width: laser.width * 2.0, height: laser.height * 2.0);
        _bulletPaint.color = laser.color;
        _glowPaint.color = laser.glowColor;
        _glowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawRect(drawRect, _glowPaint);
        canvas.drawRect(drawRect, _bulletPaint);

        // Core brightness
        _bulletPaint.color = Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(drawRect.left + 2, drawRect.top, drawRect.width - 4, drawRect.height),
          _bulletPaint,
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
      _particlePaint.color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
      canvas.drawCircle(p.position, p.size * (0.5 + 0.5 * p.life), _particlePaint);
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

  void _drawWingmen(Canvas canvas) {
    for (var wm in manager.wingmen) {
      double radius = 10.0;
      
      // Outer neon wing glow
      final Paint glow = Paint()
        ..color = wm.color.withOpacity(0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawCircle(wm.position, radius * 1.6, glow);

      // Core white engine
      final Paint core = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(wm.position, radius * 0.5, core);

      // Wing borders
      final Paint wingPaint = Paint()
        ..color = wm.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      Path wingPath = Path();
      wingPath.moveTo(wm.position.dx, wm.position.dy - radius);
      wingPath.lineTo(wm.position.dx - radius, wm.position.dy + radius * 0.6);
      wingPath.lineTo(wm.position.dx + radius, wm.position.dy + radius * 0.6);
      wingPath.close();
      canvas.drawPath(wingPath, wingPaint);
    }
  }

  void _drawAsteroids(Canvas canvas) {
    for (var ast in manager.asteroids) {
      canvas.save();
      canvas.translate(ast.position.dx, ast.position.dy);
      canvas.rotate(ast.rotationAngle);

      double r = ast.size / 2;

      // Draw an orange neon glow border ring to make it stand out!
      final Paint glowPaint = Paint()
        ..color = Colors.orangeAccent.withOpacity(0.25)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
      canvas.drawCircle(Offset.zero, r * 1.3, glowPaint);

      if (manager.spritesLoaded && manager.spriteImages.containsKey('asteroid')) {
        final ui.Image? img = manager.spriteImages['asteroid'];
        if (img != null) {
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(center: Offset.zero, width: ast.size * 1.5, height: ast.size * 1.5),
            Paint()..blendMode = BlendMode.screen,
          );
        }
      } else {
        // Fallback vector drawing
        final Paint corePaint = Paint()
          ..color = const Color(0xFF1D0E02)
          ..style = PaintingStyle.fill;
        
        Path rockPath = Path();
        rockPath.moveTo(0, -r);
        rockPath.lineTo(r * 0.8, -r * 0.5);
        rockPath.lineTo(r, r * 0.3);
        rockPath.lineTo(r * 0.4, r * 0.9);
        rockPath.lineTo(-r * 0.5, r);
        rockPath.lineTo(-r * 0.9, -r * 0.2);
        rockPath.close();
        canvas.drawPath(rockPath, corePaint);

        final Paint outlinePaint = Paint()
          ..color = Colors.orangeAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawPath(rockPath, outlinePaint);

        canvas.drawLine(Offset(-r * 0.2, -r * 0.2), Offset(r * 0.3, r * 0.3), outlinePaint);
        canvas.drawLine(Offset(r * 0.3, -r * 0.1), Offset(-r * 0.4, r * 0.4), outlinePaint);
      }

      canvas.restore();
    }
  }

  void _drawBlackHoles(Canvas canvas) {
    for (var bh in manager.blackHoles) {
      double timeFactor = DateTime.now().millisecondsSinceEpoch * 0.005;

      // 1. Draw glowing space nebula behind black hole to make it super prominent
      final Paint gravityGlow = Paint()
        ..color = const Color(0xFFBD00FF).withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);
      canvas.drawCircle(bh.position, bh.radius * 1.2, gravityGlow);

      if (manager.spritesLoaded && manager.spriteImages.containsKey('black_hole')) {
        final ui.Image? img = manager.spriteImages['black_hole'];
        if (img != null) {
          canvas.save();
          canvas.translate(bh.position.dx, bh.position.dy);
          canvas.rotate(-timeFactor * 0.6); // rotate opposite for interesting parallax effect
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(center: Offset.zero, width: bh.radius * 2.6, height: bh.radius * 2.6),
            Paint()..blendMode = BlendMode.screen,
          );
          canvas.restore();
        }
      } else {
        // Fallback rotating layers
        for (int i = 0; i < 3; i++) {
          double angle = timeFactor + i * (math.pi / 3.0);
          double r = bh.radius * (0.6 + i * 0.3);
          
          canvas.save();
          canvas.translate(bh.position.dx, bh.position.dy);
          canvas.rotate(angle);
          
          final Paint ringPaint = Paint()
            ..color = const Color(0xFFBD00FF).withOpacity(0.15 + (i * 0.05))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
          
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 0.7), ringPaint);
          canvas.restore();
        }

        final Paint eventHorizon = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
        canvas.drawCircle(bh.position, bh.radius * 0.4, eventHorizon);

        final Paint borderGlow = Paint()
          ..color = const Color(0xFFBD00FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(bh.position, bh.radius * 0.4, borderGlow);
      }
    }
  }

  void _drawUltimateEffects(Canvas canvas) {
    if (manager.ultimateActiveDuration <= 0) return;

    if (manager.equippedUltimate == 'hyper_beam') {
      double shipX = manager.spaceship.positionX;
      double shipY = manager.spaceship.positionY;

      double width = 60.0;
      double jitter = 4.0 * math.sin(DateTime.now().millisecondsSinceEpoch * 0.05);
      double beamWidth = width + jitter;

      Rect beamRect = Rect.fromLTRB(shipX - beamWidth / 2, 0.0, shipX + beamWidth / 2, shipY - 12.0);

      // 1. Wide purple nebula glow
      final Paint beamGlow = Paint()
        ..color = const Color(0x77BD00FF)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawRect(beamRect, beamGlow);

      // 2. Pure white core brightness
      final Paint beamCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(shipX - beamWidth / 4, 0.0, shipX + beamWidth / 4, shipY - 12.0),
        beamCore,
      );

      // 3. Magenta electricity borders
      final Paint beamBorder = Paint()
        ..color = const Color(0xFFFF00FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(
        Rect.fromLTRB(shipX - beamWidth / 2, 0.0, shipX + beamWidth / 2, shipY - 12.0),
        beamBorder,
      );
    }
    else if (manager.equippedUltimate == 'shield_burst') {
      double elapsed = 3.0 - manager.ultimateActiveDuration;
      double progress = (elapsed / 3.0).clamp(0.0, 1.0);
      
      double maxRadius = 350.0;
      double currentRadius = progress * maxRadius;

      Offset center = Offset(manager.spaceship.positionX, manager.spaceship.positionY);

      // Expanding energy circle
      final Paint waveGlow = Paint()
        ..color = const Color(0x3300FFFF).withOpacity(0.3 * (1.0 - progress))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawCircle(center, currentRadius, waveGlow);

      // Neon cyan border wave
      final Paint waveRing = Paint()
        ..color = const Color(0xFF00FFFF).withOpacity(1.0 - progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0 - 2.0 * progress;
      canvas.drawCircle(center, currentRadius, waveRing);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
