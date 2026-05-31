import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// A vector path object, compatible with SVG path `d` strings.
///
/// Example:
/// ```dart
/// FabricPath(
///   pathData: 'M 10 10 L 100 100 Q 150 50 200 100 Z',
///   fill: Colors.teal,
/// )
/// ```
class FabricPath extends FabricObject {
  FabricPath({
    required String pathData,
    super.left,
    super.top,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.teal,
    super.stroke = Colors.transparent,
    super.strokeWidth,
    super.selectable,
    super.visible,
    super.id,
  })  : _pathData = pathData,
        super(width: 200, height: 200) {
    _computedPath = _parseSvgPath(pathData);
    final bounds = _computedPath.getBounds();
    set(
      left: left != 0 ? left : bounds.left,
      top: top != 0 ? top : bounds.top,
      width: bounds.width == 0 ? 1 : bounds.width,
      height: bounds.height == 0 ? 1 : bounds.height,
    );
  }

  String _pathData;
  late Path _computedPath;

  String get pathData => _pathData;
  set pathData(String v) {
    _pathData = v;
    _computedPath = _parseSvgPath(v);
    final b = _computedPath.getBounds();
    set(width: b.width, height: b.height);
    notifyListeners();
  }

  @override
  String get type => 'path';

  // Very small SVG-path parser — supports M, L, H, V, C, Q, A, Z (absolute).
  static Path _parseSvgPath(String d) {
    final path = Path();
    final tokens = d
        .replaceAllMapped(
            RegExp(r'([MmLlHhVvCcQqAaSsZz])'), (m) => ' ${m[0]} ')
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .toList();

    int i = 0;
    double cx = 0, cy = 0;
    double? qcpx, qcpy; // last quadratic control point

    double next() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      final cmd = tokens[i++];
      switch (cmd) {
        case 'M':
          cx = next(); cy = next();
          path.moveTo(cx, cy);
          break;
        case 'm':
          cx += next(); cy += next();
          path.moveTo(cx, cy);
          break;
        case 'L':
          cx = next(); cy = next();
          path.lineTo(cx, cy);
          break;
        case 'l':
          cx += next(); cy += next();
          path.lineTo(cx, cy);
          break;
        case 'H':
          cx = next();
          path.lineTo(cx, cy);
          break;
        case 'h':
          cx += next();
          path.lineTo(cx, cy);
          break;
        case 'V':
          cy = next();
          path.lineTo(cx, cy);
          break;
        case 'v':
          cy += next();
          path.lineTo(cx, cy);
          break;
        case 'C':
          final c1x = next(), c1y = next();
          final c2x = next(), c2y = next();
          cx = next(); cy = next();
          path.cubicTo(c1x, c1y, c2x, c2y, cx, cy);
          break;
        case 'Q':
          qcpx = next(); qcpy = next();
          cx = next(); cy = next();
          path.quadraticBezierTo(qcpx, qcpy, cx, cy);
          break;
        case 'A':
          final rx = next(), ry = next();
          final rot = next();
          final largeArc = next() != 0;
          final sweep = next() != 0;
          final ex = next(), ey = next();
          _arcTo(path, cx, cy, ex, ey, rx, ry, rot, largeArc, sweep);
          cx = ex; cy = ey;
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
        default:
          break;
      }
    }
    return path;
  }

  /// Converts an SVG arc to cubic bezier curves and appends to [path].
  static void _arcTo(
      Path path, double x1, double y1, double x2, double y2,
      double rx, double ry, double xRot, bool largeArc, bool sweep) {
    if (x1 == x2 && y1 == y2) return;
    if (rx == 0 || ry == 0) {
      path.lineTo(x2, y2);
      return;
    }
    final phi = xRot * math.pi / 180;
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);
    final dx = (x1 - x2) / 2;
    final dy = (y1 - y2) / 2;
    final x1p = cosPhi * dx + sinPhi * dy;
    final y1p = -sinPhi * dx + cosPhi * dy;
    var x1pSq = x1p * x1p;
    var y1pSq = y1p * y1p;
    var rxSq = rx * rx;
    var rySq = ry * ry;
    var ratio = x1pSq / rxSq + y1pSq / rySq;
    if (ratio > 1) {
      final sq = math.sqrt(ratio);
      rx *= sq; ry *= sq;
      rxSq = rx * rx; rySq = ry * ry;
    }
    final num = rxSq * rySq - rxSq * y1pSq - rySq * x1pSq;
    final den = rxSq * y1pSq + rySq * x1pSq;
    final sq = den == 0 ? 0.0 : math.sqrt((num / den).abs());
    final k = (largeArc == sweep ? -1 : 1) * sq;
    final cxp = k * rx * y1p / ry;
    final cyp = -k * ry * x1p / rx;
    final cx2 = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2;
    final cy2 = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2;
    final startAngle = _angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
    var sweepAngle = _angle(
        (x1p - cxp) / rx, (y1p - cyp) / ry,
        (-x1p - cxp) / rx, (-y1p - cyp) / ry);
    if (!sweep && sweepAngle > 0) sweepAngle -= 2 * math.pi;
    if (sweep && sweepAngle < 0) sweepAngle += 2 * math.pi;
    path.addArc(
        Rect.fromCenter(
            center: Offset(cx2, cy2), width: rx * 2, height: ry * 2),
        startAngle,
        sweepAngle);
  }

  static double _angle(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final len = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    final a = math.acos((dot / len).clamp(-1.0, 1.0));
    return ux * vy - uy * vx < 0 ? -a : a;
  }

  @override
  void render(Canvas canvas, double w, double h) {
    final bounds = _computedPath.getBounds();
    final sx = bounds.width == 0 ? 1.0 : w / bounds.width;
    final sy = bounds.height == 0 ? 1.0 : h / bounds.height;
    canvas.save();
    canvas.scale(sx, sy);
    canvas.translate(-bounds.left, -bounds.top);
    if (fill != Colors.transparent) canvas.drawPath(_computedPath, fillPaint);
    if (stroke != Colors.transparent && strokeWidth > 0) {
      canvas.drawPath(_computedPath, strokePaint);
    }
    canvas.restore();
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'path': _pathData,
      };

  factory FabricPath.fromJson(Map<String, dynamic> json) {
    final o = FabricPath(
      pathData: json['path'] as String? ?? '',
      id: json['id'] as String?,
    );
    o.applyJson(json);
    return o;
  }
}
