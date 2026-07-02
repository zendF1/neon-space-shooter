import 'models/spaceship.dart';
import 'models/drone_enemy.dart';
import 'models/laser_bullet.dart';
import 'models/homing_missile.dart';
import 'models/power_up.dart';
import 'models/coin.dart';

class PhysicsEngine {
  /// Checks collision between a Laser Bullet and a Drone Enemy.
  static bool checkBulletEnemyCollision(LaserBullet bullet, DroneEnemy drone) {
    if (bullet.isDestroyed || drone.isDestroyed) return false;
    return bullet.rect.overlaps(drone.rect);
  }

  /// Checks collision between a Homing Missile and a Drone Enemy.
  static bool checkMissileEnemyCollision(HomingMissile missile, DroneEnemy drone) {
    if (missile.isDestroyed || drone.isDestroyed) return false;
    return missile.rect.overlaps(drone.rect);
  }

  /// Checks collision between an enemy Laser Bullet and the Player's Spaceship.
  static bool checkBulletSpaceshipCollision(LaserBullet bullet, Spaceship spaceship) {
    if (bullet.isDestroyed) return false;
    return bullet.rect.overlaps(spaceship.rect);
  }

  /// Checks collision between a Drone Enemy body and the Player's Spaceship.
  static bool checkEnemySpaceshipCollision(DroneEnemy drone, Spaceship spaceship) {
    if (drone.isDestroyed) return false;
    return drone.rect.overlaps(spaceship.rect);
  }

  /// Checks if the Player's Spaceship collects a PowerUp.
  static bool checkPowerUpCollection(PowerUp powerUp, Spaceship spaceship) {
    if (powerUp.isCollected || powerUp.isExpired) return false;
    return powerUp.getRect().overlaps(spaceship.rect);
  }

  /// Checks if the Player's Spaceship collects a Coin.
  static bool checkCoinCollection(Coin coin, Spaceship spaceship) {
    if (coin.isCollected) return false;
    return coin.getRect().overlaps(spaceship.rect);
  }
}
