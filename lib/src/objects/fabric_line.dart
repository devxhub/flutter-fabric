import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// A straight line between two points.
class FabricLine extends FabricObject {
  FabricLine({
    double x1 = 0,
    double y1 = 0,
    double x2 = 100,
    double y2 = 0,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.transparent,
    super.stroke = Colors.black,
    super.strokeWidth = 2,
    super.selectable,
    super.visible,
    super.id,
  })  : _x1 = x1,
        _y1 = y1,
        _x2 = x2,
        _y2 = y2,
        super(
          left: math.min(x1, x2),
          top: math.min(y1, y2),
          width: (x2 - x1).abs().clamp(1, double.infinity),
          height: (y2 - y1).abs().clamp(1, double.infinity),
        );

  double _x1, _y1, _x2, _y2;

  double get x1 => _x1;
  double get y1 => _y1;
  double get x2 => _x2;
  double get y2 => _y2;

  @override
  String get type => 'line';

  @override
  void render(Canvas canvas, double w, double h) {
    final minX = math.min(_x1, _x2);
    final minY = math.min(_y1, _y2);
    final p1 = Offset(_x1 - minX, _y1 - minY);
    final p2 = Offset(_x2 - minX, _y2 - minY);
    canvas.drawLine(p1, p2, strokePaint);
  }

  @override
  bool containsPoint(Offset point) {
    return aabb.inflate(strokeWidth + 4).contains(point);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'x1': _x1,
        'y1': _y1,
        'x2': _x2,
        'y2': _y2,
      };

  factory FabricLine.fromJson(Map<String, dynamic> json) {
    final o = FabricLine(
      x1: (json['x1'] as num?)?.toDouble() ?? 0,
      y1: (json['y1'] as num?)?.toDouble() ?? 0,
      x2: (json['x2'] as num?)?.toDouble() ?? 100,
      y2: (json['y2'] as num?)?.toDouble() ?? 0,
      id: json['id'] as String?,
    );
    o.applyJson(json);
    return o;
  }
}
