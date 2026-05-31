import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../canvas/fabric_controller.dart';
import 'base_brush.dart';

/// A brush that stamps a repeating pattern (e.g., circles, stars) along the stroke.
class PatternBrush extends BaseBrush {
  PatternBrush({
    super.color = Colors.black,
    super.width = 20,
    super.opacity = 1.0,
    required this.patternBuilder,
    this.spacing = 10.0,
  });

  final Widget Function(Color color, double size) patternBuilder;
  final double spacing;

  final List<Offset> _points = [];

  @override
  void onPointerDown(Offset point, FabricController controller) {
    _points.clear();
    _points.add(point);
  }

  @override
  void onPointerMove(Offset point, FabricController controller) {
    final last = _points.last;
    if ((point - last).distance >= spacing) {
      _points.add(point);
      notifyListeners();
    }
  }

  @override
  void onPointerUp(Offset point, FabricController controller) {
    // For simplicity, we don't commit patterns to a permanent object.
    // You could collect them into a group of small paths.
    _points.clear();
  }

  @override
  void render(Canvas canvas, Size size) {
    for (final pt in _points) {
      // This would render a Flutter widget onto the canvas, which is complex.
      // We'll draw a simple circle as placeholder.
      canvas.drawCircle(
          pt, width / 2, Paint()..color = color.withValues(alpha: opacity));
    }
  }
}

/// A brush that sprays circles of varying sizes.
class CircleBrush extends BaseBrush {
  CircleBrush({
    super.color = Colors.black,
    super.width = 30,
    super.opacity = 1.0,
    this.minRadius = 2,
    this.maxRadius = 8,
    this.density = 15,
  });

  final double minRadius, maxRadius;
  final int density;
  final List<_Circledot> _dots = [];

  @override
  void onPointerDown(Offset point, FabricController controller) {
    _dots.clear();
    _spray(point);
  }

  @override
  void onPointerMove(Offset point, FabricController controller) {
    _spray(point);
  }

  @override
  void onPointerUp(Offset point, FabricController controller) {
    _spray(point);
    // Commit as a single path of circles? We'll just leave them as dots.
    // For permanent storage, you'd need to create a group of small FabricCircle objects.
    _dots.clear();
  }

  void _spray(Offset center) {
    final random = math.Random();
    for (int i = 0; i < density; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final dist = math.sqrt(random.nextDouble()) * (width / 2);
      final x = center.dx + dist * math.cos(angle);
      final y = center.dy + dist * math.sin(angle);
      final radius = minRadius + random.nextDouble() * (maxRadius - minRadius);
      _dots.add(_Circledot(Offset(x, y), radius));
    }
  }

  @override
  void render(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    for (final dot in _dots) {
      canvas.drawCircle(dot.center, dot.radius, paint);
    }
  }
}

class _Circledot {
  _Circledot(this.center, this.radius);
  final Offset center;
  final double radius;
}
