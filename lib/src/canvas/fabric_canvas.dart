import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'fabric_controller.dart';
import '../objects/fabric_object.dart';
import '../objects/fabric_rect.dart';
import '../objects/fabric_circle.dart';
import '../objects/fabric_ellipse.dart';
import '../objects/fabric_triangle.dart';
import '../objects/fabric_line.dart';
import '../objects/fabric_itext.dart';
import '../objects/fabric_textbox.dart';
import '../controls/selection_overlay.dart' as fabric;
import '../utils/fabric_math.dart';
import '../widgets/text_editing_overlay.dart';
import '../widgets/object_edit_menu.dart';
import '../brushes/base_brush.dart';
import '../utils/fabric_serializer.dart';

/// Low-level canvas widget. For a batteries-included experience with a built-in
/// toolbar, use [FabricBoard] instead.
class FabricCanvas extends StatefulWidget {
  const FabricCanvas({
    super.key,
    required this.controller,
    this.backgroundColor,
    this.onTapObject,
    this.onDoubleTap,
    this.onLongPressObject,
    this.enablePan = true,
    this.enableZoom = true,
    this.enableSelection = true,
    this.enableDrag = true,
    this.enableMarqueeSelection = true,
    this.enableKeyboardShortcuts = true,
    this.enableDoubleTapEdit = true,
  });

  final FabricController controller;
  final Color? backgroundColor;

  /// Called when the user taps an object in [FabricInteractionMode.select].
  final void Function(FabricObject object)? onTapObject;

  /// Called on double-tap with the canvas-space position.
  final void Function(Offset canvasPosition)? onDoubleTap;

  /// Overrides the built-in long-press edit menu.
  final void Function(FabricObject object)? onLongPressObject;

  final bool enablePan;
  final bool enableZoom;

  /// Whether tapping selects objects (default true).
  final bool enableSelection;

  /// Whether selected objects can be dragged (default true).
  final bool enableDrag;

  /// Whether rubber-band / marquee selection is enabled (default true).
  final bool enableMarqueeSelection;

  /// Whether Delete/Ctrl+Z/etc keyboard shortcuts are handled (default true).
  final bool enableKeyboardShortcuts;

  /// Whether double-tapping a text object starts inline editing (default true).
  final bool enableDoubleTapEdit;

  @override
  State<FabricCanvas> createState() => _FabricCanvasState();
}

class _FabricCanvasState extends State<FabricCanvas> {
  // ── Drag state ───────────────────────────────────────────────────────────
  Offset? _lastFocalPoint;
  bool _isDraggingObject = false;
  FabricObject? _draggedObject;
  MouseCursor _cursor = SystemMouseCursors.basic;

  // ── Marquee selection ────────────────────────────────────────────────────
  bool _isSelecting = false;
  Offset? _selectionStart;
  Rect? _selectionRect;

  // ── Free drawing ─────────────────────────────────────────────────────────
  bool _isDrawing = false;

  // ── Tap & draw point tracking ────────────────────────────────────────────
  Offset _lastTapLocalPosition = Offset.zero;
  Offset _lastDrawCanvasPoint = Offset.zero;

  // ── Shape drawing ─────────────────────────────────────────────────────────
  Offset? _shapeStart; // canvas coords
  Offset? _shapeEnd;   // canvas coords

  // ── Focus for keyboard shortcuts ─────────────────────────────────────────
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  FabricController get _ctrl => widget.controller;

  Offset _toCanvas(Offset screen) => FabricMath.screenToCanvas(
        screen,
        zoom: _ctrl.zoom,
        viewportOffset: _ctrl.viewportTransform,
      );

  bool get _isShapeMode {
    switch (_ctrl.interactionMode) {
      case FabricInteractionMode.drawRect:
      case FabricInteractionMode.drawCircle:
      case FabricInteractionMode.drawEllipse:
      case FabricInteractionMode.drawTriangle:
      case FabricInteractionMode.drawLine:
        return true;
      default:
        return false;
    }
  }

  bool get _isAddTextMode =>
      _ctrl.interactionMode == FabricInteractionMode.addText ||
      _ctrl.interactionMode == FabricInteractionMode.addTextBox;

  // ── Keyboard ──────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enableKeyboardShortcuts) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _ctrl.removeActiveObjects();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyA) {
      _ctrl.selectAll();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      _ctrl.copyActiveObjects();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyX) {
      _ctrl.cutActiveObjects();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyV) {
      _ctrl.pasteObjects();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        if (_ctrl.canRedo) _ctrl.redo();
      } else {
        if (_ctrl.canUndo) _ctrl.undo();
      }
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      if (_ctrl.canRedo) _ctrl.redo();
      return KeyEventResult.handled;
    }
    const nudge = 1.0;
    final active = _ctrl.activeObjects;
    if (active.isNotEmpty) {
      double dx = 0, dy = 0;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) dx = -nudge;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) dx = nudge;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) dy = -nudge;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) dy = nudge;
      if (dx != 0 || dy != 0) {
        for (final obj in active) {
          if (!obj.lockMovementX && !obj.lockMovementY) {
            obj.set(left: obj.left + dx, top: obj.top + dy);
          }
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ── Gestures ──────────────────────────────────────────────────────────────

  void _onTapDown(TapDownDetails details) {
    _lastTapLocalPosition = details.localPosition;

    // Free drawing
    if (_ctrl.isDrawingMode) {
      final canvasPoint = _toCanvas(details.localPosition);
      _lastDrawCanvasPoint = canvasPoint;
      _ctrl.freeDrawingBrush?.onPointerDown(canvasPoint, _ctrl);
      _isDrawing = true;
      return;
    }

    // Tap to add text / textbox
    if (_isAddTextMode) {
      final cp = _toCanvas(details.localPosition);
      final isBox = _ctrl.interactionMode == FabricInteractionMode.addTextBox;
      final FabricObject obj = isBox
          ? FabricTextBox(
              'Text',
              left: cp.dx,
              top: cp.dy,
              fontSize: _ctrl.activeFontSize,
              fill: _ctrl.activeFillColor,
            )
          : FabricIText(
              'Text',
              left: cp.dx,
              top: cp.dy,
              fontSize: _ctrl.activeFontSize,
              fill: _ctrl.activeFillColor,
            );
      _ctrl.add(obj);
      if (widget.enableSelection) _ctrl.setActiveObject(obj);
      if (!isBox && obj is FabricIText) _ctrl.startEditingText(obj);
      return;
    }

    // Shape drawing — record start on tap down too (for taps with no drag)
    if (_isShapeMode) {
      _shapeStart = _toCanvas(details.localPosition);
      return;
    }

    // Select
    if (!widget.enableSelection) return;
    final canvasPoint = _toCanvas(details.localPosition);
    final tapped = _ctrl.findObjectAtPoint(canvasPoint);
    if (tapped != null) {
      _ctrl.setActiveObject(tapped);
      widget.onTapObject?.call(tapped);
    } else {
      _ctrl.discardActiveObject();
    }
  }

  void _onDoubleTap() {
    if (_ctrl.isDrawingMode || _isShapeMode || _isAddTextMode) return;
    final canvasPos = _toCanvas(_lastTapLocalPosition);
    final active = _ctrl.activeObject;
    if (widget.enableDoubleTapEdit && active is FabricIText) {
      _ctrl.startEditingText(active);
    }
    widget.onDoubleTap?.call(canvasPos);
  }

  void _onLongPress() {
    if (_ctrl.isDrawingMode || _isShapeMode || _isAddTextMode) return;
    final canvasPoint = _toCanvas(_lastTapLocalPosition);
    final obj = _ctrl.findObjectAtPoint(canvasPoint);
    if (obj == null) return;
    if (widget.onLongPressObject != null) {
      widget.onLongPressObject!(obj);
    } else {
      _showEditMenu(obj);
    }
  }

  void _showEditMenu(FabricObject obj) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => ObjectEditMenu(
        controller: _ctrl,
        object: obj,
        onDelete: () { _ctrl.remove(obj); Navigator.pop(context); },
        onDuplicate: () {
          final clone = FabricSerializer.clone(obj, nudge: const Offset(10, 10));
          if (clone != null) _ctrl.add(clone);
          Navigator.pop(context);
        },
        onBringToFront: () { _ctrl.bringToFront(obj); Navigator.pop(context); },
        onSendToBack: () { _ctrl.sendToBack(obj); Navigator.pop(context); },
        onBringForward: () { _ctrl.bringForward(obj); Navigator.pop(context); },
        onSendBackward: () { _ctrl.sendBackward(obj); Navigator.pop(context); },
        onLockMovement: () {
          obj.lockMovementX = true;
          obj.lockMovementY = true;
          Navigator.pop(context);
        },
        onUnlockMovement: () {
          obj.lockMovementX = false;
          obj.lockMovementY = false;
          Navigator.pop(context);
        },
        onToggleVisible: () {
          obj.set(visible: !obj.visible);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;

    if (_ctrl.isDrawingMode) return;
    if (_isAddTextMode) return;

    if (_isShapeMode) {
      _shapeStart = _toCanvas(details.localFocalPoint);
      return;
    }

    if (!widget.enableSelection) return;
    final canvasPoint = _toCanvas(details.focalPoint);
    _draggedObject = _ctrl.findObjectAtPoint(canvasPoint);
    _isDraggingObject =
        widget.enableDrag && _draggedObject != null && _draggedObject!.selectable;

    if (_draggedObject == null && widget.enableMarqueeSelection && _ctrl.selection) {
      _isSelecting = true;
      _selectionStart = details.localFocalPoint;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_lastFocalPoint == null) return;

    // 2-finger pinch/pan — always works (Figma-like)
    if (details.pointerCount >= 2 && widget.enableZoom) {
      _isDrawing = false;
      final canvasFocal = _toCanvas(details.focalPoint);
      _ctrl.zoomToPoint(canvasFocal, _ctrl.zoom * details.scale);
      _ctrl.panBy(details.focalPoint - _lastFocalPoint!);
      _lastFocalPoint = details.focalPoint;
      return;
    }

    if (_ctrl.isDrawingMode) {
      if (_isDrawing) {
        final canvasPoint = _toCanvas(details.localFocalPoint);
        _lastDrawCanvasPoint = canvasPoint;
        _ctrl.freeDrawingBrush?.onPointerMove(canvasPoint, _ctrl);
        _ctrl.requestRepaint();
      }
      _lastFocalPoint = details.focalPoint;
      return;
    }

    if (_isShapeMode) {
      if (_shapeStart != null && details.pointerCount == 1) {
        setState(() => _shapeEnd = _toCanvas(details.localFocalPoint));
      }
      _lastFocalPoint = details.focalPoint;
      return;
    }

    // Marquee rubber-band
    if (_isSelecting && _selectionStart != null) {
      final cur = details.localFocalPoint;
      final l = _selectionStart!.dx < cur.dx ? _selectionStart!.dx : cur.dx;
      final t = _selectionStart!.dy < cur.dy ? _selectionStart!.dy : cur.dy;
      setState(() {
        _selectionRect = Rect.fromLTWH(
          l, t,
          (_selectionStart!.dx - cur.dx).abs(),
          (_selectionStart!.dy - cur.dy).abs(),
        );
      });
      _lastFocalPoint = details.focalPoint;
      return;
    }

    if (details.pointerCount == 1) {
      final delta = details.focalPoint - _lastFocalPoint!;
      if (_isDraggingObject && _draggedObject != null) {
        final obj = _draggedObject!;
        final cd = delta / _ctrl.zoom;
        if (!obj.lockMovementX && !obj.lockMovementY) {
          obj.set(left: obj.left + cd.dx, top: obj.top + cd.dy);
        } else if (!obj.lockMovementX) {
          obj.set(left: obj.left + cd.dx);
        } else if (!obj.lockMovementY) {
          obj.set(top: obj.top + cd.dy);
        }
      } else if (widget.enablePan) {
        _ctrl.panBy(delta);
      }
    }

    _lastFocalPoint = details.focalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_ctrl.isDrawingMode) {
      if (_isDrawing) {
        _ctrl.freeDrawingBrush?.onPointerUp(_lastDrawCanvasPoint, _ctrl);
        _isDrawing = false;
        _ctrl.requestRepaint();
      }
      return;
    }

    if (_isShapeMode) {
      if (_shapeStart != null && _shapeEnd != null) {
        _finalizeShape(_shapeStart!, _shapeEnd!);
      }
      setState(() {
        _shapeStart = null;
        _shapeEnd = null;
      });
      _lastFocalPoint = null;
      return;
    }

    if (_isSelecting && _selectionRect != null) {
      final canvasTopLeft = _toCanvas(_selectionRect!.topLeft);
      final canvasBotRight = _toCanvas(_selectionRect!.bottomRight);
      final canvasRect = Rect.fromPoints(canvasTopLeft, canvasBotRight);
      final selected = _ctrl.objects
          .where((obj) =>
              obj.selectable && obj.visible && obj.boundingRect.overlaps(canvasRect))
          .toList();
      if (selected.isNotEmpty) {
        _ctrl.setActiveObjects(selected);
      } else {
        _ctrl.discardActiveObject();
      }
    }

    _lastFocalPoint = null;
    _isDraggingObject = false;
    _draggedObject = null;
    _isSelecting = false;
    _selectionRect = null;
    setState(() {});
  }

  void _finalizeShape(Offset startC, Offset endC) {
    final rect = Rect.fromPoints(startC, endC);
    if (rect.width < 3 && rect.height < 3) return;

    final fill = _ctrl.activeFillColor;
    final stroke = _ctrl.activeStrokeColor;
    final sw = _ctrl.activeStrokeWidth;
    final mode = _ctrl.interactionMode;

    FabricObject? obj;
    switch (mode) {
      case FabricInteractionMode.drawRect:
        obj = FabricRect(
          left: rect.left, top: rect.top,
          width: rect.width, height: rect.height,
          fill: fill, stroke: stroke, strokeWidth: sw,
        );
      case FabricInteractionMode.drawCircle:
        final r = rect.shortestSide / 2;
        obj = FabricCircle(
          left: rect.center.dx - r, top: rect.center.dy - r,
          radius: r, fill: fill, stroke: stroke, strokeWidth: sw,
        );
      case FabricInteractionMode.drawEllipse:
        obj = FabricEllipse(
          left: rect.left, top: rect.top,
          rx: rect.width / 2, ry: rect.height / 2,
          fill: fill, stroke: stroke, strokeWidth: sw,
        );
      case FabricInteractionMode.drawTriangle:
        obj = FabricTriangle(
          left: rect.left, top: rect.top,
          width: rect.width, height: rect.height,
          fill: fill, stroke: stroke, strokeWidth: sw,
        );
      case FabricInteractionMode.drawLine:
        final lineColor = stroke == Colors.transparent ? fill : stroke;
        obj = FabricLine(
          x1: startC.dx, y1: startC.dy, x2: endC.dx, y2: endC.dy,
          stroke: lineColor, strokeWidth: sw > 0 ? sw : 2,
        );
      default:
        return;
    }

    _ctrl.add(obj);
    if (widget.enableSelection) _ctrl.setActiveObject(obj);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      autofocus: true,
      child: MouseRegion(
        cursor: _cursor,
        onHover: (event) {
          final canvasPoint = _toCanvas(event.localPosition);
          final obj = _ctrl.findObjectAtPoint(canvasPoint);
          final newCursor = (_isShapeMode || _ctrl.isDrawingMode || _isAddTextMode)
              ? SystemMouseCursors.precise
              : (obj != null && obj.selectable
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic);
          if (newCursor != _cursor) setState(() => _cursor = newCursor);
        },
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && widget.enableZoom) {
              final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
              _ctrl.zoomToPoint(_toCanvas(event.localPosition), _ctrl.zoom * zoomFactor);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            onDoubleTap: _onDoubleTap,
            onLongPress: _onLongPress,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: Stack(
              children: [
                ListenableBuilder(
                  listenable: _ctrl,
                  builder: (context, _) => CustomPaint(
                    painter: _CanvasPainter(
                      objects: _ctrl.objects,
                      backgroundColor: widget.backgroundColor ?? _ctrl.backgroundColor,
                      zoom: _ctrl.zoom,
                      viewportOffset: _ctrl.viewportTransform,
                      backgroundImage: _ctrl.backgroundImage,
                      drawingBrush: _ctrl.isDrawingMode ? _ctrl.freeDrawingBrush : null,
                      shapePreview: (_isShapeMode &&
                              _shapeStart != null &&
                              _shapeEnd != null)
                          ? _ShapePreview(
                              start: _shapeStart!,
                              end: _shapeEnd!,
                              mode: _ctrl.interactionMode,
                            )
                          : null,
                    ),
                    size: Size.infinite,
                  ),
                ),
                if (!_ctrl.isDrawingMode && !_isShapeMode && !_isAddTextMode)
                  fabric.SelectionOverlay(controller: _ctrl),
                if (_isSelecting && _selectionRect != null)
                  Positioned.fromRect(
                    rect: _selectionRect!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                    ),
                  ),
                if (_ctrl.editingTextObject != null)
                  TextEditingOverlay(
                    controller: _ctrl,
                    textObject: _ctrl.editingTextObject!,
                    onDismiss: () => _ctrl.editingTextObject = null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shape preview ──────────────────────────────────────────────────────────

class _ShapePreview {
  const _ShapePreview({required this.start, required this.end, required this.mode});
  final Offset start; // canvas coords
  final Offset end;   // canvas coords
  final FabricInteractionMode mode;
}

// ── Painter ────────────────────────────────────────────────────────────────

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.objects,
    required this.backgroundColor,
    required this.zoom,
    required this.viewportOffset,
    this.backgroundImage,
    this.drawingBrush,
    this.shapePreview,
  });

  final List<FabricObject> objects;
  final Color backgroundColor;
  final double zoom;
  final Offset viewportOffset;
  final ui.Image? backgroundImage;
  final BaseBrush? drawingBrush;
  final _ShapePreview? shapePreview;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    if (backgroundImage != null) {
      canvas.drawImageRect(
        backgroundImage!,
        Rect.fromLTWH(0, 0, backgroundImage!.width.toDouble(),
            backgroundImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint(),
      );
    }
    canvas.save();
    canvas.translate(viewportOffset.dx, viewportOffset.dy);
    canvas.scale(zoom);
    for (final obj in objects) {
      obj.paint(canvas, size);
    }
    drawingBrush?.render(canvas, size);
    if (shapePreview != null) _paintShapePreview(canvas, shapePreview!);
    canvas.restore();
  }

  void _paintShapePreview(Canvas canvas, _ShapePreview p) {
    final fill = Paint()
      ..color = Colors.blue.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.blue.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromPoints(p.start, p.end);

    switch (p.mode) {
      case FabricInteractionMode.drawRect:
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, border);
      case FabricInteractionMode.drawCircle:
        final r = rect.shortestSide / 2;
        canvas.drawCircle(rect.center, r, fill);
        canvas.drawCircle(rect.center, r, border);
      case FabricInteractionMode.drawEllipse:
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, border);
      case FabricInteractionMode.drawTriangle:
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, border);
      case FabricInteractionMode.drawLine:
        canvas.drawLine(p.start, p.end, border..strokeWidth = 2);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.objects != objects ||
      old.backgroundColor != backgroundColor ||
      old.zoom != zoom ||
      old.viewportOffset != viewportOffset ||
      old.backgroundImage != backgroundImage ||
      old.drawingBrush != drawingBrush ||
      old.shapePreview != shapePreview;
}
