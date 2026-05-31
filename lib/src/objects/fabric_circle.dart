import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// A circle defined by a [radius].
///
/// [width] and [height] are set to `2 * radius` automatically.
class FabricCircle extends FabricObject {
  FabricCircle({
    super.left,
    super.top,
    double radius = 50,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.red,
    super.stroke = Colors.transparent,
    super.strokeWidth,
    super.selectable,
    super.visible,
    super.id,
    double startAngle = 0,
    double endAngle = 360,
  })  : _radius = radius,
        _startAngle = startAngle,
        _endAngle = endAngle,
        super(width: radius * 2, height: radius * 2);

  double _radius;
  double _startAngle; // degrees
  double _endAngle; // degrees

  double get radius => _radius;
  set radius(double v) {
    _radius = v;
    set(width: v * 2, height: v * 2);
  }

  @override
  String get type => 'circle';

  @override
  void render(Canvas canvas, double w, double h) {
    final r = w / 2;
    final center = Offset(r, r);
    if (_startAngle == 0 && _endAngle == 360) {
      if (fill != Colors.transparent) {
        canvas.drawCircle(center, r, fillPaint);
      }
      if (stroke != Colors.transparent && strokeWidth > 0) {
        canvas.drawCircle(center, r, strokePaint);
      }
    } else {
      final path = Path()
        ..moveTo(r, r)
        ..arcTo(
          Rect.fromCircle(center: center, radius: r),
          _startAngle * 3.14159265 / 180,
          (_endAngle - _startAngle) * 3.14159265 / 180,
          false,
        )
        ..close();
      if (fill != Colors.transparent) canvas.drawPath(path, fillPaint);
      if (stroke != Colors.transparent && strokeWidth > 0) {
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'radius': _radius,
        'startAngle': _startAngle,
        'endAngle': _endAngle,
      };

  factory FabricCircle.fromJson(Map<String, dynamic> json) {
    final o = FabricCircle(
      radius: (json['radius'] as num?)?.toDouble() ?? 50,
      startAngle: (json['startAngle'] as num?)?.toDouble() ?? 0,
      endAngle: (json['endAngle'] as num?)?.toDouble() ?? 360,
      id: json['id'] as String?,
    );
    o.applyJson(json);
    return o;
  }
}
