import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

typedef FabricBlendMode = BlendMode;

abstract class FabricObject with ChangeNotifier {
  FabricObject({
    double left = 0,
    double top = 0,
    double width = 100,
    double height = 100,
    double angle = 0,
    double scaleX = 1,
    double scaleY = 1,
    double opacity = 1.0,
    Color fill = Colors.transparent,
    Color stroke = Colors.black,
    double strokeWidth = 1.0,
    bool selectable = true,
    bool visible = true,
    bool evented = true,
    FabricBlendMode blendMode = BlendMode.srcOver,
    bool flipX = false,
    bool flipY = false,
    double skewX = 0,
    double skewY = 0,
    String? id,
  })  : _left = left,
        _top = top,
        _width = width,
        _height = height,
        _angle = angle,
        _scaleX = scaleX,
        _scaleY = scaleY,
        _opacity = opacity,
        _fill = fill,
        _stroke = stroke,
        _strokeWidth = strokeWidth,
        _selectable = selectable,
        _visible = visible,
        _evented = evented,
        _blendMode = blendMode,
        _flipX = flipX,
        _flipY = flipY,
        _skewX = skewX,
        _skewY = skewY,
        id = id ?? _generateId();

  final String id;
  static String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  // ── Geometry ──────────────────────────────────────────────────────────────

  double _left, _top, _width, _height, _angle, _scaleX, _scaleY;
  double get left => _left;
  double get top => _top;
  double get width => _width;
  double get height => _height;
  double get angle => _angle;
  double get scaleX => _scaleX;
  double get scaleY => _scaleY;
  double get scaledWidth => _width * _scaleX;
  double get scaledHeight => _height * _scaleY;
  Offset get center => Offset(_left + scaledWidth / 2, _top + scaledHeight / 2);

  // ── Appearance ────────────────────────────────────────────────────────────

  double _opacity;
  Color _fill;
  Color _stroke;
  double _strokeWidth;
  bool _selectable, _visible, _evented;
  FabricBlendMode _blendMode;

  double get opacity => _opacity;
  Color get fill => _fill;
  Color get stroke => _stroke;
  double get strokeWidth => _strokeWidth;
  bool get selectable => _selectable;
  bool get visible => _visible;
  bool get evented => _evented;
  FabricBlendMode get blendMode => _blendMode;

  // ── Flip & Skew ───────────────────────────────────────────────────────────

  bool _flipX, _flipY;
  double _skewX, _skewY;

  bool get flipX => _flipX;
  set flipX(bool v) {
    _flipX = v;
    notifyListeners();
  }

  bool get flipY => _flipY;
  set flipY(bool v) {
    _flipY = v;
    notifyListeners();
  }

  double get skewX => _skewX;
  set skewX(double v) {
    _skewX = v;
    notifyListeners();
  }

  double get skewY => _skewY;
  set skewY(double v) {
    _skewY = v;
    notifyListeners();
  }

  // ── Locking ───────────────────────────────────────────────────────────────

  bool _lockMovementX = false,
      _lockMovementY = false,
      _lockRotation = false,
      _lockScalingX = false,
      _lockScalingY = false,
      _lockScaling = false;

  bool get lockMovementX => _lockMovementX;
  set lockMovementX(bool v) {
    _lockMovementX = v;
    notifyListeners();
  }

  bool get lockMovementY => _lockMovementY;
  set lockMovementY(bool v) {
    _lockMovementY = v;
    notifyListeners();
  }

  bool get lockRotation => _lockRotation;
  set lockRotation(bool v) {
    _lockRotation = v;
    notifyListeners();
  }

  bool get lockScalingX => _lockScalingX;
  set lockScalingX(bool v) {
    _lockScalingX = v;
    notifyListeners();
  }

  bool get lockScalingY => _lockScalingY;
  set lockScalingY(bool v) {
    _lockScalingY = v;
    notifyListeners();
  }

  bool get lockScaling => _lockScaling;
  set lockScaling(bool v) {
    _lockScaling = v;
    notifyListeners();
  }

  // ── Shadow ────────────────────────────────────────────────────────────────

  Shadow? _shadow;
  Shadow? get shadow => _shadow;
  set shadow(Shadow? v) {
    _shadow = v;
    notifyListeners();
  }

  // ── Gradient / custom fill ────────────────────────────────────────────────

  Paint? _customFillPaint;
  Paint? get customFillPaint => _customFillPaint;
  set customFillPaint(Paint? p) {
    _customFillPaint = p;
    notifyListeners();
  }

  // ── Paints ────────────────────────────────────────────────────────────────

  Paint get fillPaint {
    if (_customFillPaint != null) return _customFillPaint!;
    return Paint()
      ..color = _fill
      ..style = PaintingStyle.fill;
  }

  Paint get strokePaint => Paint()
    ..color = _stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // ── Bounding boxes ────────────────────────────────────────────────────────

  Rect get boundingRect =>
      Rect.fromLTWH(_left, _top, scaledWidth, scaledHeight);

  Rect get aabb {
    final rad = _angle * math.pi / 180;
    final cx = _left + scaledWidth / 2;
    final cy = _top + scaledHeight / 2;
    final hw = scaledWidth / 2, hh = scaledHeight / 2;
    final cosA = math.cos(rad).abs(), sinA = math.sin(rad).abs();
    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: hw * cosA * 2 + hh * sinA * 2,
      height: hw * sinA * 2 + hh * cosA * 2,
    );
  }

  bool containsPoint(Offset point) {
    if (!_evented || !_visible) return false;
    final rad = -_angle * math.pi / 180;
    final cx = _left + scaledWidth / 2;
    final cy = _top + scaledHeight / 2;
    final dx = point.dx - cx, dy = point.dy - cy;
    final rx = dx * math.cos(rad) - dy * math.sin(rad);
    final ry = dx * math.sin(rad) + dy * math.cos(rad);
    return rx.abs() <= scaledWidth / 2 && ry.abs() <= scaledHeight / 2;
  }

  // ── set() ─────────────────────────────────────────────────────────────────

  void set({
    double? left,
    double? top,
    double? width,
    double? height,
    double? angle,
    double? scaleX,
    double? scaleY,
    double? opacity,
    Color? fill,
    Color? stroke,
    double? strokeWidth,
    bool? selectable,
    bool? visible,
    bool? flipX,
    bool? flipY,
    double? skewX,
    double? skewY,
    FabricBlendMode? blendMode,
  }) {
    _left = left ?? _left;
    _top = top ?? _top;
    _width = width ?? _width;
    _height = height ?? _height;
    _angle = angle ?? _angle;
    _scaleX = scaleX ?? _scaleX;
    _scaleY = scaleY ?? _scaleY;
    _opacity = opacity ?? _opacity;
    _fill = fill ?? _fill;
    _stroke = stroke ?? _stroke;
    _strokeWidth = strokeWidth ?? _strokeWidth;
    _selectable = selectable ?? _selectable;
    _visible = visible ?? _visible;
    _flipX = flipX ?? _flipX;
    _flipY = flipY ?? _flipY;
    _skewX = skewX ?? _skewX;
    _skewY = skewY ?? _skewY;
    _blendMode = blendMode ?? _blendMode;
    notifyListeners();
  }

  // ── Paint ─────────────────────────────────────────────────────────────────

  void paint(Canvas canvas, Size size) {
    if (!_visible) return;

    canvas.save();

    final cx = _left + scaledWidth / 2;
    final cy = _top + scaledHeight / 2;

    canvas.translate(cx, cy);
    canvas.rotate(_angle * math.pi / 180);
    _applySkewFlip(canvas);
    canvas.translate(-scaledWidth / 2, -scaledHeight / 2);

    if (_shadow != null) _drawShadow(canvas);

    canvas.saveLayer(
      Rect.fromLTWH(0, 0, scaledWidth, scaledHeight),
      Paint()
        ..blendMode = _blendMode
        ..color = Color.fromARGB((_opacity * 255).round(), 255, 255, 255),
    );
    render(canvas, scaledWidth, scaledHeight);
    canvas.restore(); // saveLayer

    canvas.restore(); // translate/rotate/flip
  }

  void _applySkewFlip(Canvas canvas) {
    if (_skewX != 0 || _skewY != 0) {
      final m = Matrix4.identity()
        ..setEntry(0, 1, math.tan(_skewX * math.pi / 180))
        ..setEntry(1, 0, math.tan(_skewY * math.pi / 180));
      canvas.transform(m.storage);
    }
    if (_flipX || _flipY) {
      canvas.scale(_flipX ? -1.0 : 1.0, _flipY ? -1.0 : 1.0);
    }
  }

  void _drawShadow(Canvas canvas) {
    final s = _shadow!;
    final sigma = s.blurRadius / 2.0;

    // Draw a blurred, tinted copy behind the actual shape.
    canvas.saveLayer(
      null,
      Paint()
        ..imageFilter =
            ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    canvas.saveLayer(
      null,
      Paint()..colorFilter =
          ui.ColorFilter.mode(s.color, BlendMode.srcIn),
    );
    canvas.translate(s.offset.dx, s.offset.dy);
    render(canvas, scaledWidth, scaledHeight);
    canvas.restore(); // colorFilter layer
    canvas.restore(); // blur layer
  }

  // ── Subclass contract ─────────────────────────────────────────────────────

  void render(Canvas canvas, double w, double h);

  String get type;

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'left': _left,
        'top': _top,
        'width': _width,
        'height': _height,
        'angle': _angle,
        'scaleX': _scaleX,
        'scaleY': _scaleY,
        'opacity': _opacity,
        'fill': _fill.toARGB32(),
        'stroke': _stroke.toARGB32(),
        'strokeWidth': _strokeWidth,
        'selectable': _selectable,
        'visible': _visible,
        'flipX': _flipX,
        'flipY': _flipY,
        'skewX': _skewX,
        'skewY': _skewY,
        'lockMovementX': _lockMovementX,
        'lockMovementY': _lockMovementY,
        'lockRotation': _lockRotation,
        'lockScalingX': _lockScalingX,
        'lockScalingY': _lockScalingY,
        'lockScaling': _lockScaling,
      };

  void applyJson(Map<String, dynamic> json) {
    _left = (json['left'] as num?)?.toDouble() ?? _left;
    _top = (json['top'] as num?)?.toDouble() ?? _top;
    _width = (json['width'] as num?)?.toDouble() ?? _width;
    _height = (json['height'] as num?)?.toDouble() ?? _height;
    _angle = (json['angle'] as num?)?.toDouble() ?? _angle;
    _scaleX = (json['scaleX'] as num?)?.toDouble() ?? _scaleX;
    _scaleY = (json['scaleY'] as num?)?.toDouble() ?? _scaleY;
    _opacity = (json['opacity'] as num?)?.toDouble() ?? _opacity;
    if (json['fill'] != null) _fill = Color(json['fill'] as int);
    if (json['stroke'] != null) _stroke = Color(json['stroke'] as int);
    _strokeWidth = (json['strokeWidth'] as num?)?.toDouble() ?? _strokeWidth;
    _selectable = json['selectable'] as bool? ?? _selectable;
    _visible = json['visible'] as bool? ?? _visible;
    _flipX = json['flipX'] as bool? ?? false;
    _flipY = json['flipY'] as bool? ?? false;
    _skewX = (json['skewX'] as num?)?.toDouble() ?? 0;
    _skewY = (json['skewY'] as num?)?.toDouble() ?? 0;
    _lockMovementX = json['lockMovementX'] as bool? ?? false;
    _lockMovementY = json['lockMovementY'] as bool? ?? false;
    _lockRotation = json['lockRotation'] as bool? ?? false;
    _lockScalingX = json['lockScalingX'] as bool? ?? false;
    _lockScalingY = json['lockScalingY'] as bool? ?? false;
    _lockScaling = json['lockScaling'] as bool? ?? false;
  }

  @override
  String toString() => 'FabricObject(type: $type, id: $id)';
}
