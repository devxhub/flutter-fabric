import 'package:flutter/material.dart';
import '../canvas/fabric_controller.dart';
import '../objects/fabric_path.dart';
import 'base_brush.dart';

/// A smooth pencil-like brush that records pointer positions and converts
/// them to an SVG path (via [FabricPath]) when the stroke ends.
///
/// Uses simple midpoint smoothing to produce fluid curves.
class PencilBrush extends BaseBrush {
  PencilBrush({
    super.color = Colors.black,
    super.width = 4,
    super.opacity = 1.0,
    this.decimate = 2.0,
  });

  /// Minimum distance between recorded points (reduces noise).
  final double decimate;

  final List<Offset> _points = [];

  @override
  void onPointerDown(Offset point, FabricController controller) {
    _points
      ..clear()
      ..add(point);
  }

  @override
  void onPointerMove(Offset point, FabricController controller) {
    if (_points.isEmpty ||
        (_points.last - point).distance >= decimate) {
      _points.add(point);
      notifyListeners();
    }
  }

  @override
  void onPointerUp(Offset point, FabricController controller) {
    _points.add(point);
    if (_points.length >= 2) {
      final svgPath = _pointsToSvgPath(_points);
      controller.add(FabricPath(
        pathData: svgPath,
        stroke: color,
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
    final path = _buildPath(_points);
    canvas.drawPath(path, brushPaint);
  }

  /// Convert a list of points to a smooth SVG path using midpoint method.
  static String _pointsToSvgPath(List<Offset> pts) {
    if (pts.length == 1) {
      return 'M ${pts[0].dx} ${pts[0].dy} '
          'L ${pts[0].dx + 0.1} ${pts[0].dy + 0.1}';
    }
    final buf = StringBuffer();
    buf.write('M ${_f(pts[0].dx)} ${_f(pts[0].dy)}');
    for (int i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      buf.write(
          ' Q ${_f(pts[i].dx)} ${_f(pts[i].dy)} ${_f(mid.dx)} ${_f(mid.dy)}');
    }
    final last = pts.last;
    buf.write(' L ${_f(last.dx)} ${_f(last.dy)}');
    return buf.toString();
  }

  static Path _buildPath(List<Offset> pts) {
    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  static String _f(double v) => v.toStringAsFixed(2);
}
