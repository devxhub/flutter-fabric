import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../canvas/fabric_controller.dart';
import '../objects/fabric_path.dart';
import 'base_brush.dart';

/// A spray-paint brush that scatters random dots around the pointer.
///
/// Each move event deposits a cluster of points; on pointer-up the accumulated
/// dots are converted to a compound SVG path and added as a [FabricPath].
///
/// Example:
/// ```dart
/// controller.freeDrawingBrush = SprayBrush(
///   color: Colors.deepOrange,
///   width: 30,
///   density: 25,
///   dotRadius: 1.5,
/// );
/// controller.isDrawingMode = true;
/// ```
class SprayBrush extends BaseBrush {
  SprayBrush({
    super.color = Colors.black,
    super.width = 30,
    super.opacity = 1.0,
    this.density = 20,
    this.dotRadius = 1.5,
    this.randomOpacity = false,
  });

  /// Number of dots deposited per pointer-move event.
  final int density;

  /// Radius of each individual dot (in canvas pixels).
  final double dotRadius;

  /// When true, each dot gets a random opacity for a more organic look.
  final bool randomOpacity;

  final _random = math.Random();

  // Accumulated dots: list of (cx, cy, r) triples.
  final List<_Dot> _dots = [];

  // Live dots for the current frame (rendered but not yet committed).
  final List<_Dot> _frameDots = [];

  // ── BaseBrush ──────────────────────────────────────────────────────────────

  @override
  void onPointerDown(Offset point, FabricController controller) {
    _dots.clear();
    _frameDots.clear();
    _sprayAt(point);
    notifyListeners();
  }

  @override
  void onPointerMove(Offset point, FabricController controller) {
    _sprayAt(point);
    notifyListeners();
  }

  @override
  void onPointerUp(Offset point, FabricController controller) {
    _sprayAt(point);
    if (_dots.isNotEmpty) {
      final svgPath = _dotsToSvgPath(_dots);
      controller.add(FabricPath(
        pathData: svgPath,
        fill: color,
        stroke: Colors.transparent,
        opacity: opacity,
      ));
    }
    _dots.clear();
    _frameDots.clear();
    notifyListeners();
  }

  @override
  void render(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final dot in _dots) {
      paint.color = color.withValues(
        alpha: randomOpacity ? (opacity * dot.opacityFactor).clamp(0.0, 1.0) : opacity,
      );
      canvas.drawCircle(Offset(dot.x, dot.y), dot.r, paint);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _sprayAt(Offset center) {
    for (int i = 0; i < density; i++) {
      // Uniform distribution within a circle of radius [width/2].
      final angle = _random.nextDouble() * 2 * math.pi;
      final dist = math.sqrt(_random.nextDouble()) * (width / 2);
      final x = center.dx + dist * math.cos(angle);
      final y = center.dy + dist * math.sin(angle);
      _dots.add(_Dot(x, y, dotRadius, _random.nextDouble()));
    }
  }

  /// Converts dot list to an SVG path made up of tiny circle approximations
  /// using four cubic Bézier curves (standard technique).
  static String _dotsToSvgPath(List<_Dot> dots) {
    final buf = StringBuffer();
    for (final dot in dots) {
      final r = dot.r;
      final cx = dot.x;
      final cy = dot.y;
      // Approximate a circle with 4 cubic bezier curves.
      // Control point offset: r * 0.5523.
      const k = 0.5523;
      final kr = r * k;
      buf.write(
        'M ${_f(cx - r)} ${_f(cy)} '
        'C ${_f(cx - r)} ${_f(cy - kr)} ${_f(cx - kr)} ${_f(cy - r)} ${_f(cx)} ${_f(cy - r)} '
        'C ${_f(cx + kr)} ${_f(cy - r)} ${_f(cx + r)} ${_f(cy - kr)} ${_f(cx + r)} ${_f(cy)} '
        'C ${_f(cx + r)} ${_f(cy + kr)} ${_f(cx + kr)} ${_f(cy + r)} ${_f(cx)} ${_f(cy + r)} '
        'C ${_f(cx - kr)} ${_f(cy + r)} ${_f(cx - r)} ${_f(cy + kr)} ${_f(cx - r)} ${_f(cy)} Z ',
      );
    }
    return buf.toString().trim();
  }

  static String _f(double v) => v.toStringAsFixed(2);
}

class _Dot {
  const _Dot(this.x, this.y, this.r, this.opacityFactor);
  final double x, y, r, opacityFactor;
}
