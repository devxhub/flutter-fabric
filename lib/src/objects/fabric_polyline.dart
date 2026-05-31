import 'package:flutter/material.dart';
import 'fabric_object.dart';

class FabricPolyline extends FabricObject {
  FabricPolyline({
    required List<Offset> points,
    super.left,
    super.top,
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
  })  : _points = List.unmodifiable(points),
        super(
            width: _computeBounds(points).width,
            height: _computeBounds(points).height) {
    final bounds = _computeBounds(points);
    if (left == 0 && top == 0 && points.isNotEmpty) {
      set(left: bounds.left, top: bounds.top);
    } else {
      set(left: left, top: top);
    }
  }

  final List<Offset> _points;

  static Rect _computeBounds(List<Offset> pts) {
    if (pts.isEmpty) return Rect.zero;
    double minX = pts[0].dx,
        minY = pts[0].dy,
        maxX = pts[0].dx,
        maxY = pts[0].dy;
    for (final p in pts.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  String get type => 'polyline';

  @override
  void render(Canvas canvas, double w, double h) {
    if (_points.length < 2) return;
    final bounds = _computeBounds(_points);
    final path = Path();
    path.moveTo(_points[0].dx - bounds.left, _points[0].dy - bounds.top);
    for (int i = 1; i < _points.length; i++) {
      path.lineTo(_points[i].dx - bounds.left, _points[i].dy - bounds.top);
    }
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

  factory FabricPolyline.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List<dynamic>)
        .map((p) =>
            Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
        .toList();
    final o = FabricPolyline(points: pts, id: json['id'] as String?);
    o.applyJson(json);
    return o;
  }
}
