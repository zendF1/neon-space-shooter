import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async' show Completer;
import 'package:flutter/material.dart';
import 'dart:typed_data' show Uint8List;
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/spaceship.dart';
import 'models/laser_bullet.dart';
import 'models/drone_enemy.dart';
import 'models/power_up.dart';
import 'models/particle.dart';
import 'models/coin.dart';
import 'models/homing_missile.dart';
import 'physics.dart';
import 'level_manager.dart';
import 'audio_controller.dart';

enum GamePlayState { menu, playing, paused, gameOver, levelComplete }

class FloatingText {
  final String text;
  Offset position;
  final Color color;
  double life; // Lifetime from 1.0 down to 0.0
  final double maxLife;

  FloatingText({
    required this.text,
    required this.position,
    required this.color,
    this.maxLife = 1.2,
  }) : life = 1.0;

  void update(double deltaTime) {
    position += Offset(0, -35.0 * deltaTime);
    life -= deltaTime / maxLife;
    if (life < 0) life = 0;
  }

  bool get isDead => life <= 0;
}

class GameManager extends ChangeNotifier {
  GamePlayState state = GamePlayState.menu;

  static const bool isDevMode = true; // Set to true to unlock all levels in dev mode
  int maxUnlockedLevel = 1;

  // Screen constraints
  double screenWidth = 360.0;
  double screenHeight = 640.0;

  // Game Entities
  late Spaceship spaceship;
  final List<LaserBullet> laserBullets = []; // Player bullets
  final List<LaserBullet> enemyLasers = [];  // Enemy bullets
  final List<DroneEnemy> drones = [];
  final List<PowerUp> powerUps = [];
  final List<Coin> fallingCoins = [];
  final ParticleSystem particleSystem = ParticleSystem();

  // Scrolling Starfield background
  final List<Offset> stars = [];
  final List<double> starSpeeds = [];

  // Floating text messages
  final List<FloatingText> floatingTexts = [];

  // Game Stats
  int score = 0;
  int highScore = 0;
  int lives = 3;
  int level = 1;
  int combo = 0;
  double comboTimer = 0.0;
  int coins = 100000; // Currency (Dev Mode)

  // Screen Shake
  double shakeIntensity = 0.0;
  Offset shakeOffset = Offset.zero;

  // Timers
  double slowMotionTimer = 0.0;
  double playerShootCooldown = 0.0;

  // Upgrades
  int mainCannonLevel = 1;
  int homingMissileLevel = 0;
  int shieldMaxLevel = 1;
  int magnetLevel = 0;

  // Homing Missiles
  final List<HomingMissile> missiles = [];
  double missileCooldown = 0.0;

  // Cosmetics & Shop
  String equippedSpaceship = 'paddle_pink';
  String equippedLaser = 'ball_white';
  List<String> unlockedItems = ['paddle_pink', 'ball_white'];
  
  bool isEndlessMode = false;
  int endlessHighScore = 0;

  final AudioController audio = AudioController();
  final math.Random _random = math.Random();

  // Adapter properties for UI compatibility
  double get widePaddleTimer => spaceship.tripleShotTimer;
  double get laserPaddleTimer => spaceship.rapidFireTimer;
  double get empStormTimer => slowMotionTimer;
  double get glitchTimer => spaceship.shieldActive ? 8.0 : 0.0;
  List<String> get unlockedAchievements => [];
  int get dronesDestroyedThisSession => 0;
  String get equippedPaddle => equippedSpaceship;
  String get equippedBall => equippedLaser;

  GameManager() {
    spaceship = Spaceship(
      positionX: screenWidth / 2,
      positionY: screenHeight - 80.0,
    );
    resetGame();
    audio.init();
    loadSavedData();
  }

  void update(double deltaTime) {
    updateGame(deltaTime);
  }

  void shootLasers() {
    if (state == GamePlayState.playing) {
      _firePlayerLasers();
    }
  }

  void handlePaddleDrag(double deltaX) {
    handleSpaceshipDrag(deltaX, 0.0);
  }

  void initializeScreen(double width, double height) {
    if (screenWidth == width && screenHeight == height) return;
    screenWidth = width;
    screenHeight = height;
    
    spaceship.positionX = screenWidth / 2;
    spaceship.positionY = screenHeight - 80.0;
    
    _initStars();
    if (state == GamePlayState.menu) {
      resetGame();
    }
  }

  void _initStars() {
    stars.clear();
    starSpeeds.clear();
    for (int i = 0; i < 40; i++) {
      stars.add(Offset(
        _random.nextDouble() * screenWidth,
        _random.nextDouble() * screenHeight,
      ));
      starSpeeds.add(0.3 + _random.nextDouble() * 0.7); // parallax
    }
  }

  // --- Sprite Preloading & Assets ---
  final Map<String, ui.Image> spriteImages = {};
  bool spritesLoaded = false;

  Future<void> _preloadSprites() async {
    try {
      final list = {
        'ship_pink': 'assets/images/ship_pink.png',
        'ship_cyan': 'assets/images/ship_cyan.png',
        'ship_gold': 'assets/images/ship_gold.png',
        'drone_normal': 'assets/images/drone_normal.png',
        'drone_armored': 'assets/images/drone_armored.png',
        'drone_explosive': 'assets/images/drone_explosive.png',
        'drone_boss': 'assets/images/drone_boss.png',
        'coin': 'assets/images/coin.png',
        'bullet_player': 'assets/images/bullet_player.png',
        'bullet_enemy': 'assets/images/bullet_enemy.png',
        'missile': 'assets/images/missile.png',
      };
      for (var entry in list.entries) {
        final rawImg = await _loadSprite(entry.value);
        spriteImages[entry.key] = await _makeBackgroundTransparent(rawImg);
      }
      spritesLoaded = true;
    } catch (e) {
      // Fail silently
    }
  }

  Future<ui.Image> _makeBackgroundTransparent(ui.Image image) async {
    try {
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return image;

      final Uint8List pixels = byteData.buffer.asUint8List();
      final int len = pixels.length;

      for (int i = 0; i < len; i += 4) {
        int r = pixels[i];
        int g = pixels[i + 1];
        int b = pixels[i + 2];
        // Make very dark background pixels completely transparent (RGB < 55)
        if (r < 55 && g < 55 && b < 55) {
          pixels[i + 3] = 0; // Alpha = 0
        }
      }

      final Completer<ui.Image> completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        image.width,
        image.height,
        ui.PixelFormat.rgba8888,
        (ui.Image img) {
          completer.complete(img);
        },
      );
      return completer.future;
    } catch (e) {
      return image;
    }
  }

  Future<ui.Image> _loadSprite(String path) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  // --- Persistence Methods (shared_preferences) ---
  Future<void> loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      highScore = prefs.getInt('highScore') ?? 0;
      coins = 100000; // Dev Mode Override (Originally loaded from SharedPreferences)
      maxUnlockedLevel = prefs.getInt('maxUnlockedLevel') ?? 1;
      equippedSpaceship = prefs.getString('equippedPaddle') ?? 'paddle_pink';
      equippedLaser = prefs.getString('equippedBall') ?? 'ball_white';
      unlockedItems = prefs.getStringList('unlockedItems') ?? ['paddle_pink', 'ball_white'];
      endlessHighScore = prefs.getInt('endlessHighScore') ?? 0;

      // Upgrades
      mainCannonLevel = prefs.getInt('mainCannonLevel') ?? 1;
      homingMissileLevel = prefs.getInt('homingMissileLevel') ?? 0;
      shieldMaxLevel = prefs.getInt('shieldMaxLevel') ?? 1;
      magnetLevel = prefs.getInt('magnetLevel') ?? 0;
      
      // Load sprites
      await _preloadSprites();
      
      _applyCosmeticsToModels();
      notifyListeners();
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> saveGameStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', highScore);
      await prefs.setInt('coins', coins);
      await prefs.setInt('maxUnlockedLevel', maxUnlockedLevel);
      await prefs.setString('equippedPaddle', equippedSpaceship);
      await prefs.setString('equippedBall', equippedLaser);
      await prefs.setStringList('unlockedItems', unlockedItems);
      await prefs.setInt('endlessHighScore', endlessHighScore);
    } catch (e) {
      // Fail silently
    }
  }

  void _applyCosmeticsToModels() {
    // Spaceship colors mapping
    if (equippedSpaceship == 'paddle_green' || equippedSpaceship == 'ship_cyan') {
      spaceship.color = const Color(0xFF00FFFF);
      spaceship.glowColor = const Color(0x9900FFFF);
      spaceship.skinId = 'ship_cyan';
    } else if (equippedSpaceship == 'paddle_gold' || equippedSpaceship == 'ship_gold') {
      spaceship.color = const Color(0xFFFFCC00);
      spaceship.glowColor = const Color(0x99FFCC00);
      spaceship.skinId = 'ship_gold';
    } else {
      spaceship.color = const Color(0xFFFF007F); // Neon Pink
      spaceship.glowColor = const Color(0x99FF007F);
      spaceship.skinId = 'ship_pink';
    }

    // Apply persistent upgrades to spaceship
    spaceship.mainCannonLevel = mainCannonLevel;
    spaceship.homingMissileLevel = homingMissileLevel;
    spaceship.shieldMaxLevel = shieldMaxLevel;
    spaceship.magnetLevel = magnetLevel;
  }

  // --- Shop Business Logic ---
  bool isUnlocked(String id) => unlockedItems.contains(id);

  bool buyCosmetic(String id, int cost) {
    if (coins >= cost && !isUnlocked(id)) {
      coins -= cost;
      unlockedItems.add(id);
      saveGameStats();
      audio.playSFX('buff');
      notifyListeners();
      return true;
    }
    return false;
  }

  bool buyUpgrade(String id, int cost) {
    if (coins >= cost) {
      if (id == 'main_cannon' && mainCannonLevel < 4) {
        coins -= cost;
        mainCannonLevel++;
        spaceship.mainCannonLevel = mainCannonLevel;
      } else if (id == 'homing_missile' && homingMissileLevel < 3) {
        coins -= cost;
        homingMissileLevel++;
        spaceship.homingMissileLevel = homingMissileLevel;
      } else if (id == 'shield_max' && shieldMaxLevel < 3) {
        coins -= cost;
        shieldMaxLevel++;
        spaceship.shieldMaxLevel = shieldMaxLevel;
      } else if (id == 'magnet' && magnetLevel < 3) {
        coins -= cost;
        magnetLevel++;
        spaceship.magnetLevel = magnetLevel;
      } else {
        return false;
      }
      saveGameStats();
      audio.playSFX('buff');
      notifyListeners();
      return true;
    }
    return false;
  }

  void equipCosmetic(String id, String category) {
    if (!isUnlocked(id)) return;
    if (category == 'spaceship' || category == 'paddle') {
      equippedSpaceship = id;
    } else if (category == 'laser' || category == 'ball') {
      equippedLaser = id;
    }
    saveGameStats();
    _applyCosmeticsToModels();
    audio.playSFX('hit');
    notifyListeners();
  }

  Color getLaserColor() {
    if (equippedLaser == 'ball_orange' || equippedLaser == 'laser_gold') {
      return const Color(0xFFFFCC00);
    } else if (equippedLaser == 'ball_purple' || equippedLaser == 'laser_violet') {
      return const Color(0xFFBD00FF);
    } else if (equippedLaser == 'ball_cyan') {
      return const Color(0xFF00FFCC);
    }
    return const Color(0xFF00FFFF); // Cyan default
  }

  Color getLaserGlowColor() {
    return getLaserColor().withOpacity(0.6);
  }



  // --- Core Game Loops & State Changes ---
  void resetGame() {
    score = 0;
    lives = 3;
    level = isEndlessMode ? 1 : level;
    combo = 0;
    comboTimer = 0.0;
    shakeIntensity = 0.0;
    shakeOffset = Offset.zero;
    slowMotionTimer = 0.0;
    playerShootCooldown = 0.0;

    fallingCoins.clear();
    laserBullets.clear();
    enemyLasers.clear();
    drones.clear();
    powerUps.clear();
    floatingTexts.clear();
    missiles.clear();
    missileCooldown = 0.0;

    spaceship.positionX = screenWidth / 2;
    spaceship.positionY = screenHeight - 80.0;
    spaceship.shieldActive = false;
    spaceship.shieldHealth = 0;
    spaceship.tripleShotTimer = 0.0;
    spaceship.rapidFireTimer = 0.0;
    
    _applyCosmeticsToModels();
    _initStars();

    // Populate level
    if (isEndlessMode) {
      _spawnEndlessWave();
    } else {
      drones.addAll(LevelManager.buildLevel(level, screenWidth));
    }
    notifyListeners();
  }

  void _spawnEndlessWave() {
    drones.clear();
    // Generate endless wave of drones based on score/level
    double margin = 30.0;
    double usableWidth = screenWidth - (margin * 2);
    int cols = 5;
    double colWidth = usableWidth / (cols - 1);
    double speedX = 40.0 + (level * 3);
    if (speedX > 100.0) speedX = 100.0;

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < cols; c++) {
        if (_random.nextDouble() < 0.20) continue; // gaps
        double roll = _random.nextDouble();
        DroneType type = DroneType.normal;
        int hp = 1;
        if (roll < 0.10) {
          type = DroneType.explosive;
        } else if (roll < 0.35) {
          type = DroneType.armored;
          hp = 2;
        }
        drones.add(DroneEnemy(
          position: Offset(margin + c * colWidth, 60.0 + r * 45.0),
          type: type,
          velocity: Offset((_random.nextBool() ? 1 : -1) * speedX, 8.0 + level * 2.0),
          health: hp,
          shootCooldown: 2.0 + _random.nextDouble() * 4.0,
        ));
      }
    }
  }

  void startGame() {
    audio.stopBGM().then((_) {
      audio.playBGM();
    });
    state = GamePlayState.playing;
    notifyListeners();
  }

  void pauseGame() {
    if (state == GamePlayState.playing) {
      state = GamePlayState.paused;
      audio.pauseBGM();
      notifyListeners();
    }
  }

  void resumeGame() {
    if (state == GamePlayState.paused) {
      state = GamePlayState.playing;
      audio.resumeBGM();
      notifyListeners();
    }
  }

  void exitToMenu() {
    state = GamePlayState.menu;
    audio.stopBGM();
    notifyListeners();
  }

  void nextLevel() {
    level++;
    if (level > maxUnlockedLevel) {
      maxUnlockedLevel = level;
      saveGameStats();
    }
    combo = 0;
    comboTimer = 0.0;
    slowMotionTimer = 0.0;
    playerShootCooldown = 0.0;
    
    laserBullets.clear();
    enemyLasers.clear();
    powerUps.clear();
    fallingCoins.clear();
    
    spaceship.positionX = screenWidth / 2;
    spaceship.positionY = screenHeight - 80.0;
    spaceship.shieldActive = false;
    spaceship.tripleShotTimer = 0.0;
    spaceship.rapidFireTimer = 0.0;

    _applyCosmeticsToModels();
    
    drones.clear();
    drones.addAll(LevelManager.buildLevel(level, screenWidth));
    
    state = GamePlayState.playing;
    audio.playBGM();
    notifyListeners();
  }

  void selectLevel(int selectedLevel) {
    score = 0;
    lives = 3;
    level = selectedLevel;
    combo = 0;
    comboTimer = 0.0;
    shakeIntensity = 0.0;
    shakeOffset = Offset.zero;
    slowMotionTimer = 0.0;
    playerShootCooldown = 0.0;
    
    fallingCoins.clear();
    laserBullets.clear();
    enemyLasers.clear();
    drones.clear();
    powerUps.clear();
    floatingTexts.clear();
    
    spaceship.positionX = screenWidth / 2;
    spaceship.positionY = screenHeight - 80.0;
    spaceship.shieldActive = false;
    spaceship.tripleShotTimer = 0.0;
    spaceship.rapidFireTimer = 0.0;
    
    _applyCosmeticsToModels();
    drones.addAll(LevelManager.buildLevel(level, screenWidth));
    
    state = GamePlayState.playing;
    audio.stopBGM().then((_) {
      audio.playBGM();
    });
    notifyListeners();
  }

  void handleSpaceshipDrag(double deltaX, double deltaY) {
    if (state != GamePlayState.playing) return;
    spaceship.move(deltaX, deltaY, screenWidth, screenHeight);
  }

  // --- Main Update Loop ---
  void updateGame(double deltaTime) {
    // 1. Update background star scrolling even in menus
    _updateStars(deltaTime);

    if (state != GamePlayState.playing) {
      // Keep updating particles and floating texts in non-playing states (like menu/gameover) for visuals
      particleSystem.update(deltaTime);
      _updateFloatingTexts(deltaTime);
      notifyListeners();
      return;
    }

    double enemyDeltaTime = slowMotionTimer > 0 ? deltaTime * 0.35 : deltaTime;
    if (slowMotionTimer > 0) {
      slowMotionTimer -= deltaTime;
    }

    // 2. Spaceship updates
    spaceship.updatePowerUps(deltaTime);

    // 3. Screen shake resolution
    if (shakeIntensity > 0) {
      shakeIntensity -= deltaTime * 15.0;
      if (shakeIntensity < 0) shakeIntensity = 0;
      shakeOffset = Offset(
        (_random.nextDouble() - 0.5) * 2 * shakeIntensity,
        (_random.nextDouble() - 0.5) * 2 * shakeIntensity,
      );
    } else {
      shakeOffset = Offset.zero;
    }

    // 4. Floating texts & Particle updates
    _updateFloatingTexts(deltaTime);
    particleSystem.update(deltaTime);

    // 5. Combo decays
    if (comboTimer > 0) {
      comboTimer -= deltaTime;
      if (comboTimer <= 0) {
        combo = 0;
      }
    }

    // 6. Player auto-shooting
    if (playerShootCooldown > 0) {
      playerShootCooldown -= deltaTime;
    }
    if (playerShootCooldown <= 0) {
      _firePlayerLasers();
      playerShootCooldown = spaceship.rapidFireTimer > 0 ? 0.16 : 0.32;
    }

    // 6b. Homing Missile firing
    if (spaceship.homingMissileLevel > 0) {
      if (missileCooldown > 0) {
        missileCooldown -= deltaTime;
      }
      if (missileCooldown <= 0) {
        missiles.add(HomingMissile(
          position: Offset(spaceship.positionX - 16.0, spaceship.positionY),
          velocity: const Offset(-45.0, -180.0),
        ));
        missiles.add(HomingMissile(
          position: Offset(spaceship.positionX + 16.0, spaceship.positionY),
          velocity: const Offset(45.0, -180.0),
        ));
        missileCooldown = 2.2 - (spaceship.homingMissileLevel * 0.4); // Lv 1: 1.8s, Lv 2: 1.4s, Lv 3: 1.0s
      }
    }

    // 7. Update player bullets
    for (int i = laserBullets.length - 1; i >= 0; i--) {
      laserBullets[i].update(deltaTime);
      if (laserBullets[i].position.dy < -20.0 || laserBullets[i].isDestroyed) {
        laserBullets.removeAt(i);
      }
    }

    // 7b. Update homing missiles
    for (int i = missiles.length - 1; i >= 0; i--) {
      missiles[i].update(deltaTime, drones);
      if (missiles[i].position.dy < -30.0 || missiles[i].isDestroyed) {
        missiles.removeAt(i);
      }
    }

    // 8. Update enemy bullets
    for (int i = enemyLasers.length - 1; i >= 0; i--) {
      enemyLasers[i].update(enemyDeltaTime);
      if (enemyLasers[i].position.dy > screenHeight + 20.0 || enemyLasers[i].isDestroyed) {
        enemyLasers.removeAt(i);
      }
    }

    // 9. Update falling items
    for (int i = fallingCoins.length - 1; i >= 0; i--) {
      fallingCoins[i].update(deltaTime, spaceshipPosition: Offset(spaceship.positionX, spaceship.positionY), magnetLevel: spaceship.magnetLevel);
      if (fallingCoins[i].position.dy > screenHeight + 20.0 || fallingCoins[i].isCollected) {
        fallingCoins.removeAt(i);
      }
    }
    for (int i = powerUps.length - 1; i >= 0; i--) {
      powerUps[i].update(deltaTime, spaceshipPosition: Offset(spaceship.positionX, spaceship.positionY), magnetLevel: spaceship.magnetLevel);
      if (powerUps[i].position.dy > screenHeight + 20.0 || powerUps[i].isCollected) {
        powerUps.removeAt(i);
      }
    }

    // 10. Update Drones & Firing
    for (int i = drones.length - 1; i >= 0; i--) {
      DroneEnemy drone = drones[i];

      drone.update(enemyDeltaTime, screenWidth);
      
      // Auto-shoot for drones
      if (drone.shootCooldown <= 0 && !drone.isDestroyed) {
        _fireEnemyLaser(drone);
        double minCD = drone.type == DroneType.boss ? 1.0 : 2.5;
        drone.shootCooldown = minCD + _random.nextDouble() * 3.5;
      }

      // If drone reaches spaceship's vertical plane, damage the player and bounce drone back up
      if (drone.position.dy > spaceship.positionY && !drone.isDestroyed) {
        drone.position = Offset(drone.position.dx, 50.0); // Wrap back to top
        if (spaceship.shieldActive) {
          spaceship.shieldActive = false;
          audio.playSFX('buff');
        } else {
          lives--;
          shakeIntensity = 8.0;
          audio.playSFX('lose');
          if (lives <= 0) {
            _triggerGameOver();
            return;
          }
        }
      }
    }

    // 11. Check Collisions
    _resolveCollisions();

    // 12. Level Clear check
    if (drones.isEmpty) {
      if (isEndlessMode) {
        level++;
        _spawnEndlessWave();
        audio.playSFX('win');
      } else {
        _triggerLevelComplete();
      }
    }

    notifyListeners();
  }

  void _updateStars(double deltaTime) {
    if (stars.isEmpty) _initStars();
    for (int i = 0; i < stars.length; i++) {
      double newY = stars[i].dy + starSpeeds[i] * 65.0 * deltaTime;
      if (newY > screenHeight) {
        newY = -10.0;
        stars[i] = Offset(_random.nextDouble() * screenWidth, newY);
      } else {
        stars[i] = Offset(stars[i].dx, newY);
      }
    }
  }

  void _updateFloatingTexts(double deltaTime) {
    for (int i = floatingTexts.length - 1; i >= 0; i--) {
      floatingTexts[i].update(deltaTime);
      if (floatingTexts[i].isDead) {
        floatingTexts.removeAt(i);
      }
    }
  }

  void _firePlayerLasers() {
    Color laserColor = getLaserColor();
    Color laserGlow = getLaserGlowColor();

    int cannonLvl = spaceship.mainCannonLevel;
    List<LaserBullet> baseBullets = [];

    switch (cannonLvl) {
      case 2:
        // Dual Lasers
        baseBullets.add(LaserBullet(
          position: Offset(spaceship.positionX - 8.0, spaceship.positionY - 15.0),
          velocity: const Offset(0.0, -480.0),
          isEnemy: false,
          color: laserColor,
          glowColor: laserGlow,
        ));
        baseBullets.add(LaserBullet(
          position: Offset(spaceship.positionX + 8.0, spaceship.positionY - 15.0),
          velocity: const Offset(0.0, -480.0),
          isEnemy: false,
          color: laserColor,
          glowColor: laserGlow,
        ));
        break;
      case 3:
        // Triple Lasers
        baseBullets.add(LaserBullet(
          position: Offset(spaceship.positionX, spaceship.positionY - 15.0),
          velocity: const Offset(0.0, -480.0),
          isEnemy: false,
          color: laserColor,
          glowColor: laserGlow,
        ));
        baseBullets.add(LaserBullet(
          position: Offset(spaceship.positionX - 10.0, spaceship.positionY - 10.0),
          velocity: const Offset(-60.0, -460.0),
          isEnemy: false,
          color: laserColor,
          glowColor: laserGlow,
        ));
        baseBullets.add(LaserBullet(
          position: Offset(spaceship.positionX + 10.0, spaceship.positionY - 10.0),
          velocity: const Offset(60.0, -460.0),
          isEnemy: false,
          color: laserColor,
          glowColor: laserGlow,
        ));
        break;
      case 4:
        // Wave Beam! (width = 18.0, height = 12.0)
        baseBullets.add(LaserBullet(
          position: Offset(spaceship.positionX, spaceship.positionY - 15.0),
          velocity: const Offset(0.0, -500.0),
          isEnemy: false,
          width: 18.0,
          height: 12.0,
          color: laserColor,
          glowColor: laserGlow,
        ));
        break;
      case 1:
      default:
        // Single Laser
        baseBullets.add(LaserBullet(
          position: Offset(spaceship.positionX, spaceship.positionY - 15.0),
          velocity: const Offset(0.0, -480.0),
          isEnemy: false,
          color: laserColor,
          glowColor: laserGlow,
        ));
        break;
    }

    // Apply Triple Shot temporary powerup: add 2 angled lasers on the sides if not already Level 3
    if (spaceship.tripleShotTimer > 0 && cannonLvl != 3) {
      baseBullets.add(LaserBullet(
        position: Offset(spaceship.positionX - 14.0, spaceship.positionY - 8.0),
        velocity: const Offset(-110.0, -450.0),
        isEnemy: false,
        color: laserColor,
        glowColor: laserGlow,
      ));
      baseBullets.add(LaserBullet(
        position: Offset(spaceship.positionX + 14.0, spaceship.positionY - 8.0),
        velocity: const Offset(110.0, -450.0),
        isEnemy: false,
        color: laserColor,
        glowColor: laserGlow,
      ));
    }

    laserBullets.addAll(baseBullets);
    audio.playSFX('hit');
  }

  void _fireEnemyLaser(DroneEnemy drone) {
    double speedY = 160.0 + (level * 5.0);
    if (speedY > 320.0) speedY = 320.0;

    if (drone.type == DroneType.boss) {
      // 1. Ultimate Cosmic Carrier (Level 20 Main Boss - 250 max HP)
      if (drone.maxHealth == 250) {
        // Circular 360-degree spray of 8 fireballs
        for (int i = 0; i < 8; i++) {
          double angleRad = i * (math.pi / 4.0);
          enemyLasers.add(LaserBullet(
            position: drone.position,
            velocity: Offset(math.cos(angleRad) * speedY * 0.8, math.sin(angleRad) * speedY * 0.8),
            isEnemy: true,
            color: const Color(0xFFBD00FF),
            glowColor: const Color(0x99BD00FF),
          ));
        }
        
        // Bomb rain from the sky!
        for (int i = 0; i < 5; i++) {
          double bombX = 30.0 + _random.nextDouble() * (screenWidth - 60.0);
          enemyLasers.add(LaserBullet(
            position: Offset(bombX, -15.0),
            velocity: Offset(0.0, speedY * 0.75),
            isEnemy: true,
            color: const Color(0xFFFF5555),
            glowColor: const Color(0x99FF5555),
            width: 8.0,
            height: 8.0,
          ));
        }
      } 
      // 2. Heavy Carrier Boss (Level 15 - 120 max HP)
      else if (drone.maxHealth == 120) {
        // 3-way spread + bomb rain
        enemyLasers.add(LaserBullet(
          position: drone.position,
          velocity: Offset(0, speedY),
          isEnemy: true,
          color: const Color(0xFFFF3377),
          glowColor: const Color(0x99FF3377),
        ));
        enemyLasers.add(LaserBullet(
          position: drone.position,
          velocity: Offset(-45.0, speedY * 0.95),
          isEnemy: true,
          color: const Color(0xFFFF3377),
          glowColor: const Color(0x99FF3377),
        ));
        enemyLasers.add(LaserBullet(
          position: drone.position,
          velocity: Offset(45.0, speedY * 0.95),
          isEnemy: true,
          color: const Color(0xFFFF3377),
          glowColor: const Color(0x99FF3377),
        ));
        
        // Bomb rain from the sky!
        for (int i = 0; i < 4; i++) {
          double bombX = 30.0 + _random.nextDouble() * (screenWidth - 60.0);
          enemyLasers.add(LaserBullet(
            position: Offset(bombX, -15.0),
            velocity: Offset(0.0, speedY * 0.75),
            isEnemy: true,
            color: const Color(0xFFFF3333),
            glowColor: const Color(0x99FF3333),
            width: 8.0,
            height: 8.0,
          ));
        }
      }
      // 3. Shield Destroyer Boss (Level 10 - 80 max HP or flanking in Level 20)
      else if (drone.maxHealth == 80 || (level == 20 && drone.position.dx > screenWidth / 2)) {
        // 5-way fan spread
        for (double angle in [-60.0, -30.0, 0.0, 30.0, 60.0]) {
          enemyLasers.add(LaserBullet(
            position: drone.position,
            velocity: Offset(angle, speedY * 0.95),
            isEnemy: true,
            color: const Color(0xFFFFCC00),
            glowColor: const Color(0x99FFCC00),
          ));
        }
      }
      // 4. Commander Boss (Level 5 - 40 max HP or flanking in Level 20)
      else {
        // 3-way spread
        enemyLasers.add(LaserBullet(
          position: drone.position,
          velocity: Offset(0, speedY),
          isEnemy: true,
          color: const Color(0xFFFF3377),
          glowColor: const Color(0x99FF3377),
        ));
        enemyLasers.add(LaserBullet(
          position: drone.position,
          velocity: Offset(-45.0, speedY * 0.95),
          isEnemy: true,
          color: const Color(0xFFFF3377),
          glowColor: const Color(0x99FF3377),
        ));
        enemyLasers.add(LaserBullet(
          position: drone.position,
          velocity: Offset(45.0, speedY * 0.95),
          isEnemy: true,
          color: const Color(0xFFFF3377),
          glowColor: const Color(0x99FF3377),
        ));
      }
    } else {
      // Standard single bullet downward
      enemyLasers.add(LaserBullet(
        position: drone.position,
        velocity: Offset(0, speedY),
        isEnemy: true,
        color: const Color(0xFFFF5555),
        glowColor: const Color(0x99FF5555),
      ));
    }
  }

  // --- Collision Resolutions ---
  void _resolveCollisions() {
    // 1. Player Lasers vs Drones
    for (var bullet in laserBullets) {
      for (var drone in drones) {
        if (PhysicsEngine.checkBulletEnemyCollision(bullet, drone)) {
          bullet.isDestroyed = true;
          int dmg = bullet.width > 10.0 ? 2 : 1;
          drone.health -= dmg;
          
          particleSystem.spawnExplosion(bullet.position, drone.color, count: 6);
          audio.playSFX('hit');

          if (drone.health <= 0) {
            drone.isDestroyed = true;
            _destroyDrone(drone);
          }
          break; // break drone loop to check next bullet
        }
      }
    }
    drones.removeWhere((d) => d.isDestroyed);

    // 1b. Homing Missiles vs Drones
    for (var missile in missiles) {
      for (var drone in drones) {
        if (PhysicsEngine.checkMissileEnemyCollision(missile, drone)) {
          missile.isDestroyed = true;
          drone.health -= 2; // Homing missiles deal double damage!
          
          particleSystem.spawnExplosion(missile.position, drone.color, count: 8);
          audio.playSFX('hit');

          if (drone.health <= 0) {
            drone.isDestroyed = true;
            _destroyDrone(drone);
          }
          break;
        }
      }
    }
    drones.removeWhere((d) => d.isDestroyed);

    // 2. Enemy Lasers vs Player
    for (var laser in enemyLasers) {
      if (PhysicsEngine.checkBulletSpaceshipCollision(laser, spaceship)) {
        laser.isDestroyed = true;
        _hitPlayer();
        break;
      }
    }

    // 3. Drone Body vs Player
    for (var drone in drones) {
      if (PhysicsEngine.checkEnemySpaceshipCollision(drone, spaceship)) {
        drone.isDestroyed = true;
        particleSystem.spawnExplosion(drone.position, drone.color, count: 15);
        _hitPlayer();
        break;
      }
    }
    drones.removeWhere((d) => d.isDestroyed);

    // 4. Collect Coins
    for (var coin in fallingCoins) {
      if (PhysicsEngine.checkCoinCollection(coin, spaceship)) {
        coin.isCollected = true;
        coins++;
        score += 50;
        audio.playSFX('coin');
        floatingTexts.add(FloatingText(
          text: "+1 Coin",
          position: coin.position,
          color: Colors.amberAccent,
        ));
      }
    }

    // 5. Collect PowerUps
    for (var powerUp in powerUps) {
      if (PhysicsEngine.checkPowerUpCollection(powerUp, spaceship)) {
        powerUp.isCollected = true;
        _applyPowerUp(powerUp);
      }
    }
  }

  void _destroyDrone(DroneEnemy drone) {
    particleSystem.spawnExplosion(drone.position, drone.color, count: 18);
    audio.playSFX('win'); // explosion sound

    // Combo and Score
    combo++;
    comboTimer = 2.5; // combo reset window
    int pointsGained = (drone.type == DroneType.boss ? 1500 : 100) * combo;
    score += pointsGained;

    floatingTexts.add(FloatingText(
      text: "+$pointsGained${combo > 1 ? ' (x$combo)' : ''}",
      position: drone.position,
      color: drone.color,
    ));

    // Handle Explosive Drone chains
    if (drone.type == DroneType.explosive) {
      _triggerExplosiveDroneChain(drone.position);
    }

    // Coin & PowerUp drops
    if (drone.type == DroneType.boss) {
      // Boss always drops massive coins
      for (int i = 0; i < 8; i++) {
        fallingCoins.add(Coin(
          position: drone.position + Offset(
            (_random.nextDouble() - 0.5) * 60,
            (_random.nextDouble() - 0.5) * 40,
          ),
        ));
      }
      // Boss drops high-tier buff
      powerUps.add(PowerUp(
        position: drone.position,
        type: _random.nextBool() ? PowerUpType.tripleShot : PowerUpType.rapidFire,
      ));
    } else {
      // Normal drops
      double roll = _random.nextDouble();
      if (roll < 0.25) {
        fallingCoins.add(Coin(position: drone.position));
      } else if (roll < 0.38) {
        // Spawn random buff
        PowerUpType randomType = PowerUpType.values[_random.nextInt(PowerUpType.values.length)];
        powerUps.add(PowerUp(position: drone.position, type: randomType));
      }
    }
  }

  void _triggerExplosiveDroneChain(Offset center) {
    double radius = 75.0;
    for (var d in drones) {
      if (d.isDestroyed) continue;
      double distance = (d.position - center).distance;
      if (distance <= radius) {
        d.health--;
        particleSystem.spawnExplosion(d.position, d.color, count: 6);
        if (d.health <= 0) {
          d.isDestroyed = true;
          // Deferred call to prevent stack overflow/concurrent issues
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _destroyDrone(d);
          });
        }
      }
    }
  }

  void _hitPlayer() {
    if (spaceship.shieldActive) {
      spaceship.shieldHealth--;
      audio.playSFX('buff');
      
      if (spaceship.shieldHealth <= 0) {
        spaceship.shieldActive = false;
        floatingTexts.add(FloatingText(
          text: "SHIELD DOWN!",
          position: Offset(spaceship.positionX, spaceship.positionY - 30),
          color: Colors.blueAccent,
        ));
      } else {
        floatingTexts.add(FloatingText(
          text: "SHIELD: ${spaceship.shieldHealth}/${spaceship.shieldMaxLevel}",
          position: Offset(spaceship.positionX, spaceship.positionY - 30),
          color: Colors.lightBlueAccent,
        ));
      }
      return;
    }

    lives--;
    combo = 0;
    shakeIntensity = 10.0;
    audio.playSFX('lose');

    if (lives <= 0) {
      _triggerGameOver();
    } else {
      floatingTexts.add(FloatingText(
        text: "CRITICAL HIT!",
        position: Offset(spaceship.positionX, spaceship.positionY - 30),
        color: Colors.redAccent,
      ));
    }
  }

  void _applyPowerUp(PowerUp powerUp) {
    audio.playSFX('buff');
    String text = "";
    Color textCol = powerUp.color;

    switch (powerUp.type) {
      case PowerUpType.tripleShot:
        spaceship.tripleShotTimer = 8.0;
        text = "TRIPLE SHOT!";
        break;
      case PowerUpType.shield:
        spaceship.shieldActive = true;
        spaceship.shieldHealth = spaceship.shieldMaxLevel;
        text = "SHIELD ACTIVATED!";
        break;
      case PowerUpType.slowMotion:
        slowMotionTimer = 8.0;
        text = "SLOW MOTION!";
        break;
      case PowerUpType.rapidFire:
        spaceship.rapidFireTimer = 8.0;
        text = "RAPID FIRE!";
        break;
      case PowerUpType.extraLife:
        lives = (lives + 1).clamp(0, 5);
        text = "+1 LIFE!";
        break;
    }

    floatingTexts.add(FloatingText(
      text: text,
      position: Offset(spaceship.positionX, spaceship.positionY - 40.0),
      color: textCol,
      maxLife: 1.8,
    ));
  }

  void _triggerGameOver() {
    state = GamePlayState.gameOver;
    audio.stopBGM();
    
    // High score save
    if (isEndlessMode) {
      if (score > endlessHighScore) {
        endlessHighScore = score;
      }
    } else {
      if (score > highScore) {
        highScore = score;
      }
    }
    saveGameStats();
    notifyListeners();
  }

  void _triggerLevelComplete() {
    state = GamePlayState.levelComplete;
    audio.stopBGM();
    audio.playSFX('win');
    
    if (score > highScore) {
      highScore = score;
    }
    if (level == maxUnlockedLevel) {
      maxUnlockedLevel++;
    }
    saveGameStats();
    notifyListeners();
  }
}
