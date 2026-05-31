import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// A rectangle that can optionally have rounded corners.
class FabricRect extends FabricObject {
  FabricRect({
    super.left,
    super.top,
    super.width,
    super.height,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.blue,
    super.stroke = Colors.transparent,
    super.strokeWidth,
    super.selectable,
    super.visible,
    super.id,
    double rx = 0,
    double ry = 0,
  })  : _rx = rx,
        _ry = ry;

  double _rx, _ry;

  double get rx => _rx;
  double get ry => _ry;

  set rx(double v) {
    _rx = v;
    notifyListeners();
  }

  set ry(double v) {
    _ry = v;
    notifyListeners();
  }

  @override
  String get type => 'rect';

  @override
  void render(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    final rr = RRect.fromRectXY(rect, _rx, _ry);
    if (fill != Colors.transparent) canvas.drawRRect(rr, fillPaint);
    if (stroke != Colors.transparent && strokeWidth > 0) {
      canvas.drawRRect(rr, strokePaint);
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'rx': _rx,
        'ry': _ry,
      };

  factory FabricRect.fromJson(Map<String, dynamic> json) {
    final o = FabricRect(
      rx: (json['rx'] as num?)?.toDouble() ?? 0,
      ry: (json['ry'] as num?)?.toDouble() ?? 0,
      id: json['id'] as String?,
    );
    o.applyJson(json);
    return o;
  }
}
