import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../canvas/fabric_canvas.dart';
import '../canvas/fabric_controller.dart';
import '../brushes/pencil_brush.dart';
import '../brushes/eraser_brush.dart';
import '../brushes/spray_brush.dart';
import '../objects/fabric_object.dart';
import '../objects/fabric_group.dart';
import '../utils/fabric_serializer.dart';

// ── Public enums & types ────────────────────────────────────────────────────

/// Where the built-in toolbar appears relative to the canvas.
enum FabricToolbarPosition { top, bottom, left, right, floating }

/// Items that can appear in [FabricBoard]'s built-in toolbar.
///
/// **Mode tools** (select, pencil, eraser, spray, draw*, add*) are mutually
/// exclusive — selecting one deactivates the previous.
///
/// **Action tools** (undo, redo, delete, clear, …) execute immediately.
///
/// **Settings tools** (colorPicker, strokeColor, brushWidth) open a picker UI.
///
/// **Export tools** (exportJson, exportImage, submit) produce output or fire callbacks.
///
/// Use [FabricTool.divider] to insert a visual separator between groups.
enum FabricTool {
  // ── Mode tools ─────────────────────────────────────────────────────────
  select,
  pencil,
  eraser,
  spray,
  drawRect,
  drawCircle,
  drawEllipse,
  drawTriangle,
  drawLine,
  addText,
  addTextBox,

  // ── Action tools ────────────────────────────────────────────────────────
  undo,
  redo,
  delete,
  clear,
  duplicate,
  selectAll,
  group,
  ungroup,
  bringToFront,
  sendToBack,
  bringForward,
  sendBackward,
  flipH,
  flipV,
  zoomIn,
  zoomOut,
  resetView,

  // ── Settings tools ──────────────────────────────────────────────────────
  colorPicker,
  strokeColor,
  brushWidth,

  // ── Export & submit tools ───────────────────────────────────────────────
  /// Opens a sheet showing the canvas as pretty-printed JSON with a copy button.
  exportJson,

  /// Renders the canvas to a PNG image and shows a preview dialog.
  exportImage,

  /// Calls [FabricBoard.onSubmit] with the current canvas JSON.
  submit,

  // ── Visual ──────────────────────────────────────────────────────────────
  divider,
}

/// Visual style for the built-in toolbar.
class FabricToolbarStyle {
  const FabricToolbarStyle({
    this.backgroundColor,
    this.selectedColor,
    this.iconColor,
    this.selectedIconColor,
    this.borderRadius = 12.0,
    this.elevation = 4.0,
    this.iconSize = 22.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  });

  /// Toolbar background. Defaults to [ColorScheme.surface].
  final Color? backgroundColor;

  /// Highlight for the active mode tool. Defaults to [ColorScheme.primaryContainer].
  final Color? selectedColor;

  /// Icon color. Defaults to [ColorScheme.onSurface].
  final Color? iconColor;

  /// Icon color when active. Defaults to [ColorScheme.onPrimaryContainer].
  final Color? selectedIconColor;

  final double borderRadius;
  final double elevation;
  final double iconSize;
  final EdgeInsetsGeometry padding;
}

// ── Default toolbar items ───────────────────────────────────────────────────

const List<FabricTool> _kDefaultTools = [
  FabricTool.select,
  FabricTool.pencil,
  FabricTool.eraser,
  FabricTool.spray,
  FabricTool.divider,
  FabricTool.drawRect,
  FabricTool.drawCircle,
  FabricTool.drawEllipse,
  FabricTool.drawTriangle,
  FabricTool.drawLine,
  FabricTool.divider,
  FabricTool.addText,
  FabricTool.addTextBox,
  FabricTool.divider,
  FabricTool.undo,
  FabricTool.redo,
  FabricTool.delete,
  FabricTool.clear,
  FabricTool.divider,
  FabricTool.colorPicker,
  FabricTool.strokeColor,
  FabricTool.brushWidth,
  FabricTool.divider,
  FabricTool.exportJson,
  FabricTool.exportImage,
];

// ── FabricBoard ─────────────────────────────────────────────────────────────

/// An all-in-one canvas widget with a built-in toolbar and sane defaults.
///
/// Drop it anywhere in your widget tree — it works like a [Container] with
/// canvas super-powers. Supply a [child] to render any Flutter widget as the
/// canvas background, and control every feature with simple bool flags.
///
/// ```dart
/// FabricBoard(
///   backgroundColor: Colors.white,
///   enableZoom: true,
///   showToolbar: true,
///   showToolbarLabels: true,   // name under each icon
///   showUserGuide: true,       // "?" help button
///   onSubmit: (json) => sendToServer(json),
///   onChangeJsonData: (json) => setState(() => _liveJson = json),
/// )
/// ```
class FabricBoard extends StatefulWidget {
  const FabricBoard({
    super.key,

    // ── Controller ───────────────────────────────────────────────────────────
    this.controller,

    // ── Size & background ────────────────────────────────────────────────────
    this.width,
    this.height,
    this.backgroundColor = Colors.white,
    this.child,

    // ── Feature toggles ──────────────────────────────────────────────────────
    this.enableSelection = true,
    this.enableDrag = true,
    this.enablePan = true,
    this.enableZoom = true,
    this.enableMarqueeSelection = true,
    this.enableKeyboardShortcuts = true,
    this.enableDoubleTapEdit = true,
    this.enableLongPressMenu = true,

    // ── Built-in toolbar ─────────────────────────────────────────────────────
    this.showToolbar = true,
    this.toolbarPosition = FabricToolbarPosition.bottom,
    this.toolbarItems,
    this.toolbarStyle = const FabricToolbarStyle(),
    this.showToolbarLabels = false,

    // ── User guide ───────────────────────────────────────────────────────────
    this.showUserGuide = true,

    // ── Drawing defaults ─────────────────────────────────────────────────────
    this.initialFillColor = Colors.blue,
    this.initialStrokeColor = Colors.transparent,
    this.initialBrushWidth = 4.0,
    this.initialFontSize = 24.0,

    // ── Callbacks ────────────────────────────────────────────────────────────
    this.onObjectAdded,
    this.onObjectRemoved,
    this.onObjectModified,
    this.onObjectSelected,
    this.onSelectionCleared,
    this.onDoubleTap,
    this.onLongPress,
    this.onCanvasChanged,
    this.onReady,

    // ── Export & Submit callbacks ─────────────────────────────────────────────
    this.onSubmit,
    this.onChangeJsonData,
    this.onImageExported,
  });

  // ── Controller ─────────────────────────────────────────────────────────────
  final FabricController? controller;

  // ── Size & background ───────────────────────────────────────────────────────
  final double? width;
  final double? height;
  final Color backgroundColor;

  /// Widget rendered behind all canvas objects — use for images, gradients, etc.
  final Widget? child;

  // ── Feature toggles ─────────────────────────────────────────────────────────
  final bool enableSelection;
  final bool enableDrag;
  final bool enablePan;
  final bool enableZoom;
  final bool enableMarqueeSelection;
  final bool enableKeyboardShortcuts;
  final bool enableDoubleTapEdit;
  final bool enableLongPressMenu;

  // ── Built-in toolbar ─────────────────────────────────────────────────────
  final bool showToolbar;
  final FabricToolbarPosition toolbarPosition;
  final List<FabricTool>? toolbarItems;
  final FabricToolbarStyle toolbarStyle;

  /// Show a text label below each tool icon (default: false).
  final bool showToolbarLabels;

  // ── User guide ───────────────────────────────────────────────────────────
  /// Show a floating "?" button that opens a context-aware usage guide.
  final bool showUserGuide;

  // ── Drawing defaults ─────────────────────────────────────────────────────
  final Color initialFillColor;
  final Color initialStrokeColor;
  final double initialBrushWidth;
  final double initialFontSize;

  // ── Callbacks ────────────────────────────────────────────────────────────
  final void Function(FabricObject)? onObjectAdded;
  final void Function(FabricObject)? onObjectRemoved;
  final void Function(FabricObject)? onObjectModified;
  final void Function(FabricObject)? onObjectSelected;
  final void Function()? onSelectionCleared;
  final void Function(Offset canvasPosition)? onDoubleTap;
  final void Function(FabricObject)? onLongPress;
  final void Function()? onCanvasChanged;

  /// Called once after the widget is built and [controller] is ready.
  final void Function(FabricController controller)? onReady;

  // ── Export & Submit callbacks ─────────────────────────────────────────────

  /// Called when [FabricTool.submit] is tapped, or when
  /// [FabricBoardState.submit] is called programmatically.
  /// Receives the full canvas as a JSON [String].
  final void Function(String json)? onSubmit;

  /// Called when the user taps Share/Save inside the Export Image dialog, or
  /// when [FabricBoardState.exportImage] resolves and the app wants to act on
  /// the bytes. Receives the raw bytes and the chosen format (`"png"` or
  /// `"jpg"`). Use `share_plus` or `path_provider` in your app to share/save.
  final void Function(Uint8List bytes, String format)? onImageExported;

  /// Fires on every canvas change with the latest canvas JSON.
  /// Useful for auto-saving, live previews, or real-time collaboration.
  /// Debounce on the receiving end if used for heavy operations.
  final void Function(String json)? onChangeJsonData;

  @override
  State<FabricBoard> createState() => FabricBoardState();
}

// ── FabricBoardState ─────────────────────────────────────────────────────────

class FabricBoardState extends State<FabricBoard> {
  late FabricController _ctrl;
  bool _ownsController = false;

  FabricTool _activeTool = FabricTool.select;
  Color _fillColor = Colors.blue;
  Color _strokeColor = Colors.transparent;
  double _brushWidth = 4.0;

  // ── Public API ─────────────────────────────────────────────────────────────

  FabricController get controller => _ctrl;
  FabricTool get activeTool => _activeTool;

  Color get fillColor => _fillColor;
  set fillColor(Color c) {
    setState(() => _fillColor = c);
    _applyColor(c);
  }

  Color get strokeColor => _strokeColor;
  set strokeColor(Color c) {
    setState(() => _strokeColor = c);
    _ctrl.activeStrokeColor = c;
  }

  double get brushWidth => _brushWidth;
  set brushWidth(double w) {
    setState(() => _brushWidth = w);
    _ctrl.activeStrokeWidth = w;
    _syncBrushWidth(w);
  }

  /// Programmatically switch the active tool.
  void setTool(FabricTool tool) => _handleToolTap(tool);

  /// Returns the current canvas state as a JSON string.
  String exportJson() => FabricSerializer.exportCanvas(_ctrl);

  /// Renders the canvas objects to a PNG [Uint8List].
  ///
  /// [size] defaults to a tight bounding box around all objects.
  /// [pixelRatio] sets the physical resolution multiplier (default 2.0 = @2x).
  Future<Uint8List?> exportImage({double pixelRatio = 2.0, Size? size}) =>
      _ctrl.exportPng(pixelRatio: pixelRatio, size: size);

  /// Fires [FabricBoard.onSubmit] with the current canvas JSON.
  void submit() => widget.onSubmit?.call(FabricSerializer.exportCanvas(_ctrl));

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
    } else {
      _ctrl = FabricController(backgroundColor: widget.backgroundColor);
      _ownsController = true;
    }

    _fillColor = widget.initialFillColor;
    _strokeColor = widget.initialStrokeColor;
    _brushWidth = widget.initialBrushWidth;

    _ctrl.activeFillColor = _fillColor;
    _ctrl.activeStrokeColor = _strokeColor;
    _ctrl.activeStrokeWidth = _brushWidth;
    _ctrl.activeFontSize = widget.initialFontSize;

    _ctrl.onObjectAdded = widget.onObjectAdded;
    _ctrl.onObjectRemoved = widget.onObjectRemoved;
    _ctrl.onObjectModified = widget.onObjectModified;
    _ctrl.onSelectionCreated = (e) => widget.onObjectSelected
        ?.call(e.selected.isNotEmpty ? e.selected.last : e.selected.first);
    _ctrl.onSelectionCleared = (_) => widget.onSelectionCleared?.call();

    // Real-time JSON change notifications
    _ctrl.addListener(_notifyJsonChange);

    // freeDrawingBrush setter calls notifyListeners(), which would trigger
    // ListenableBuilder.setState during the first build — defer to post-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ctrl.freeDrawingBrush = PencilBrush()
        ..color = _fillColor
        ..width = _brushWidth;
      widget.onReady?.call(_ctrl);
    });
  }

  @override
  void didUpdateWidget(FabricBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backgroundColor != oldWidget.backgroundColor) {
      _ctrl.backgroundColor = widget.backgroundColor;
    }
    _ctrl.onObjectAdded = widget.onObjectAdded;
    _ctrl.onObjectRemoved = widget.onObjectRemoved;
    _ctrl.onObjectModified = widget.onObjectModified;
  }

  @override
  void dispose() {
    _ctrl.removeListener(_notifyJsonChange);
    if (_ownsController) _ctrl.dispose();
    super.dispose();
  }

  void _notifyJsonChange() {
    widget.onChangeJsonData?.call(FabricSerializer.exportCanvas(_ctrl));
  }

  // ── Tool handling ──────────────────────────────────────────────────────────

  void _handleToolTap(FabricTool tool) {
    final mode = _toolToMode(tool);

    if (mode != null) {
      setState(() => _activeTool = tool);
      _ctrl.interactionMode = mode;
      if (mode == FabricInteractionMode.pencil) {
        _ctrl.freeDrawingBrush = PencilBrush()
          ..color = _fillColor
          ..width = _brushWidth;
      } else if (mode == FabricInteractionMode.eraser) {
        _ctrl.freeDrawingBrush = EraserBrush()..width = _brushWidth;
      } else if (mode == FabricInteractionMode.spray) {
        _ctrl.freeDrawingBrush = SprayBrush()
          ..color = _fillColor
          ..width = _brushWidth;
      }
      return;
    }

    switch (tool) {
      case FabricTool.undo:
        if (_ctrl.canUndo) _ctrl.undo();
      case FabricTool.redo:
        if (_ctrl.canRedo) _ctrl.redo();
      case FabricTool.delete:
        _ctrl.removeActiveObjects();
      case FabricTool.clear:
        _ctrl.clear();
      case FabricTool.duplicate:
        final clones = _ctrl.activeObjects
            .map((o) => FabricSerializer.clone(o, nudge: const Offset(12, 12)))
            .whereType<FabricObject>()
            .toList();
        if (clones.isNotEmpty) {
          _ctrl.addAll(clones);
          _ctrl.setActiveObjects(clones);
        }
      case FabricTool.selectAll:
        _ctrl.selectAll();
      case FabricTool.group:
        _ctrl.groupActiveObjects();
      case FabricTool.ungroup:
        final obj = _ctrl.activeObject;
        if (obj is FabricGroup) _ctrl.ungroup(obj);
      case FabricTool.bringToFront:
        for (final o in _ctrl.activeObjects) {
          _ctrl.bringToFront(o);
        }
      case FabricTool.sendToBack:
        for (final o in _ctrl.activeObjects) {
          _ctrl.sendToBack(o);
        }
      case FabricTool.bringForward:
        for (final o in _ctrl.activeObjects) {
          _ctrl.bringForward(o);
        }
      case FabricTool.sendBackward:
        for (final o in _ctrl.activeObjects) {
          _ctrl.sendBackward(o);
        }
      case FabricTool.flipH:
        _ctrl.flipActiveObjectsX();
      case FabricTool.flipV:
        _ctrl.flipActiveObjectsY();
      case FabricTool.zoomIn:
        _ctrl.zoomTo(_ctrl.zoom * 1.25);
      case FabricTool.zoomOut:
        _ctrl.zoomTo(_ctrl.zoom * 0.8);
      case FabricTool.resetView:
        _ctrl.resetViewport();
      // Export & submit
      case FabricTool.exportJson:
        _showJsonExportSheet();
      case FabricTool.exportImage:
        _showImageExportDialog();
      case FabricTool.submit:
        widget.onSubmit?.call(FabricSerializer.exportCanvas(_ctrl));
      default:
        break;
    }
  }

  FabricInteractionMode? _toolToMode(FabricTool tool) {
    switch (tool) {
      case FabricTool.select:
        return FabricInteractionMode.select;
      case FabricTool.pencil:
        return FabricInteractionMode.pencil;
      case FabricTool.eraser:
        return FabricInteractionMode.eraser;
      case FabricTool.spray:
        return FabricInteractionMode.spray;
      case FabricTool.drawRect:
        return FabricInteractionMode.drawRect;
      case FabricTool.drawCircle:
        return FabricInteractionMode.drawCircle;
      case FabricTool.drawEllipse:
        return FabricInteractionMode.drawEllipse;
      case FabricTool.drawTriangle:
        return FabricInteractionMode.drawTriangle;
      case FabricTool.drawLine:
        return FabricInteractionMode.drawLine;
      case FabricTool.addText:
        return FabricInteractionMode.addText;
      case FabricTool.addTextBox:
        return FabricInteractionMode.addTextBox;
      default:
        return null;
    }
  }

  void _applyColor(Color color) {
    _ctrl.activeFillColor = color;
    final mode = _ctrl.interactionMode;
    if (mode == FabricInteractionMode.pencil) {
      (_ctrl.freeDrawingBrush as PencilBrush?)?.color = color;
    } else if (mode == FabricInteractionMode.spray) {
      (_ctrl.freeDrawingBrush as SprayBrush?)?.color = color;
    }
    for (final obj in _ctrl.activeObjects) {
      obj.set(fill: color);
    }
  }

  void _applyStrokeColor(Color color) {
    _ctrl.activeStrokeColor = color;
    for (final obj in _ctrl.activeObjects) {
      obj.set(stroke: color);
    }
  }

  void _syncBrushWidth(double w) {
    _ctrl.activeStrokeWidth = w;
    final brush = _ctrl.freeDrawingBrush;
    if (brush != null) brush.width = w;
  }

  // ── Export / submit dialogs ────────────────────────────────────────────────

  void _showJsonExportSheet() {
    final json = FabricSerializer.exportCanvas(_ctrl);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _JsonExportSheet(json: json),
    );
  }

  void _showImageExportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImageExportDialog(
        controller: _ctrl,
        onShare: widget.onImageExported,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Widget canvas = FabricCanvas(
      controller: _ctrl,
      backgroundColor: widget.backgroundColor,
      enablePan: widget.enablePan,
      enableZoom: widget.enableZoom,
      enableSelection: widget.enableSelection,
      enableDrag: widget.enableDrag,
      enableMarqueeSelection: widget.enableMarqueeSelection,
      enableKeyboardShortcuts: widget.enableKeyboardShortcuts,
      enableDoubleTapEdit: widget.enableDoubleTapEdit,
      onTapObject: widget.onObjectSelected,
      onDoubleTap: widget.onDoubleTap,
      onLongPressObject: widget.enableLongPressMenu ? null : widget.onLongPress,
    );

    if (widget.child != null) {
      canvas = Stack(
        fit: StackFit.expand,
        children: [widget.child!, canvas],
      );
    }

    if (widget.width != null || widget.height != null) {
      canvas =
          SizedBox(width: widget.width, height: widget.height, child: canvas);
    }

    Widget result;

    if (!widget.showToolbar) {
      result = canvas;
    } else {
      final toolbar = _BoardToolbar(
        items: widget.toolbarItems ?? _kDefaultTools,
        activeTool: _activeTool,
        fillColor: _fillColor,
        strokeColor: _strokeColor,
        brushWidth: _brushWidth,
        style: widget.toolbarStyle,
        showLabels: widget.showToolbarLabels,
        isHorizontal: widget.toolbarPosition == FabricToolbarPosition.top ||
            widget.toolbarPosition == FabricToolbarPosition.bottom ||
            widget.toolbarPosition == FabricToolbarPosition.floating,
        onToolTap: _handleToolTap,
        onFillColorChanged: (c) {
          setState(() => _fillColor = c);
          _applyColor(c);
        },
        onStrokeColorChanged: (c) {
          setState(() => _strokeColor = c);
          _applyStrokeColor(c);
        },
        onBrushWidthChanged: (w) {
          setState(() => _brushWidth = w);
          _syncBrushWidth(w);
        },
      );

      switch (widget.toolbarPosition) {
        case FabricToolbarPosition.top:
          result = Column(children: [toolbar, Expanded(child: canvas)]);
        case FabricToolbarPosition.bottom:
          result = Column(children: [Expanded(child: canvas), toolbar]);
        case FabricToolbarPosition.left:
          result = Row(children: [toolbar, Expanded(child: canvas)]);
        case FabricToolbarPosition.right:
          result = Row(children: [Expanded(child: canvas), toolbar]);
        case FabricToolbarPosition.floating:
          result = Stack(
            children: [
              canvas,
              Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: toolbar,
              ),
            ],
          );
      }
    }

    if (widget.showUserGuide) {
      result = Stack(
        fit: StackFit.expand,
        children: [
          result,
          Positioned(
            top: 60,
            right: 8,
            child: _UserGuideButton(
              enableSelection: widget.enableSelection,
              enableDrag: widget.enableDrag,
              enablePan: widget.enablePan,
              enableZoom: widget.enableZoom,
              enableMarqueeSelection: widget.enableMarqueeSelection,
              enableDoubleTapEdit: widget.enableDoubleTapEdit,
              enableLongPressMenu: widget.enableLongPressMenu,
              enableKeyboardShortcuts: widget.enableKeyboardShortcuts,
              showToolbar: widget.showToolbar,
              showToolbarLabels: widget.showToolbarLabels,
              hasSubmit: widget.onSubmit != null ||
                  (widget.toolbarItems?.contains(FabricTool.submit) ?? false) ||
                  (_kDefaultTools.contains(FabricTool.submit)),
              hasExport: (widget.toolbarItems ?? _kDefaultTools).any((t) =>
                  t == FabricTool.exportJson || t == FabricTool.exportImage),
            ),
          ),
        ],
      );
    }

    return result;
  }
}

// ── _BoardToolbar ─────────────────────────────────────────────────────────────

class _BoardToolbar extends StatelessWidget {
  const _BoardToolbar({
    required this.items,
    required this.activeTool,
    required this.fillColor,
    required this.strokeColor,
    required this.brushWidth,
    required this.style,
    required this.isHorizontal,
    required this.showLabels,
    required this.onToolTap,
    required this.onFillColorChanged,
    required this.onStrokeColorChanged,
    required this.onBrushWidthChanged,
  });

  final List<FabricTool> items;
  final FabricTool activeTool;
  final Color fillColor;
  final Color strokeColor;
  final double brushWidth;
  final FabricToolbarStyle style;
  final bool isHorizontal;
  final bool showLabels;
  final void Function(FabricTool) onToolTap;
  final void Function(Color) onFillColorChanged;
  final void Function(Color) onStrokeColorChanged;
  final void Function(double) onBrushWidthChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = style.backgroundColor ?? cs.surface;
    final children = items.map((t) => _buildItem(context, t, cs)).toList();
    final scrollable = isHorizontal
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: style.padding,
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: style.padding,
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          );

    return Material(
      elevation: style.elevation,
      borderRadius: BorderRadius.circular(style.borderRadius),
      color: bg,
      child: scrollable,
    );
  }

  Widget _buildItem(BuildContext context, FabricTool tool, ColorScheme cs) {
    if (tool == FabricTool.divider) {
      return isHorizontal
          ? VerticalDivider(
              width: 16,
              thickness: 1,
              indent: 6,
              endIndent: 6,
              color: cs.outlineVariant)
          : Divider(
              height: 16,
              thickness: 1,
              indent: 6,
              endIndent: 6,
              color: cs.outlineVariant);
    }

    if (tool == FabricTool.colorPicker) {
      return _ColorSwatchButton(
        color: fillColor,
        tooltip: 'Fill color',
        label: showLabels ? 'Fill' : null,
        onTap: () => _showColorPicker(
            context, fillColor, 'Fill Color', onFillColorChanged),
      );
    }

    if (tool == FabricTool.strokeColor) {
      return _ColorSwatchButton(
        color: strokeColor,
        tooltip: 'Stroke color',
        label: showLabels ? 'Stroke' : null,
        isOutline: true,
        onTap: () => _showColorPicker(
            context, strokeColor, 'Stroke Color', onStrokeColorChanged),
      );
    }

    if (tool == FabricTool.brushWidth) {
      return _WidthButton(
        width: brushWidth,
        iconSize: style.iconSize,
        iconColor: style.iconColor ?? cs.onSurface,
        label: showLabels ? 'Width' : null,
        onTap: () => _showWidthPicker(context),
      );
    }

    final isMode = _toolToMode(tool) != null;
    final isActive = isMode && activeTool == tool;
    final selectedBg = style.selectedColor ?? cs.primaryContainer;
    final iconClr = isActive
        ? (style.selectedIconColor ?? cs.onPrimaryContainer)
        : (style.iconColor ?? cs.onSurface);

    Widget iconWidget;
    if (tool == FabricTool.drawEllipse) {
      iconWidget = _EllipseIcon(size: style.iconSize, color: iconClr);
    } else {
      iconWidget = Icon(_toolIcon(tool), size: style.iconSize, color: iconClr);
    }

    if (tool == FabricTool.flipV) {
      iconWidget = Transform.rotate(angle: 1.5708, child: iconWidget);
    }

    Widget buttonContent;
    if (showLabels) {
      buttonContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 2),
          Text(
            _toolLabel(tool),
            style: TextStyle(fontSize: 9, color: iconClr, height: 1.1),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      );
    } else {
      buttonContent = iconWidget;
    }

    final btnSize = showLabels ? 52.0 : 40.0;

    return Tooltip(
      message: _toolLabel(tool),
      child: InkWell(
        onTap: () => onToolTap(tool),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: btnSize,
          height: btnSize,
          decoration: isActive
              ? BoxDecoration(
                  color: selectedBg, borderRadius: BorderRadius.circular(8))
              : null,
          alignment: Alignment.center,
          child: buttonContent,
        ),
      ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    Color current,
    String title,
    void Function(Color) onChanged,
  ) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorPickerDialog(initial: current, title: title),
    );
    if (picked != null) onChanged(picked);
  }

  void _showWidthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _WidthPickerSheet(
        initial: brushWidth,
        onChanged: onBrushWidthChanged,
      ),
    );
  }

  static FabricInteractionMode? _toolToMode(FabricTool tool) {
    switch (tool) {
      case FabricTool.select:
        return FabricInteractionMode.select;
      case FabricTool.pencil:
        return FabricInteractionMode.pencil;
      case FabricTool.eraser:
        return FabricInteractionMode.eraser;
      case FabricTool.spray:
        return FabricInteractionMode.spray;
      case FabricTool.drawRect:
        return FabricInteractionMode.drawRect;
      case FabricTool.drawCircle:
        return FabricInteractionMode.drawCircle;
      case FabricTool.drawEllipse:
        return FabricInteractionMode.drawEllipse;
      case FabricTool.drawTriangle:
        return FabricInteractionMode.drawTriangle;
      case FabricTool.drawLine:
        return FabricInteractionMode.drawLine;
      case FabricTool.addText:
        return FabricInteractionMode.addText;
      case FabricTool.addTextBox:
        return FabricInteractionMode.addTextBox;
      default:
        return null;
    }
  }

  static String _toolLabel(FabricTool tool) {
    switch (tool) {
      case FabricTool.select:
        return 'Select';
      case FabricTool.pencil:
        return 'Pencil';
      case FabricTool.eraser:
        return 'Eraser';
      case FabricTool.spray:
        return 'Spray';
      case FabricTool.drawRect:
        return 'Rect';
      case FabricTool.drawCircle:
        return 'Circle';
      case FabricTool.drawEllipse:
        return 'Ellipse';
      case FabricTool.drawTriangle:
        return 'Triangle';
      case FabricTool.drawLine:
        return 'Line';
      case FabricTool.addText:
        return 'Text';
      case FabricTool.addTextBox:
        return 'Text Box';
      case FabricTool.undo:
        return 'Undo';
      case FabricTool.redo:
        return 'Redo';
      case FabricTool.delete:
        return 'Delete';
      case FabricTool.clear:
        return 'Clear';
      case FabricTool.duplicate:
        return 'Duplicate';
      case FabricTool.selectAll:
        return 'Select All';
      case FabricTool.group:
        return 'Group';
      case FabricTool.ungroup:
        return 'Ungroup';
      case FabricTool.bringToFront:
        return 'To Front';
      case FabricTool.sendToBack:
        return 'To Back';
      case FabricTool.bringForward:
        return 'Forward';
      case FabricTool.sendBackward:
        return 'Backward';
      case FabricTool.flipH:
        return 'Flip H';
      case FabricTool.flipV:
        return 'Flip V';
      case FabricTool.zoomIn:
        return 'Zoom In';
      case FabricTool.zoomOut:
        return 'Zoom Out';
      case FabricTool.resetView:
        return 'Reset';
      case FabricTool.colorPicker:
        return 'Fill Color';
      case FabricTool.strokeColor:
        return 'Stroke Color';
      case FabricTool.brushWidth:
        return 'Brush Width';
      case FabricTool.exportJson:
        return 'Export JSON';
      case FabricTool.exportImage:
        return 'Export PNG';
      case FabricTool.submit:
        return 'Submit';
      case FabricTool.divider:
        return '';
    }
  }

  static IconData _toolIcon(FabricTool tool) {
    switch (tool) {
      case FabricTool.select:
        return Icons.near_me_outlined;
      case FabricTool.pencil:
        return Icons.edit_outlined;
      case FabricTool.eraser:
        return Icons.auto_fix_normal_outlined;
      case FabricTool.spray:
        return Icons.blur_on_outlined;
      case FabricTool.drawRect:
        return Icons.crop_square_outlined;
      case FabricTool.drawCircle:
        return Icons.circle_outlined;
      case FabricTool.drawEllipse:
        return Icons.radio_button_unchecked;
      case FabricTool.drawTriangle:
        return Icons.change_history_outlined;
      case FabricTool.drawLine:
        return Icons.horizontal_rule;
      case FabricTool.addText:
        return Icons.text_fields;
      case FabricTool.addTextBox:
        return Icons.wrap_text;
      case FabricTool.undo:
        return Icons.undo;
      case FabricTool.redo:
        return Icons.redo;
      case FabricTool.delete:
        return Icons.delete_outline;
      case FabricTool.clear:
        return Icons.delete_forever_outlined;
      case FabricTool.duplicate:
        return Icons.file_copy_outlined;
      case FabricTool.selectAll:
        return Icons.select_all;
      case FabricTool.group:
        return Icons.folder_outlined;
      case FabricTool.ungroup:
        return Icons.folder_open_outlined;
      case FabricTool.bringToFront:
        return Icons.flip_to_front;
      case FabricTool.sendToBack:
        return Icons.flip_to_back;
      case FabricTool.bringForward:
        return Icons.keyboard_arrow_up;
      case FabricTool.sendBackward:
        return Icons.keyboard_arrow_down;
      case FabricTool.flipH:
        return Icons.flip;
      case FabricTool.flipV:
        return Icons.flip;
      case FabricTool.zoomIn:
        return Icons.zoom_in;
      case FabricTool.zoomOut:
        return Icons.zoom_out;
      case FabricTool.resetView:
        return Icons.fit_screen;
      case FabricTool.colorPicker:
        return Icons.palette_outlined;
      case FabricTool.strokeColor:
        return Icons.border_color_outlined;
      case FabricTool.brushWidth:
        return Icons.line_weight;
      case FabricTool.exportJson:
        return Icons.data_object_outlined;
      case FabricTool.exportImage:
        return Icons.image_outlined;
      case FabricTool.submit:
        return Icons.send_outlined;
      case FabricTool.divider:
        return Icons.more_vert;
    }
  }
}

// ── Custom ellipse icon ───────────────────────────────────────────────────────

class _EllipseIcon extends StatelessWidget {
  const _EllipseIcon({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _EllipsePainter(color: color),
    );
  }
}

class _EllipsePainter extends CustomPainter {
  const _EllipsePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.92,
        height: size.height * 0.52,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_EllipsePainter old) => old.color != color;
}

// ── Color swatch button ───────────────────────────────────────────────────────

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.isOutline = false,
    this.label,
  });

  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool isOutline;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Transparent colors must still render a visible swatch
    final isTransparent = (color.a * 255.0).round() == 0;

    Widget swatch;
    if (isOutline) {
      // Stroke color button
      swatch = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isTransparent ? cs.outlineVariant : color,
            width: isTransparent ? 1.5 : 3,
          ),
        ),
        child: isTransparent
            ? Icon(Icons.block, size: 12, color: cs.onSurfaceVariant)
            : null,
      );
    } else {
      // Fill color button
      swatch = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isTransparent ? null : color,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline, width: 1.5),
        ),
        child: isTransparent
            ? Icon(Icons.block, size: 12, color: cs.onSurfaceVariant)
            : null,
      );
    }

    Widget content = label != null
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            swatch,
            const SizedBox(height: 2),
            Text(label!,
                style: TextStyle(fontSize: 9, color: cs.onSurface, height: 1.1),
                overflow: TextOverflow.ellipsis),
          ])
        : swatch;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: label != null ? 52 : 40,
          height: label != null ? 52 : 40,
          child: Center(child: content),
        ),
      ),
    );
  }
}

// ── Width button ──────────────────────────────────────────────────────────────

class _WidthButton extends StatelessWidget {
  const _WidthButton({
    required this.width,
    required this.iconSize,
    required this.iconColor,
    required this.onTap,
    this.label,
  });

  final double width;
  final double iconSize;
  final Color iconColor;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final iconW = Icon(Icons.line_weight, size: iconSize, color: iconColor);
    Widget content = label != null
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            iconW,
            const SizedBox(height: 2),
            Text(label!,
                style: TextStyle(fontSize: 9, color: iconColor, height: 1.1),
                overflow: TextOverflow.ellipsis),
          ])
        : iconW;

    return Tooltip(
      message: 'Brush Width (${width.toStringAsFixed(0)})',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: label != null ? 52 : 40,
          height: label != null ? 52 : 40,
          child: Center(child: content),
        ),
      ),
    );
  }
}

// ── Width picker sheet ────────────────────────────────────────────────────────

class _WidthPickerSheet extends StatefulWidget {
  const _WidthPickerSheet({required this.initial, required this.onChanged});
  final double initial;
  final void Function(double) onChanged;

  @override
  State<_WidthPickerSheet> createState() => _WidthPickerSheetState();
}

class _WidthPickerSheetState extends State<_WidthPickerSheet> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Brush Width — ${_value.toStringAsFixed(0)} px',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              height: _value.clamp(2, 40),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          Slider(
            value: _value,
            min: 1,
            max: 60,
            divisions: 59,
            label: _value.toStringAsFixed(0),
            onChanged: (v) {
              setState(() => _value = v);
              widget.onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

// ── Color picker dialog ───────────────────────────────────────────────────────

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title});
  final Color initial;
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;

  static const _kPresets = [
    Color(0xFF000000),
    Color(0xFF212121),
    Color(0xFF424242),
    Color(0xFF757575),
    Color(0xFF9E9E9E),
    Color(0xFFBDBDBD),
    Color(0xFFE0E0E0),
    Color(0xFFFFFFFF),
    Color(0xFFB71C1C),
    Color(0xFFF44336),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF03A9F4),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFCDDC39),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFF00BFA5),
    Color(0xFFAA00FF),
    Color(0xFF2962FF),
    Color(0xFF00C853),
    Color(0xFFFFD600),
    Color(0xFFDD2C00),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              decoration: BoxDecoration(
                color: _selected,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selected = Colors.transparent),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selected == Colors.transparent
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        width: _selected == Colors.transparent ? 2.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child:
                        const Icon(Icons.block, size: 18, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Transparent',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kPresets.map((c) {
                final isSelected = c.toARGB32() == _selected.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selected = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                            size: 18,
                            color: c.computeLuminance() > 0.5
                                ? Colors.black87
                                : Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// ── JSON export sheet ─────────────────────────────────────────────────────────

class _JsonExportSheet extends StatelessWidget {
  const _JsonExportSheet({required this.json});
  final String json;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(children: [
              Icon(Icons.data_object_outlined, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text('Canvas JSON',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              // Copy button
              TextButton.icon(
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: json));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('JSON copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ]),
          ),
          // Character count badge
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${json.length} chars',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          // Scrollable JSON body
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                json,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image export dialog ───────────────────────────────────────────────────────

/// Available export image formats.
enum _ImgFormat { png, jpg }

class _ImageExportDialog extends StatefulWidget {
  const _ImageExportDialog({
    required this.controller,
    this.onShare,
  });

  final FabricController controller;

  /// Called when the user taps Share / Save.
  /// [bytes] are always PNG-encoded; [format] is `"png"` or `"jpg"` (the user's
  /// preference). If `"jpg"` is selected the app should re-encode the bytes
  /// (e.g. with the `image` package) before sharing.
  final void Function(Uint8List bytes, String format)? onShare;

  @override
  State<_ImageExportDialog> createState() => _ImageExportDialogState();
}

class _ImageExportDialogState extends State<_ImageExportDialog> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  _ImgFormat _format = _ImgFormat.png;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = await widget.controller.exportPng(pixelRatio: 2.0);
      if (!mounted) return;
      setState(() { _bytes = bytes; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _share() async {
    if (_bytes == null || widget.onShare == null) return;
    setState(() => _sharing = true);
    try {
      widget.onShare!(_bytes!, _format == _ImgFormat.png ? 'png' : 'jpg');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasBytes = _bytes != null && !_loading && _error == null;

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.image_outlined, color: cs.primary, size: 20),
        const SizedBox(width: 8),
        const Text('Export Image'),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Render failed: $_error',
                        style: TextStyle(color: cs.error)),
                  )
                : _bytes == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Nothing to export — canvas is empty.'),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Preview
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_bytes!,
                                fit: BoxFit.contain,
                                width: double.infinity),
                          ),
                          const SizedBox(height: 8),
                          // Size info
                          Text(
                            '${(_bytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB · @2×',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          // Format selector
                          Row(children: [
                            Text('Format:',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                            const SizedBox(width: 8),
                            _FormatChip(
                              label: 'PNG',
                              selected: _format == _ImgFormat.png,
                              onTap: () => setState(
                                  () => _format = _ImgFormat.png),
                            ),
                            const SizedBox(width: 6),
                            _FormatChip(
                              label: 'JPG',
                              selected: _format == _ImgFormat.jpg,
                              onTap: () => setState(
                                  () => _format = _ImgFormat.jpg),
                            ),
                          ]),
                          if (_format == _ImgFormat.jpg) ...[
                            const SizedBox(height: 4),
                            Text(
                              'PNG bytes are passed to onImageExported. '
                              'Re-encode to JPEG in your app (e.g. with the image package).',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
      ),
      actions: [
        // Share / Save button
        if (hasBytes)
          widget.onShare != null
              ? FilledButton.icon(
                  icon: _sharing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined, size: 16),
                  label: Text(_sharing ? 'Sharing…' : 'Share / Save'),
                  onPressed: _sharing ? null : _share,
                )
              : Tooltip(
                  message:
                      'Set onImageExported on FabricBoard to enable sharing',
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share / Save'),
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content: Text(
                          'Provide onImageExported on FabricBoard to share.'),
                      duration: Duration(seconds: 3),
                    )),
                  ),
                ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── User Guide ────────────────────────────────────────────────────────────────

class _UserGuideButton extends StatelessWidget {
  const _UserGuideButton({
    required this.enableSelection,
    required this.enableDrag,
    required this.enablePan,
    required this.enableZoom,
    required this.enableMarqueeSelection,
    required this.enableDoubleTapEdit,
    required this.enableLongPressMenu,
    required this.enableKeyboardShortcuts,
    required this.showToolbar,
    required this.showToolbarLabels,
    required this.hasSubmit,
    required this.hasExport,
  });

  final bool enableSelection;
  final bool enableDrag;
  final bool enablePan;
  final bool enableZoom;
  final bool enableMarqueeSelection;
  final bool enableDoubleTapEdit;
  final bool enableLongPressMenu;
  final bool enableKeyboardShortcuts;
  final bool showToolbar;
  final bool showToolbarLabels;
  final bool hasSubmit;
  final bool hasExport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'How to use this canvas',
      child: Material(
        color: cs.surface.withValues(alpha: 0.92),
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => _UserGuideSheet(
              enableSelection: enableSelection,
              enableDrag: enableDrag,
              enablePan: enablePan,
              enableZoom: enableZoom,
              enableMarqueeSelection: enableMarqueeSelection,
              enableDoubleTapEdit: enableDoubleTapEdit,
              enableLongPressMenu: enableLongPressMenu,
              enableKeyboardShortcuts: enableKeyboardShortcuts,
              showToolbar: showToolbar,
              showToolbarLabels: showToolbarLabels,
              hasSubmit: hasSubmit,
              hasExport: hasExport,
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_rounded, size: 16, color: cs.onSurface),
                const SizedBox(width: 4),
                Text('Help',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserGuideSheet extends StatelessWidget {
  const _UserGuideSheet({
    required this.enableSelection,
    required this.enableDrag,
    required this.enablePan,
    required this.enableZoom,
    required this.enableMarqueeSelection,
    required this.enableDoubleTapEdit,
    required this.enableLongPressMenu,
    required this.enableKeyboardShortcuts,
    required this.showToolbar,
    required this.showToolbarLabels,
    required this.hasSubmit,
    required this.hasExport,
  });

  final bool enableSelection;
  final bool enableDrag;
  final bool enablePan;
  final bool enableZoom;
  final bool enableMarqueeSelection;
  final bool enableDoubleTapEdit;
  final bool enableLongPressMenu;
  final bool enableKeyboardShortcuts;
  final bool showToolbar;
  final bool showToolbarLabels;
  final bool hasSubmit;
  final bool hasExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Icon(Icons.help_outline_rounded, color: cs.primary, size: 22),
              const SizedBox(width: 10),
              Text('How to use this canvas',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // ── Gestures ──
                _sectionHeader('Gestures', Icons.touch_app_outlined, theme, cs),
                const SizedBox(height: 8),
                _guideTile(Icons.touch_app_outlined, 'Tap',
                    'Select an object on the canvas', cs,
                    enabled: enableSelection),
                _guideTile(
                    Icons.drag_indicator, 'Drag', 'Move a selected object', cs,
                    enabled: enableSelection && enableDrag),
                _guideTile(Icons.select_all, 'Drag on empty area',
                    'Rubber-band select multiple objects', cs,
                    enabled: enableMarqueeSelection),
                _guideTile(Icons.edit_outlined, 'Double-tap text',
                    'Edit text content inline', cs,
                    enabled: enableDoubleTapEdit),
                _guideTile(Icons.touch_app, 'Long-press an object',
                    'Open the style & arrange editor', cs,
                    enabled: enableLongPressMenu),
                _guideTile(Icons.pinch_outlined, 'Pinch two fingers',
                    'Zoom in or out', cs,
                    enabled: enableZoom),
                _guideTile(Icons.pan_tool_alt_outlined, 'Two-finger drag',
                    'Pan / scroll the viewport', cs,
                    enabled: enablePan),

                // ── Keyboard shortcuts ──
                if (enableKeyboardShortcuts) ...[
                  const SizedBox(height: 20),
                  _sectionHeader(
                      'Keyboard Shortcuts', Icons.keyboard_outlined, theme, cs),
                  const SizedBox(height: 8),
                  _shortcutTile('Del / Backspace', 'Delete selected', cs),
                  _shortcutTile('Ctrl + Z', 'Undo', cs),
                  _shortcutTile('Ctrl + Y  /  Ctrl + Shift + Z', 'Redo', cs),
                  _shortcutTile('Ctrl + C', 'Copy', cs),
                  _shortcutTile('Ctrl + V', 'Paste', cs),
                  _shortcutTile('Ctrl + X', 'Cut', cs),
                  _shortcutTile('Ctrl + A', 'Select all', cs),
                  _shortcutTile('Arrow keys', 'Nudge selected 1 px', cs),
                ],

                // ── Toolbar ──
                if (showToolbar) ...[
                  const SizedBox(height: 20),
                  _sectionHeader(
                      'Toolbar', Icons.dashboard_customize_outlined, theme, cs),
                  const SizedBox(height: 8),
                  _toolGroupTile(
                      Icons.near_me_outlined,
                      'Select',
                      'Tap objects to select, drag handles to resize & rotate.',
                      cs),
                  _toolGroupTile(
                      Icons.edit_outlined,
                      'Pencil / Eraser / Spray',
                      'Free-hand drawing tools. Choose color and brush width.',
                      cs),
                  _toolGroupTile(
                      Icons.crop_square_outlined,
                      'Shapes',
                      'Draw rectangles, circles, ellipses, triangles, and lines by dragging.',
                      cs),
                  _toolGroupTile(Icons.text_fields, 'Text / Text Box',
                      'Tap the canvas to place text. Double-tap to edit.', cs),
                  _toolGroupTile(
                      Icons.palette_outlined,
                      'Fill & Stroke colors',
                      'Set the fill and border color for shapes and drawing.',
                      cs),
                  _toolGroupTile(Icons.undo, 'Undo / Redo',
                      'Step back or forward through your editing history.', cs),
                  if (showToolbarLabels)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _infoBanner(
                          'Tool names are shown below each icon to help you learn them faster.',
                          cs),
                    ),
                ],

                // ── Export & Submit ──
                if (hasExport || hasSubmit) ...[
                  const SizedBox(height: 20),
                  _sectionHeader(
                      'Export & Submit', Icons.output_outlined, theme, cs),
                  const SizedBox(height: 8),
                  if (hasExport) ...[
                    _toolGroupTile(
                        Icons.data_object_outlined,
                        'Export JSON',
                        'Opens a sheet showing the full canvas as JSON. Tap Copy to copy to clipboard.',
                        cs),
                    _toolGroupTile(
                        Icons.image_outlined,
                        'Export PNG',
                        'Renders the canvas to a PNG image preview. Use exportImage() in code to get the raw bytes.',
                        cs),
                  ],
                  if (hasSubmit)
                    _toolGroupTile(
                        Icons.send_outlined,
                        'Submit',
                        'Calls the onSubmit callback with the canvas JSON — use this to send data to your server or form.',
                        cs),
                  _infoBanner(
                      'Programmatic access: key.currentState!.exportJson() · exportImage() · submit()',
                      cs),
                ],

                // ── Tips ──
                const SizedBox(height: 20),
                _sectionHeader('Tips', Icons.lightbulb_outline, theme, cs),
                const SizedBox(height: 8),
                _tipTile(
                    'Long-press any object to edit its color, size, opacity, and layer order.',
                    cs),
                _tipTile(
                    'Drag the resize handles on a selected object to scale it.',
                    cs),
                _tipTile(
                    'Drag the rotate handle (top centre) to rotate a selected object.',
                    cs),
                _tipTile(
                    'Use onChangeJsonData to receive the canvas JSON on every edit in real-time.',
                    cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
      String title, IconData icon, ThemeData theme, ColorScheme cs) {
    return Row(children: [
      Icon(icon, size: 16, color: cs.primary),
      const SizedBox(width: 6),
      Text(title,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _guideTile(
      IconData icon, String gesture, String description, ColorScheme cs,
      {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(enabled ? icon : Icons.block_outlined,
            size: 18, color: enabled ? cs.onSurface : cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                  fontSize: 13),
              children: [
                TextSpan(
                  text: '$gesture  ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: enabled ? null : TextDecoration.lineThrough),
                ),
                TextSpan(
                  text: enabled ? description : 'Disabled for this canvas',
                  style: TextStyle(
                      color: enabled
                          ? cs.onSurfaceVariant
                          : cs.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _shortcutTile(String keys, String action, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(keys,
              style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Text(action,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _toolGroupTile(
      IconData icon, String name, String desc, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: cs.onSurface),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              children: [
                TextSpan(
                    text: '$name  ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(
                    text: desc, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tipTile(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('•  ',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ),
      ]),
    );
  }

  Widget _infoBanner(String text, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
        ),
      ]),
    );
  }
}
