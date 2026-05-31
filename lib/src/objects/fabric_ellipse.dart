import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// An ellipse with independent [rx] and [ry] radii.
class FabricEllipse extends FabricObject {
  FabricEllipse({
    super.left,
    super.top,
    double rx = 60,
    double ry = 40,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.orange,
    super.stroke = Colors.transparent,
    super.strokeWidth,
    super.selectable,
    super.visible,
    super.id,
  })  : _rx = rx,
        _ry = ry,
        super(width: rx * 2, height: ry * 2);

  double _rx, _ry;

  double get rx => _rx;
  double get ry => _ry;

  set rx(double v) {
    _rx = v;
    set(width: v * 2);
    notifyListeners();
  }

  set ry(double v) {
    _ry = v;
    set(height: v * 2);
    notifyListeners();
  }

  @override
  String get type => 'ellipse';

  @override
  void render(Canvas canvas, double w, double h) {
    final hasStroke = stroke != Colors.transparent && strokeWidth > 0;
    final inset = hasStroke ? strokeWidth / 2 : 0.0;
    final oval = Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2);
    if (fill != Colors.transparent) canvas.drawOval(oval, fillPaint);
    if (hasStroke) canvas.drawOval(oval, strokePaint);
  }

  @override
  Map<String, dynamic> toJson() =>
      {...super.toJson(), 'rx': _rx, 'ry': _ry};

  factory FabricEllipse.fromJson(Map<String, dynamic> json) {
    final o = FabricEllipse(
      rx: (json['rx'] as num?)?.toDouble() ?? 60,
      ry: (json['ry'] as num?)?.toDouble() ?? 40,
      id: json['id'] as String?,
    );
    o.applyJson(json);
    return o;
  }
}
