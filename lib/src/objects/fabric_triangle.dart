import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// An isosceles triangle fitting within its bounding box.
class FabricTriangle extends FabricObject {
  FabricTriangle({
    super.left,
    super.top,
    super.width = 100,
    super.height = 80,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.green,
    super.stroke = Colors.transparent,
    super.strokeWidth,
    super.selectable,
    super.visible,
    super.id,
  });

  @override
  String get type => 'triangle';

  @override
  void render(Canvas canvas, double w, double h) {
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    if (fill != Colors.transparent) canvas.drawPath(path, fillPaint);
    if (stroke != Colors.transparent && strokeWidth > 0) {
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  Map<String, dynamic> toJson() => super.toJson();

  factory FabricTriangle.fromJson(Map<String, dynamic> json) {
    final o = FabricTriangle(id: json['id'] as String?);
    o.applyJson(json);
    return o;
  }
}
