import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../objects/fabric_object.dart';
import '../canvas/fabric_controller.dart';

/// The size of each corner/edge handle knob.
const double _kHandleSize = 12.0;

/// Hit-test radius around a handle (slightly larger than visual size).
const double _kHandleHitRadius = 16.0;

/// Minimum object dimension to prevent degeneracy during scaling.
const double _kMinDimension = 4.0;

/// Which handle is being dragged.
enum _HandleType {
  topLeft,
  topCenter,
  topRight,
  middleRight,
  bottomRight,
  bottomCenter,
  bottomLeft,
  middleLeft,
  rotate,
  none,
}

/// An overlay widget that renders selection handles around the active
/// [FabricObject] and translates pointer gestures into move / scale / rotate
/// operations on it.
///
/// Place this on top of [FabricCanvas] using a [Stack]:
///
/// ```dart
/// Stack(
///   children: [
///     FabricCanvas(controller: controller),
///     SelectionOverlay(controller: controller),
///   ],
/// )
/// ```
///
/// [FabricCanvas] already includes [SelectionOverlay] internally, so you only
/// need to add it manually if you opt out of the default canvas widget.
class SelectionOverlay extends StatefulWidget {
  const SelectionOverlay({
    super.key,
    required this.controller,
    this.handleColor = Colors.white,
    this.borderColor = Colors.blue,
    this.rotateHandleColor = Colors.blue,
    this.handleStrokeColor = Colors.blue,
    this.borderWidth = 1.5,
    this.rotateHandleDistance = 24.0,
    this.showScaleHandles = true,
    this.showRotateHandle = true,
    this.lockAspectRatio = false,
  });

  final FabricController controller;

  /// Fill colour of the square corner / edge handles.
  final Color handleColor;

  /// Colour of the dashed / solid selection border.
  final Color borderColor;

  /// Colour of the circular rotate handle.
  final Color rotateHandleColor;

  /// Stroke colour drawn around each handle knob.
  final Color handleStrokeColor;

  /// Width of the selection border.
  final double borderWidth;

  /// Distance the rotate handle sits above the top-centre handle.
  final double rotateHandleDistance;

  /// Whether to show the eight scale handles.
  final bool showScaleHandles;

  /// Whether to show the rotate handle above the top-centre.
  final bool showRotateHandle;

  /// When true, corner handles maintain the object's aspect ratio.
  final bool lockAspectRatio;

  @override
  State<SelectionOverlay> createState() => _SelectionOverlayState();
}

class _SelectionOverlayState extends State<SelectionOverlay> {
  // ── Drag state ─────────────────────────────────────────────────────────────
  _HandleType _activeHandle = _HandleType.none;

  // Snapshot values captured at drag-start.
  Offset _dragStart = Offset.zero;
  double _startLeft = 0;
  double _startTop = 0;
  double _startWidth = 0;
  double _startHeight = 0;
  double _startScaleX = 0;
  double _startScaleY = 0;
  double _startAngle = 0;
  Offset _startCenter = Offset.zero;

  FabricController get _ctrl => widget.controller;

  FabricObject? get _obj => _ctrl.activeObject;

  // ── Coordinate helpers ─────────────────────────────────────────────────────

  /// Convert a canvas-space point to screen-space.
  Offset _toScreen(Offset canvas) =>
      canvas * _ctrl.zoom + _ctrl.viewportTransform;

  /// Convert a screen-space point to canvas-space.
  Offset _toCanvas(Offset screen) =>
      (screen - _ctrl.viewportTransform) / _ctrl.zoom;

  // ── Handle positions in screen space ──────────────────────────────────────

  /// Returns the eight handle positions + rotate handle in screen coords,
  /// already rotated around the object centre.
  Map<_HandleType, Offset> _handlePositions(FabricObject obj) {
    final cx = obj.left + obj.scaledWidth / 2;
    final cy = obj.top + obj.scaledHeight / 2;
    final hw = obj.scaledWidth / 2;
    final hh = obj.scaledHeight / 2;
    final angle = obj.angle;

    Offset rot(double dx, double dy) {
      final rad = angle * math.pi / 180;
      final rx = dx * math.cos(rad) - dy * math.sin(rad);
      final ry = dx * math.sin(rad) + dy * math.cos(rad);
      return _toScreen(Offset(cx + rx, cy + ry));
    }

    final topCenterScreen = rot(0, -hh);
    final rotateOffset = _applyRotation(
      Offset(0, -(hh + widget.rotateHandleDistance / _ctrl.zoom)),
      angle,
      _toScreen(Offset(cx, cy)),
    );

    return {
      _HandleType.topLeft: rot(-hw, -hh),
      _HandleType.topCenter: topCenterScreen,
      _HandleType.topRight: rot(hw, -hh),
      _HandleType.middleRight: rot(hw, 0),
      _HandleType.bottomRight: rot(hw, hh),
      _HandleType.bottomCenter: rot(0, hh),
      _HandleType.bottomLeft: rot(-hw, hh),
      _HandleType.middleLeft: rot(-hw, 0),
      _HandleType.rotate: rotateOffset,
    };
  }

  Offset _applyRotation(Offset delta, double angleDeg, Offset pivot) {
    final rad = angleDeg * math.pi / 180;
    final dx = delta.dx * _ctrl.zoom;
    final dy = delta.dy * _ctrl.zoom;
    final rx = dx * math.cos(rad) - dy * math.sin(rad);
    final ry = dx * math.sin(rad) + dy * math.cos(rad);
    return pivot + Offset(rx, ry);
  }

  // ── Hit-testing ────────────────────────────────────────────────────────────

  _HandleType _hitTest(Offset screenPoint, Map<_HandleType, Offset> positions) {
    // Rotate handle first (smaller target, check priority)
    if (widget.showRotateHandle) {
      final rp = positions[_HandleType.rotate]!;
      if ((screenPoint - rp).distance <= _kHandleHitRadius) {
        return _HandleType.rotate;
      }
    }
    if (widget.showScaleHandles) {
      for (final entry in positions.entries) {
        if (entry.key == _HandleType.rotate) continue;
        if ((screenPoint - entry.value).distance <= _kHandleHitRadius) {
          return entry.key;
        }
      }
    }
    return _HandleType.none;
  }

  // ── Drag handlers ──────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails details) {
    final obj = _obj;
    if (obj == null) return;

    final positions = _handlePositions(obj);
    final hit = _hitTest(details.localPosition, positions);

    if (hit == _HandleType.none) {
      // Check if inside the object bounding rect (move).
      final canvasPoint = _toCanvas(details.localPosition);
      if (obj.containsPoint(canvasPoint)) {
        _activeHandle = _HandleType.none; // will be treated as move
        _dragStart = details.localPosition;
        _startLeft = obj.left;
        _startTop = obj.top;
      } else {
        _activeHandle = _HandleType.none;
      }
      return;
    }

    _activeHandle = hit;
    _dragStart = details.localPosition;
    _startLeft = obj.left;
    _startTop = obj.top;
    _startWidth = obj.width;
    _startHeight = obj.height;
    _startScaleX = obj.scaleX;
    _startScaleY = obj.scaleY;
    _startAngle = obj.angle;
    _startCenter = Offset(
      obj.left + obj.scaledWidth / 2,
      obj.top + obj.scaledHeight / 2,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final obj = _obj;
    if (obj == null) return;

    final delta = details.localPosition - _dragStart;
    final canvasDelta = delta / _ctrl.zoom;

    if (_activeHandle == _HandleType.none) {
      // Move
      obj.set(
        left: _startLeft + canvasDelta.dx,
        top: _startTop + canvasDelta.dy,
      );
      return;
    }

    if (_activeHandle == _HandleType.rotate) {
      _handleRotate(details.localPosition, obj);
      return;
    }

    _handleScale(details.localPosition, obj, canvasDelta);
  }

  void _onPanEnd(DragEndDetails details) {
    _activeHandle = _HandleType.none;
  }

  void _handleRotate(Offset screenPoint, FabricObject obj) {
    final centerScreen = _toScreen(_startCenter);
    final startVec = _dragStart - centerScreen;
    final currentVec = screenPoint - centerScreen;
    final startAngleRad = math.atan2(startVec.dy, startVec.dx);
    final currentAngleRad = math.atan2(currentVec.dy, currentVec.dx);
    final deltaAngleDeg =
        (currentAngleRad - startAngleRad) * 180 / math.pi;
    obj.set(angle: _startAngle + deltaAngleDeg);
  }

  void _handleScale(
      Offset screenPoint, FabricObject obj, Offset canvasDelta) {
    final rad = -_startAngle * math.pi / 180;
    final cos = math.cos(rad);
    final sin = math.sin(rad);

    // Rotate the canvas-space delta into the object's local space.
    final ldx = canvasDelta.dx * cos - canvasDelta.dy * sin;
    final ldy = canvasDelta.dx * sin + canvasDelta.dy * cos;

    double newLeft = _startLeft;
    double newTop = _startTop;
    double newScaleX = _startScaleX;
    double newScaleY = _startScaleY;

    final origW = _startWidth * _startScaleX;
    final origH = _startHeight * _startScaleY;

    switch (_activeHandle) {
      case _HandleType.bottomRight:
        newScaleX = math.max(_kMinDimension, origW + ldx) / _startWidth;
        newScaleY = math.max(_kMinDimension, origH + ldy) / _startHeight;
        if (widget.lockAspectRatio) {
          newScaleY = newScaleX * (_startScaleY / _startScaleX);
        }
        break;
      case _HandleType.bottomLeft:
        final newW = math.max(_kMinDimension, origW - ldx);
        newScaleX = newW / _startWidth;
        newScaleY = math.max(_kMinDimension, origH + ldy) / _startHeight;
        if (widget.lockAspectRatio) {
          newScaleY = newScaleX * (_startScaleY / _startScaleX);
        }
        newLeft = _startLeft + (origW - newW);
        break;
      case _HandleType.topRight:
        newScaleX = math.max(_kMinDimension, origW + ldx) / _startWidth;
        final newH = math.max(_kMinDimension, origH - ldy);
        newScaleY = newH / _startHeight;
        if (widget.lockAspectRatio) {
          newScaleX = newScaleY * (_startScaleX / _startScaleY);
        }
        newTop = _startTop + (origH - newH);
        break;
      case _HandleType.topLeft:
        final newW = math.max(_kMinDimension, origW - ldx);
        final newH = math.max(_kMinDimension, origH - ldy);
        newScaleX = newW / _startWidth;
        newScaleY = newH / _startHeight;
        if (widget.lockAspectRatio) {
          final s = math.min(newScaleX, newScaleY);
          newScaleX = s;
          newScaleY = s;
        }
        newLeft = _startLeft + (origW - newW);
        newTop = _startTop + (origH - newH);
        break;
      case _HandleType.middleRight:
        newScaleX = math.max(_kMinDimension, origW + ldx) / _startWidth;
        break;
      case _HandleType.middleLeft:
        final newW = math.max(_kMinDimension, origW - ldx);
        newScaleX = newW / _startWidth;
        newLeft = _startLeft + (origW - newW);
        break;
      case _HandleType.bottomCenter:
        newScaleY = math.max(_kMinDimension, origH + ldy) / _startHeight;
        break;
      case _HandleType.topCenter:
        final newH = math.max(_kMinDimension, origH - ldy);
        newScaleY = newH / _startHeight;
        newTop = _startTop + (origH - newH);
        break;
      default:
        break;
    }

    obj.set(
      left: newLeft,
      top: newTop,
      scaleX: newScaleX,
      scaleY: newScaleY,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        final obj = _obj;
        if (obj == null || !obj.visible) return const SizedBox.expand();

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            size: Size.infinite,
            painter: _SelectionPainter(
              object: obj,
              zoom: _ctrl.zoom,
              viewportTransform: _ctrl.viewportTransform,
              handleColor: widget.handleColor,
              borderColor: widget.borderColor,
              rotateHandleColor: widget.rotateHandleColor,
              handleStrokeColor: widget.handleStrokeColor,
              borderWidth: widget.borderWidth,
              rotateHandleDistance: widget.rotateHandleDistance,
              showScaleHandles: widget.showScaleHandles,
              showRotateHandle: widget.showRotateHandle,
            ),
          ),
        );
      },
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────

class _SelectionPainter extends CustomPainter {
  _SelectionPainter({
    required this.object,
    required this.zoom,
    required this.viewportTransform,
    required this.handleColor,
    required this.borderColor,
    required this.rotateHandleColor,
    required this.handleStrokeColor,
    required this.borderWidth,
    required this.rotateHandleDistance,
    required this.showScaleHandles,
    required this.showRotateHandle,
  });

  final FabricObject object;
  final double zoom;
  final Offset viewportTransform;
  final Color handleColor;
  final Color borderColor;
  final Color rotateHandleColor;
  final Color handleStrokeColor;
  final double borderWidth;
  final double rotateHandleDistance;
  final bool showScaleHandles;
  final bool showRotateHandle;

  Offset _toScreen(Offset canvas) => canvas * zoom + viewportTransform;

  @override
  void paint(Canvas canvas, Size size) {
    final obj = object;
    final cx = obj.left + obj.scaledWidth / 2;
    final cy = obj.top + obj.scaledHeight / 2;
    final hw = obj.scaledWidth / 2;
    final hh = obj.scaledHeight / 2;
    final angle = obj.angle;
    final rad = angle * math.pi / 180;

    // Helper: rotate offset around centre and convert to screen.
    Offset rot(double dx, double dy) {
      final rx = dx * math.cos(rad) - dy * math.sin(rad);
      final ry = dx * math.sin(rad) + dy * math.cos(rad);
      return _toScreen(Offset(cx + rx, cy + ry));
    }

    final tl = rot(-hw, -hh);
    final tr = rot(hw, -hh);
    final br = rot(hw, hh);
    final bl = rot(-hw, hh);

    // ── Border ──────────────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..isAntiAlias = true;

    final borderPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();
    canvas.drawPath(borderPath, borderPaint);

    if (!showScaleHandles && !showRotateHandle) return;

    // ── Handle positions ────────────────────────────────────────────────────
    final tc = rot(0, -hh);
    final mr = rot(hw, 0);
    final bc = rot(0, hh);
    final ml = rot(-hw, 0);

    // ── Scale handles ───────────────────────────────────────────────────────
    if (showScaleHandles) {
      final handlePositions = [tl, tc, tr, mr, br, bc, bl, ml];
      _drawHandles(canvas, handlePositions);
    }

    // ── Rotate handle ───────────────────────────────────────────────────────
    if (showRotateHandle) {
      // Line from top-centre to rotate knob
      final rotHandleCanvas = Offset(
        cx + (0 * math.cos(rad) - (-hh - rotateHandleDistance / zoom) * math.sin(rad)),
        cy + (0 * math.sin(rad) + (-hh - rotateHandleDistance / zoom) * math.cos(rad)),
      );
      final rotHandleScreen = _toScreen(rotHandleCanvas);

      final linePaint = Paint()
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke;
      canvas.drawLine(tc, rotHandleScreen, linePaint);

      _drawRotateHandle(canvas, rotHandleScreen);
    }
  }

  void _drawHandles(Canvas canvas, List<Offset> positions) {
    final fillPaint = Paint()
      ..color = handleColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = handleStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pos in positions) {
      final rect = Rect.fromCenter(
        center: pos,
        width: _kHandleSize,
        height: _kHandleSize,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
    }
  }

  void _drawRotateHandle(Canvas canvas, Offset center) {
    final fillPaint = Paint()
      ..color = rotateHandleColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = handleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, _kHandleSize / 2, fillPaint);
    canvas.drawCircle(center, _kHandleSize / 2, strokePaint);

    // Draw a small rotation arrow icon
    _drawRotateArrow(canvas, center, _kHandleSize / 2 - 2);
  }

  void _drawRotateArrow(Canvas canvas, Offset center, double radius) {
    final arrowPaint = Paint()
      ..color = handleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Draw a partial arc (270 degrees)
    const startAngle = -math.pi / 2;
    const sweepAngle = math.pi * 1.5;
    final arcRect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2,
    );
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arrowPaint);

    // Arrowhead at the end of the arc
    final endAngle = startAngle + sweepAngle;
    final arrowTip = center +
        Offset(math.cos(endAngle) * radius, math.sin(endAngle) * radius);
    final arrowDir = Offset(
      math.cos(endAngle + math.pi / 2),
      math.sin(endAngle + math.pi / 2),
    );
    final arrowPath = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(
        arrowTip.dx - arrowDir.dx * 3 - arrowDir.dy * 2,
        arrowTip.dy - arrowDir.dy * 3 + arrowDir.dx * 2,
      )
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(
        arrowTip.dx - arrowDir.dx * 3 + arrowDir.dy * 2,
        arrowTip.dy - arrowDir.dy * 3 - arrowDir.dx * 2,
      );
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.object != object ||
      old.zoom != zoom ||
      old.viewportTransform != viewportTransform;
}
