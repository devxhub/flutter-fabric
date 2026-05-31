import 'package:flutter/material.dart';
import '../canvas/fabric_controller.dart';

/// Abstract base class for free-drawing brushes.
///
/// Subclass this and implement [onPointerDown], [onPointerMove],
/// [onPointerUp], and [render] to create custom brushes.
abstract class BaseBrush with ChangeNotifier {
  BaseBrush({
    Color color = Colors.black,
    double width = 4,
    double opacity = 1.0,
  })  : _color = color,
        _width = width,
        _opacity = opacity;

  Color _color;
  double _width;
  double _opacity;

  Color get color => _color;
  set color(Color v) {
    _color = v;
    notifyListeners();
  }

  double get width => _width;
  set width(double v) {
    _width = v;
    notifyListeners();
  }

  double get opacity => _opacity;
  set opacity(double v) {
    _opacity = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  Paint get brushPaint => Paint()
    ..color = _color.withValues(alpha: _opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = _width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  /// Called when the pointer is first pressed.
  void onPointerDown(Offset point, FabricController controller);

  /// Called as the pointer moves.
  void onPointerMove(Offset point, FabricController controller);

  /// Called when the pointer is released. Should add the finished
  /// [FabricObject] to the [controller].
  void onPointerUp(Offset point, FabricController controller);

  /// Paint the in-progress stroke onto [canvas]. Size is the canvas size.
  void render(Canvas canvas, Size size);
}
