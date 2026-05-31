import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A collection of math helpers used throughout flutter_fabric.
///
/// All methods are static so no instantiation is needed.
abstract final class FabricMath {
  // ── Angle conversion ───────────────────────────────────────────────────────

  /// Convert [degrees] to radians.
  static double degreesToRadians(double degrees) => degrees * math.pi / 180.0;

  /// Convert [radians] to degrees.
  static double radiansToDegrees(double radians) => radians * 180.0 / math.pi;

  /// Normalise [degrees] to the range [0, 360).
  static double normalizeAngle(double degrees) =>
      ((degrees % 360) + 360) % 360;

  // ── Point / vector utilities ───────────────────────────────────────────────

  /// Rotate [point] around [pivot] by [angleDegrees].
  static Offset rotatePoint(Offset point, Offset pivot, double angleDegrees) {
    final rad = degreesToRadians(angleDegrees);
    final cos = math.cos(rad);
    final sin = math.sin(rad);
    final dx = point.dx - pivot.dx;
    final dy = point.dy - pivot.dy;
    return Offset(
      pivot.dx + dx * cos - dy * sin,
      pivot.dy + dx * sin + dy * cos,
    );
  }

  /// Linear interpolation between [a] and [b] by factor [t] (0 → 1).
  static double lerp(double a, double b, double t) => a + (b - a) * t;

  /// Linear interpolation between two [Offset]s.
  static Offset lerpOffset(Offset a, Offset b, double t) =>
      Offset(lerp(a.dx, b.dx, t), lerp(a.dy, b.dy, t));

  /// Distance between two points.
  static double distance(Offset a, Offset b) => (b - a).distance;

  /// Midpoint between two points.
  static Offset midpoint(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  /// Clamp [value] between [min] and [max].
  static double clamp(double value, double min, double max) =>
      value.clamp(min, max);

  // ── Bounding-box helpers ───────────────────────────────────────────────────

  /// Compute the axis-aligned bounding box of a rotated rectangle.
  ///
  /// [rect] is the unrotated rectangle; [angleDegrees] is the rotation.
  /// Returns the AABB that fully contains the rotated rectangle.
  static Rect rotatedBoundingBox(Rect rect, double angleDegrees) {
    final rad = degreesToRadians(angleDegrees);
    final cos = math.cos(rad).abs();
    final sin = math.sin(rad).abs();
    final hw = rect.width / 2;
    final hh = rect.height / 2;
    final newHW = hw * cos + hh * sin;
    final newHH = hw * sin + hh * cos;
    final cx = rect.left + hw;
    final cy = rect.top + hh;
    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: newHW * 2,
      height: newHH * 2,
    );
  }

  /// Whether [rectA] and [rectB] intersect (or touch).
  static bool rectsIntersect(Rect rectA, Rect rectB) =>
      rectA.overlaps(rectB);

  /// Compute the union bounding box of a list of [rects].
  static Rect boundingBoxOfRects(List<Rect> rects) {
    if (rects.isEmpty) return Rect.zero;
    double left = rects.first.left;
    double top = rects.first.top;
    double right = rects.first.right;
    double bottom = rects.first.bottom;
    for (final r in rects.skip(1)) {
      if (r.left < left) left = r.left;
      if (r.top < top) top = r.top;
      if (r.right > right) right = r.right;
      if (r.bottom > bottom) bottom = r.bottom;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  // ── Viewport / zoom ────────────────────────────────────────────────────────

  /// Convert a screen-space [point] to canvas-space given [zoom] and
  /// [viewportOffset] (the canvas translation in screen pixels).
  static Offset screenToCanvas(
    Offset point, {
    required double zoom,
    required Offset viewportOffset,
  }) =>
      (point - viewportOffset) / zoom;

  /// Convert a canvas-space [point] to screen-space.
  static Offset canvasToScreen(
    Offset point, {
    required double zoom,
    required Offset viewportOffset,
  }) =>
      point * zoom + viewportOffset;

  /// Compute the new viewport offset so that [focalPoint] (screen coords)
  /// remains stationary when zoom changes from [oldZoom] to [newZoom].
  static Offset zoomToPoint({
    required Offset focalPoint,
    required Offset currentViewportOffset,
    required double oldZoom,
    required double newZoom,
  }) {
    final delta = focalPoint - currentViewportOffset;
    return focalPoint - delta * (newZoom / oldZoom);
  }

  // ── Polygon helpers ────────────────────────────────────────────────────────

  /// Compute the centroid (average point) of a polygon.
  static Offset centroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    final sum = points.fold(Offset.zero, (a, b) => a + b);
    return sum / points.length.toDouble();
  }

  /// Signed area of a polygon (positive = CCW winding in screen coords).
  static double signedPolygonArea(List<Offset> points) {
    final n = points.length;
    if (n < 3) return 0;
    double area = 0;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += points[i].dx * points[j].dy;
      area -= points[j].dx * points[i].dy;
    }
    return area / 2;
  }

  /// Whether [point] is inside the polygon defined by [vertices] (ray casting).
  static bool pointInPolygon(Offset point, List<Offset> vertices) {
    final n = vertices.length;
    if (n < 3) return false;
    bool inside = false;
    int j = n - 1;
    for (int i = 0; i < n; i++) {
      final xi = vertices[i].dx, yi = vertices[i].dy;
      final xj = vertices[j].dx, yj = vertices[j].dy;
      final intersect = ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }

  // ── Numeric helpers ────────────────────────────────────────────────────────

  /// Snap [value] to the nearest multiple of [step].
  static double snapToGrid(double value, double step) {
    if (step <= 0) return value;
    return (value / step).round() * step;
  }

  /// Snap [angle] to the nearest multiple of [stepDegrees].
  static double snapAngle(double angle, double stepDegrees) =>
      snapToGrid(normalizeAngle(angle), stepDegrees);

  /// Returns the sign of [v]: −1, 0, or +1.
  static int sign(double v) => v == 0 ? 0 : (v < 0 ? -1 : 1);

  /// Precise sin / cos for common angles to avoid floating-point noise.
  static double preciseSin(double angleDeg) {
    final normalized = normalizeAngle(angleDeg);
    if (normalized == 0 || normalized == 180) return 0;
    if (normalized == 90) return 1;
    if (normalized == 270) return -1;
    return math.sin(degreesToRadians(angleDeg));
  }

  static double preciseCos(double angleDeg) {
    final normalized = normalizeAngle(angleDeg);
    if (normalized == 90 || normalized == 270) return 0;
    if (normalized == 0) return 1;
    if (normalized == 180) return -1;
    return math.cos(degreesToRadians(angleDeg));
  }

  // ── Matrix 2x2 helpers ─────────────────────────────────────────────────────

  /// Build a 2-element rotation matrix [cos, sin, -sin, cos] for [angleDeg].
  static List<double> rotationMatrix2x2(double angleDeg) {
    final rad = degreesToRadians(angleDeg);
    return [math.cos(rad), math.sin(rad), -math.sin(rad), math.cos(rad)];
  }

  /// Apply a 2×2 matrix [m] to [point] (no translation).
  static Offset applyMatrix2x2(List<double> m, Offset point) => Offset(
        m[0] * point.dx + m[2] * point.dy,
        m[1] * point.dx + m[3] * point.dy,
      );

  // ── Colour utilities ───────────────────────────────────────────────────────

  /// Linearly interpolate between two [Color]s.
  static Color lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  /// Returns the perceived luminance of [color] (0 = dark, 1 = bright).
  static double luminance(Color color) => color.computeLuminance();

  /// Returns [Colors.white] or [Colors.black] whichever contrasts more with
  /// [background] — useful for label colours.
  static Color contrastingColor(Color background) =>
      luminance(background) > 0.4 ? Colors.black : Colors.white;
}
