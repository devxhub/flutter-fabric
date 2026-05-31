import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../objects/fabric_object.dart';
import '../objects/fabric_group.dart';
import '../objects/fabric_itext.dart';
import '../brushes/base_brush.dart';
import '../utils/fabric_object_factory.dart';
import '../utils/fabric_serializer.dart';

typedef ImageResolver = Future<ui.Image> Function(String source);

/// Defines how the user interacts with [FabricCanvas].
///
/// Set via [FabricController.interactionMode]. [FabricBoard] manages this
/// automatically through its built-in toolbar.
enum FabricInteractionMode {
  select,        // tap/drag to select & move objects
  pencil,        // free-hand pencil drawing
  eraser,        // free-hand eraser
  spray,         // spray-paint brush
  drawRect,      // drag to draw a rectangle
  drawCircle,    // drag to draw a circle
  drawEllipse,   // drag to draw an ellipse
  drawTriangle,  // drag to draw a triangle
  drawLine,      // drag to draw a line
  addText,       // tap to place an editable text label
  addTextBox,    // tap to place a wrapped text box
}

class FabricSelectionEvent {
  const FabricSelectionEvent({required this.selected, this.deselected});
  final List<FabricObject> selected;
  final FabricObject? deselected;
}

typedef FabricObjectCallback = void Function(FabricObject object);
typedef FabricSelectionCallback = void Function(FabricSelectionEvent event);
typedef FabricModifiedCallback = void Function(FabricObject object);

class FabricController with ChangeNotifier {
  FabricController({
    Color backgroundColor = Colors.white,
    bool selection = true,
    bool isDrawingMode = false,
    BaseBrush? freeDrawingBrush,
    this.onResolveImage,
  })  : _backgroundColor = backgroundColor,
        _selection = selection,
        _isDrawingMode = isDrawingMode,
        _freeDrawingBrush = freeDrawingBrush;

  // ── Objects ───────────────────────────────────────────────────────────────

  final List<FabricObject> _objects = [];
  List<FabricObject> get objects => List.unmodifiable(_objects);

  // ── Selection ─────────────────────────────────────────────────────────────

  final List<FabricObject> _activeObjects = [];
  List<FabricObject> get activeObjects => List.unmodifiable(_activeObjects);
  FabricObject? get activeObject =>
      _activeObjects.length == 1 ? _activeObjects.first : null;

  bool _selection;
  bool get selection => _selection;
  set selection(bool v) {
    _selection = v;
    notifyListeners();
  }

  // ── Drawing mode ──────────────────────────────────────────────────────────

  bool _isDrawingMode;
  bool get isDrawingMode => _isDrawingMode;
  set isDrawingMode(bool v) {
    _isDrawingMode = v;
    if (v) discardActiveObject();
    notifyListeners();
  }

  BaseBrush? _freeDrawingBrush;
  BaseBrush? get freeDrawingBrush => _freeDrawingBrush;
  set freeDrawingBrush(BaseBrush? v) {
    _freeDrawingBrush = v;
    notifyListeners();
  }

  // ── Interaction mode ──────────────────────────────────────────────────────

  FabricInteractionMode _interactionMode = FabricInteractionMode.select;

  FabricInteractionMode get interactionMode => _interactionMode;

  /// Switches the active interaction mode and keeps [isDrawingMode] in sync.
  set interactionMode(FabricInteractionMode mode) {
    _interactionMode = mode;
    _isDrawingMode = mode == FabricInteractionMode.pencil ||
        mode == FabricInteractionMode.eraser ||
        mode == FabricInteractionMode.spray;
    if (_isDrawingMode) _activeObjects.clear();
    notifyListeners();
  }

  // ── Object creation defaults ──────────────────────────────────────────────
  // These are read by FabricCanvas when creating shapes via drag-to-draw.

  Color activeFillColor = Colors.blue;
  Color activeStrokeColor = Colors.transparent;
  double activeStrokeWidth = 1.0;
  double activeFontSize = 24.0;

  // ── Appearance ────────────────────────────────────────────────────────────

  Color _backgroundColor;
  Color get backgroundColor => _backgroundColor;
  set backgroundColor(Color v) {
    _backgroundColor = v;
    notifyListeners();
  }

  // ── Viewport ──────────────────────────────────────────────────────────────

  double _zoom = 1.0;
  double get zoom => _zoom;
  Offset _viewportTransform = Offset.zero;
  Offset get viewportTransform => _viewportTransform;

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  static const int _maxHistory = 50;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _pushHistory() {
    _undoStack.add(_serializeObjects());
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  // ── Clipboard ─────────────────────────────────────────────────────────────

  final List<Map<String, dynamic>> _clipboard = [];

  void copyActiveObjects() {
    _clipboard
      ..clear()
      ..addAll(_activeObjects.map((o) => o.toJson()));
  }

  void pasteObjects() {
    if (_clipboard.isEmpty) return;
    _pushHistory();
    final pasted = <FabricObject>[];
    for (final json in _clipboard) {
      final map = Map<String, dynamic>.from(json)
        ..remove('id')
        ..['left'] = ((json['left'] as num?)?.toDouble() ?? 0) + 10
        ..['top'] = ((json['top'] as num?)?.toDouble() ?? 0) + 10;
      final obj = FabricObjectFactory.deserialize(map);
      if (obj != null) {
        _objects.add(obj);
        _attachWithClosure(obj);
        onObjectAdded?.call(obj);
        pasted.add(obj);
      }
    }
    if (pasted.isNotEmpty) setActiveObjects(pasted);
    notifyListeners();
  }

  void cutActiveObjects() {
    copyActiveObjects();
    removeActiveObjects();
  }

  // ── Callbacks ─────────────────────────────────────────────────────────────

  FabricObjectCallback? onObjectAdded;
  FabricObjectCallback? onObjectRemoved;
  FabricModifiedCallback? onObjectModified;
  FabricSelectionCallback? onSelectionCreated;
  FabricSelectionCallback? onSelectionCleared;
  VoidCallback? onRender;
  final ImageResolver? onResolveImage;

  // ── Text editing ──────────────────────────────────────────────────────────

  FabricIText? _editingTextObject;
  FabricIText? get editingTextObject => _editingTextObject;
  set editingTextObject(FabricIText? v) {
    _editingTextObject = v;
    notifyListeners();
  }

  void startEditingText(FabricIText text) {
    editingTextObject = text;
  }

  // ── Background image ──────────────────────────────────────────────────────

  ui.Image? _backgroundImage;
  ui.Image? get backgroundImage => _backgroundImage;
  set backgroundImage(ui.Image? v) {
    _backgroundImage = v;
    notifyListeners();
  }

  // ── Object listener management ────────────────────────────────────────────

  final Map<FabricObject, VoidCallback> _listenerClosures = {};

  void _attachWithClosure(FabricObject obj) {
    final closure = () => _onObjectChanged(obj);
    _listenerClosures[obj] = closure;
    obj.addListener(closure);
  }

  void _detachWithClosure(FabricObject obj) {
    final closure = _listenerClosures.remove(obj);
    if (closure != null) obj.removeListener(closure);
  }

  void _onObjectChanged(FabricObject changedObject) {
    onObjectModified?.call(changedObject);
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  void add(FabricObject obj) {
    _pushHistory();
    _objects.add(obj);
    _attachWithClosure(obj);
    onObjectAdded?.call(obj);
    notifyListeners();
  }

  void addAll(List<FabricObject> objects) {
    _pushHistory();
    for (final obj in objects) {
      _objects.add(obj);
      _attachWithClosure(obj);
      onObjectAdded?.call(obj);
    }
    notifyListeners();
  }

  void remove(FabricObject obj) {
    _pushHistory();
    _objects.remove(obj);
    _activeObjects.remove(obj);
    _detachWithClosure(obj);
    onObjectRemoved?.call(obj);
    notifyListeners();
  }

  void clear() {
    _pushHistory();
    for (final obj in _objects) _detachWithClosure(obj);
    _objects.clear();
    _activeObjects.clear();
    notifyListeners();
  }

  void removeActiveObjects() {
    if (_activeObjects.isEmpty) return;
    final toRemove = List<FabricObject>.from(_activeObjects);
    _pushHistory();
    for (final obj in toRemove) {
      _objects.remove(obj);
      _detachWithClosure(obj);
      onObjectRemoved?.call(obj);
    }
    _activeObjects.clear();
    notifyListeners();
  }

  // ── Z-order ───────────────────────────────────────────────────────────────

  void bringToFront(FabricObject obj) {
    if (_objects.remove(obj)) {
      _objects.add(obj);
      notifyListeners();
    }
  }

  void sendToBack(FabricObject obj) {
    if (_objects.remove(obj)) {
      _objects.insert(0, obj);
      notifyListeners();
    }
  }

  void bringForward(FabricObject obj) {
    final i = _objects.indexOf(obj);
    if (i >= 0 && i < _objects.length - 1) {
      _objects.removeAt(i);
      _objects.insert(i + 1, obj);
      notifyListeners();
    }
  }

  void sendBackward(FabricObject obj) {
    final i = _objects.indexOf(obj);
    if (i > 0) {
      _objects.removeAt(i);
      _objects.insert(i - 1, obj);
      notifyListeners();
    }
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  void setActiveObject(FabricObject obj) {
    if (!obj.selectable) return;
    final prev = _activeObjects.isNotEmpty ? _activeObjects.first : null;
    _activeObjects
      ..clear()
      ..add(obj);
    onSelectionCreated
        ?.call(FabricSelectionEvent(selected: [obj], deselected: prev));
    notifyListeners();
  }

  void setActiveObjects(List<FabricObject> objects) {
    _activeObjects.clear();
    _activeObjects.addAll(objects.where((o) => o.selectable));
    onSelectionCreated?.call(
        FabricSelectionEvent(selected: List.unmodifiable(_activeObjects)));
    notifyListeners();
  }

  void addToActiveObjects(FabricObject obj) {
    if (!obj.selectable || _activeObjects.contains(obj)) return;
    _activeObjects.add(obj);
    onSelectionCreated?.call(
        FabricSelectionEvent(selected: List.unmodifiable(_activeObjects)));
    notifyListeners();
  }

  void discardActiveObject() {
    if (_activeObjects.isEmpty) return;
    final prev = List<FabricObject>.from(_activeObjects);
    _activeObjects.clear();
    onSelectionCleared?.call(FabricSelectionEvent(
        selected: const [], deselected: prev.isNotEmpty ? prev.first : null));
    notifyListeners();
  }

  void selectAll() {
    final selectable = _objects.where((o) => o.selectable && o.visible).toList();
    if (selectable.isEmpty) return;
    setActiveObjects(selectable);
  }

  FabricObject? findObjectAtPoint(Offset point) {
    for (final obj in _objects.reversed) {
      if (obj.selectable && obj.visible && obj.containsPoint(point)) return obj;
    }
    return null;
  }

  // ── Group ─────────────────────────────────────────────────────────────────

  FabricGroup? groupActiveObjects() {
    if (_activeObjects.length < 2) return null;
    final objs = List<FabricObject>.from(_activeObjects);
    _pushHistory();
    for (final o in objs) {
      _objects.remove(o);
      _detachWithClosure(o);
    }
    final group = FabricGroup(objects: objs);
    _objects.add(group);
    _attachWithClosure(group);
    _activeObjects
      ..clear()
      ..add(group);
    notifyListeners();
    return group;
  }

  List<FabricObject> ungroup(FabricGroup group) {
    _pushHistory();
    _objects.remove(group);
    _activeObjects.remove(group);
    _detachWithClosure(group);
    final children = group.objects.toList();
    for (final child in children) {
      _objects.add(child);
      _attachWithClosure(child);
    }
    _activeObjects.addAll(children);
    notifyListeners();
    return children;
  }

  // ── Alignment ─────────────────────────────────────────────────────────────

  void alignLeft() {
    if (_activeObjects.isEmpty) return;
    final l = _activeObjects.map((o) => o.left).reduce((a, b) => a < b ? a : b);
    for (final obj in _activeObjects) obj.set(left: l);
  }

  void alignRight() {
    if (_activeObjects.isEmpty) return;
    final r = _activeObjects
        .map((o) => o.left + o.scaledWidth)
        .reduce((a, b) => a > b ? a : b);
    for (final obj in _activeObjects) obj.set(left: r - obj.scaledWidth);
  }

  void alignTop() {
    if (_activeObjects.isEmpty) return;
    final t = _activeObjects.map((o) => o.top).reduce((a, b) => a < b ? a : b);
    for (final obj in _activeObjects) obj.set(top: t);
  }

  void alignBottom() {
    if (_activeObjects.isEmpty) return;
    final b = _activeObjects
        .map((o) => o.top + o.scaledHeight)
        .reduce((a, b) => a > b ? a : b);
    for (final obj in _activeObjects) obj.set(top: b - obj.scaledHeight);
  }

  void alignCenterH() {
    if (_activeObjects.isEmpty) return;
    final cx = _activeObjects
            .map((o) => o.left + o.scaledWidth / 2)
            .reduce((a, b) => a + b) /
        _activeObjects.length;
    for (final obj in _activeObjects)
      obj.set(left: cx - obj.scaledWidth / 2);
  }

  void alignCenterV() {
    if (_activeObjects.isEmpty) return;
    final cy = _activeObjects
            .map((o) => o.top + o.scaledHeight / 2)
            .reduce((a, b) => a + b) /
        _activeObjects.length;
    for (final obj in _activeObjects)
      obj.set(top: cy - obj.scaledHeight / 2);
  }

  void distributeHorizontally() {
    if (_activeObjects.length < 3) return;
    final sorted = List<FabricObject>.from(_activeObjects)
      ..sort((a, b) => a.left.compareTo(b.left));
    final totalWidth =
        sorted.last.left + sorted.last.scaledWidth - sorted.first.left;
    final gap = totalWidth / (_activeObjects.length - 1);
    double x = sorted.first.left;
    for (final obj in sorted) {
      obj.set(left: x);
      x += gap;
    }
  }

  void distributeVertically() {
    if (_activeObjects.length < 3) return;
    final sorted = List<FabricObject>.from(_activeObjects)
      ..sort((a, b) => a.top.compareTo(b.top));
    final totalHeight =
        sorted.last.top + sorted.last.scaledHeight - sorted.first.top;
    final gap = totalHeight / (_activeObjects.length - 1);
    double y = sorted.first.top;
    for (final obj in sorted) {
      obj.set(top: y);
      y += gap;
    }
  }

  // ── Flip ──────────────────────────────────────────────────────────────────

  void flipActiveObjectsX() {
    for (final obj in _activeObjects) obj.set(flipX: !obj.flipX);
  }

  void flipActiveObjectsY() {
    for (final obj in _activeObjects) obj.set(flipY: !obj.flipY);
  }

  // ── Viewport ──────────────────────────────────────────────────────────────

  void zoomTo(double zoom) {
    _zoom = zoom.clamp(0.1, 20.0);
    notifyListeners();
  }

  void zoomToPoint(Offset point, double zoom) {
    final newZoom = zoom.clamp(0.1, 20.0);
    final delta = point - _viewportTransform;
    _viewportTransform = point - delta * (newZoom / _zoom);
    _zoom = newZoom;
    notifyListeners();
  }

  void panBy(Offset delta) {
    _viewportTransform += delta;
    notifyListeners();
  }

  void resetViewport() {
    _zoom = 1.0;
    _viewportTransform = Offset.zero;
    notifyListeners();
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_serializeObjects());
    _loadSnapshot(_undoStack.removeLast());
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_serializeObjects());
    _loadSnapshot(_redoStack.removeLast());
  }

  // ── JSON ──────────────────────────────────────────────────────────────────

  String _serializeObjects() => jsonEncode({
        'objects': _objects.map((o) => o.toJson()).toList(),
        'background': _backgroundColor.toARGB32(),
      });

  void _loadSnapshot(String snapshot) {
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    for (final obj in _objects) _detachWithClosure(obj);
    _objects.clear();
    _activeObjects.clear();
    for (final raw in (data['objects'] as List<dynamic>)) {
      final obj =
          FabricObjectFactory.deserialize(raw as Map<String, dynamic>);
      if (obj != null) {
        _objects.add(obj);
        _attachWithClosure(obj);
      }
    }
    if (data['background'] != null) {
      _backgroundColor = Color(data['background'] as int);
    }
    notifyListeners();
  }

  String toJson() => _serializeObjects();

  void loadFromJson(String json) {
    _pushHistory();
    _loadSnapshot(json);
  }

  // ── PNG export ────────────────────────────────────────────────────────────

  Future<ui.Image> toImage(Size logicalSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        Offset.zero & logicalSize, Paint()..color = backgroundColor);
    if (_backgroundImage != null) {
      canvas.drawImageRect(
        _backgroundImage!,
        Rect.fromLTWH(0, 0, _backgroundImage!.width.toDouble(),
            _backgroundImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, logicalSize.width, logicalSize.height),
        Paint(),
      );
    }
    for (final obj in _objects) obj.paint(canvas, logicalSize);
    final picture = recorder.endRecording();
    return picture.toImage(
        logicalSize.width.toInt(), logicalSize.height.toInt());
  }

  /// Exports the canvas to PNG bytes at [pixelRatio] resolution.
  ///
  /// [size] defaults to a tight bounding box around all objects (min 100×100).
  /// The returned bytes can be saved to disk, shared, or displayed with
  /// [Image.memory].
  Future<Uint8List?> exportPng({
    Size? size,
    double pixelRatio = 2.0,
  }) async {
    final renderSize = size ?? _computeContentSize();
    final physW = (renderSize.width * pixelRatio).round();
    final physH = (renderSize.height * pixelRatio).round();
    if (physW <= 0 || physH <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder,
        Rect.fromLTWH(
            0, 0, renderSize.width * pixelRatio, renderSize.height * pixelRatio));
    canvas.scale(pixelRatio);

    canvas.drawRect(Offset.zero & renderSize, Paint()..color = backgroundColor);
    if (_backgroundImage != null) {
      canvas.drawImageRect(
        _backgroundImage!,
        Rect.fromLTWH(0, 0, _backgroundImage!.width.toDouble(),
            _backgroundImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, renderSize.width, renderSize.height),
        Paint(),
      );
    }
    for (final obj in _objects) {
      obj.paint(canvas, renderSize);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(physW, physH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  Size _computeContentSize() {
    if (_objects.isEmpty) return const Size(800, 600);
    double maxX = 0, maxY = 0;
    for (final obj in _objects) {
      final r = obj.aabb;
      if (r.right > maxX) maxX = r.right;
      if (r.bottom > maxY) maxY = r.bottom;
    }
    return Size(
      (maxX + 40).clamp(100, double.infinity),
      (maxY + 40).clamp(100, double.infinity),
    );
  }

  /// Triggers a canvas repaint without a state change — used by [FabricCanvas]
  /// during free-drawing to keep strokes visible in real time.
  void requestRepaint() => notifyListeners();

  // ── SVG export ────────────────────────────────────────────────────────────

  String toSvg({double width = 800, double height = 600}) =>
      FabricSerializer.exportSvg(this, width: width, height: height);

  @override
  void dispose() {
    for (final obj in _objects) _detachWithClosure(obj);
    super.dispose();
  }
}
