import 'package:flutter/material.dart';

class BlackHole {
  Offset position;
  final double radius;
  final double pullForce;
  double lifeTimer;
  final double maxDuration;

  BlackHole({
    required this.position,
    this.radius = 80.0,
    this.pullForce = 140.0,
    this.maxDuration = 7.0,
  }) : lifeTimer = maxDuration;

  void update(double deltaTime) {
    lifeTimer -= deltaTime;
  }

  bool get isExpired => lifeTimer <= 0.0;

  // Gravitational force pull algorithm
  Offset getPullForce(Offset targetPos, double deltaTime) {
    Offset direction = position - targetPos;
    double dist = direction.distance;

    if (dist < 6.0) return Offset.zero; // Near zero force at exact center
    if (dist > radius * 2.5) return Offset.zero; // Too far from gravity field

    // Inverse distance strength mapping
    double strength = (1.0 - (dist / (radius * 2.5))).clamp(0.0, 1.0) * pullForce;
    return direction.normalized * strength * deltaTime;
  }
}

extension OffsetNormalize on Offset {
  Offset get normalized {
    double d = distance;
    if (d == 0.0) return Offset.zero;
    return Offset(dx / d, dy / d);
  }
}
