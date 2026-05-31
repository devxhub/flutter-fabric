import 'package:flutter/material.dart';
import '../canvas/fabric_controller.dart';
import '../objects/fabric_path.dart';
import 'base_brush.dart';

/// A brush that "erases" by painting strokes in the canvas background colour.
///
/// Because Flutter's [Canvas] uses a fully opaque background, true pixel
/// erasure requires a compositing layer.  This brush approximates erasure by
/// drawing a filled stroke matching [FabricController.backgroundColor].  For
/// best results keep the canvas background a solid colour.
class EraserBrush extends BaseBrush {
  EraserBrush({
    super.width = 20,
    super.opacity = 1.0,
    this.decimate = 2.0,
  }) : super(color: Colors.white);

  final double decimate;

  final List<Offset> _points = [];

  @override
  void onPointerDown(Offset point, FabricController controller) {
    color = controller.backgroundColor;
    _points
      ..clear()
      ..add(point);
  }

  @override
  void onPointerMove(Offset point, FabricController controller) {
    if (_points.isEmpty || (_points.last - point).distance >= decimate) {
      _points.add(point);
      notifyListeners();
    }
  }

  @override
  void onPointerUp(Offset point, FabricController controller) {
    _points.add(point);
    if (_points.length >= 2) {
      controller.add(FabricPath(
        pathData: _toSvgPath(_points),
        stroke: controller.backgroundColor,
        fill: Colors.transparent,
        strokeWidth: width,
        opacity: opacity,
      ));
    }
    _points.clear();
    notifyListeners();
  }

  @override
  void render(Canvas canvas, Size size) {
    if (_points.length < 2) {
      if (_points.length == 1) {
        canvas.drawCircle(_points.first, width / 2, brushPaint);
      }
      return;
    }
    final path = Path()..moveTo(_points[0].dx, _points[0].dy);
    for (int i = 1; i < _points.length - 1; i++) {
      final mid = (_points[i] + _points[i + 1]) / 2;
      path.quadraticBezierTo(_points[i].dx, _points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(_points.last.dx, _points.last.dy);
    canvas.drawPath(path, brushPaint);
  }

  static String _toSvgPath(List<Offset> pts) {
    if (pts.length == 1) {
      return 'M ${pts[0].dx} ${pts[0].dy} L ${pts[0].dx + 0.1} ${pts[0].dy}';
    }
    final buf = StringBuffer('M ${pts[0].dx.toStringAsFixed(2)} ${pts[0].dy.toStringAsFixed(2)}');
    for (int i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      buf.write(' Q ${pts[i].dx.toStringAsFixed(2)} ${pts[i].dy.toStringAsFixed(2)}'
          ' ${mid.dx.toStringAsFixed(2)} ${mid.dy.toStringAsFixed(2)}');
    }
    buf.write(' L ${pts.last.dx.toStringAsFixed(2)} ${pts.last.dy.toStringAsFixed(2)}');
    return buf.toString();
  }
}
