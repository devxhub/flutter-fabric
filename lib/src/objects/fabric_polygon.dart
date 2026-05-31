import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// An arbitrary filled/stroked polygon defined by a list of [points].
class FabricPolygon extends FabricObject {
  FabricPolygon({
    required List<Offset> points,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.purple,
    super.stroke = Colors.transparent,
    super.strokeWidth,
    super.selectable,
    super.visible,
    super.id,
  })  : _points = List.unmodifiable(points),
        super(
          left: points.isEmpty ? 0 : points.map((p) => p.dx).reduce(math.min),
          top: points.isEmpty ? 0 : points.map((p) => p.dy).reduce(math.min),
          width: points.isEmpty
              ? 0
              : points.map((p) => p.dx).reduce(math.max) -
                  points.map((p) => p.dx).reduce(math.min),
          height: points.isEmpty
              ? 0
              : points.map((p) => p.dy).reduce(math.max) -
                  points.map((p) => p.dy).reduce(math.min),
        );

  final List<Offset> _points;
  List<Offset> get points => _points;

  @override
  String get type => 'polygon';

  @override
  void render(Canvas canvas, double w, double h) {
    if (_points.isEmpty) return;
    final minX = _points.map((p) => p.dx).reduce(math.min);
    final minY = _points.map((p) => p.dy).reduce(math.min);
    final path = Path()
      ..moveTo(_points[0].dx - minX, _points[0].dy - minY);
    for (final p in _points.skip(1)) {
      path.lineTo(p.dx - minX, p.dy - minY);
    }
    path.close();
    if (fill != Colors.transparent) canvas.drawPath(path, fillPaint);
    if (stroke != Colors.transparent && strokeWidth > 0) {
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'points': _points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      };

  factory FabricPolygon.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List<dynamic>)
        .map((p) => Offset(
            (p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
        .toList();
    final o = FabricPolygon(points: pts, id: json['id'] as String?);
    o.applyJson(json);
    return o;
  }
}
