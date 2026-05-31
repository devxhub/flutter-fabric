import 'package:flutter/material.dart';
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
///   child: Image.asset('assets/background.png'),
/// )
/// ```
///
/// For programmatic access create a key and read [FabricBoardState]:
///
/// ```dart
/// final key = GlobalKey<FabricBoardState>();
/// FabricBoard(key: key)
/// // later:
/// key.currentState!.controller.add(FabricRect(...));
/// key.currentState!.setTool(FabricTool.pencil);
/// ```
///
/// For maximum control use [FabricController] + [FabricCanvas] directly.
class FabricBoard extends StatefulWidget {
  const FabricBoard({
    super.key,

    // ── Controller ───────────────────────────────────────────────────────────
    this.controller,

    // ── Size & background ────────────────────────────────────────────────────
    this.width,
    this.height,
    this.backgroundColor = Colors.white,

    /// Optional widget rendered as the canvas background (image, gradient, etc.)
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
  });

  // ── Controller ─────────────────────────────────────────────────────────────

  /// Provide your own controller to add/remove objects programmatically.
  /// If null, [FabricBoard] creates and owns one internally.
  final FabricController? controller;

  // ── Size & background ───────────────────────────────────────────────────────

  /// Explicit canvas width. When null the canvas expands to fill its parent.
  final double? width;

  /// Explicit canvas height. When null the canvas expands to fill its parent.
  final double? height;

  /// Canvas background color (default: white).
  final Color backgroundColor;

  /// Widget rendered behind all canvas objects — use for images, gradients, etc.
  final Widget? child;

  // ── Feature toggles ─────────────────────────────────────────────────────────

  /// Allows tapping objects to select them (default: true).
  final bool enableSelection;

  /// Allows dragging selected objects (default: true).
  final bool enableDrag;

  /// Allows panning the viewport (default: true).
  final bool enablePan;

  /// Allows pinch-to-zoom (default: true).
  final bool enableZoom;

  /// Allows rubber-band / marquee multi-select (default: true).
  final bool enableMarqueeSelection;

  /// Enables Del / Ctrl+Z / Ctrl+C etc. keyboard shortcuts (default: true).
  final bool enableKeyboardShortcuts;

  /// Double-tapping a text object opens the inline editor (default: true).
  final bool enableDoubleTapEdit;

  /// Long-pressing an object shows the built-in edit menu (default: true).
  /// Set to false and use [onLongPress] to show your own UI.
  final bool enableLongPressMenu;

  // ── Built-in toolbar ─────────────────────────────────────────────────────

  /// Show or hide the built-in toolbar (default: true).
  final bool showToolbar;

  /// Where the toolbar is placed (default: bottom).
  final FabricToolbarPosition toolbarPosition;

  /// Which tools appear. Defaults to all tools with dividers.
  final List<FabricTool>? toolbarItems;

  /// Visual styling for the toolbar.
  final FabricToolbarStyle toolbarStyle;

  // ── Drawing defaults ─────────────────────────────────────────────────────

  /// Starting fill color for shapes and drawing tools.
  final Color initialFillColor;

  /// Starting stroke/border color for shapes.
  final Color initialStrokeColor;

  /// Starting brush width (also used as shape stroke width).
  final double initialBrushWidth;

  /// Starting font size for text tools.
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

  /// Access the underlying controller to add/remove/query objects.
  FabricController get controller => _ctrl;

  /// The currently active toolbar tool.
  FabricTool get activeTool => _activeTool;

  /// Current fill color applied to new shapes and drawing strokes.
  Color get fillColor => _fillColor;
  set fillColor(Color c) {
    setState(() => _fillColor = c);
    _applyColor(c);
  }

  /// Current stroke/border color applied to new shapes.
  Color get strokeColor => _strokeColor;
  set strokeColor(Color c) {
    setState(() => _strokeColor = c);
    _ctrl.activeStrokeColor = c;
  }

  /// Current brush width (also shape stroke width).
  double get brushWidth => _brushWidth;
  set brushWidth(double w) {
    setState(() => _brushWidth = w);
    _ctrl.activeStrokeWidth = w;
    _syncBrushWidth(w);
  }

  /// Programmatically switch the active tool (same effect as tapping it).
  void setTool(FabricTool tool) => _handleToolTap(tool);

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

    // Sync creation defaults
    _ctrl.activeFillColor = _fillColor;
    _ctrl.activeStrokeColor = _strokeColor;
    _ctrl.activeStrokeWidth = _brushWidth;
    _ctrl.activeFontSize = widget.initialFontSize;

    // Wire controller callbacks
    _ctrl.onObjectAdded = widget.onObjectAdded;
    _ctrl.onObjectRemoved = widget.onObjectRemoved;
    _ctrl.onObjectModified = widget.onObjectModified;
    _ctrl.onSelectionCreated = (e) => widget.onObjectSelected?.call(
        e.selected.isNotEmpty ? e.selected.last : e.selected.first);
    _ctrl.onSelectionCleared = (_) => widget.onSelectionCleared?.call();

    // Default brush
    _ctrl.freeDrawingBrush = PencilBrush()
      ..color = _fillColor
      ..width = _brushWidth;

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (_ownsController) _ctrl.dispose();
    super.dispose();
  }

  // ── Tool handling ──────────────────────────────────────────────────────────

  void _handleToolTap(FabricTool tool) {
    final mode = _toolToMode(tool);

    // Mode tool — switch interaction mode
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

    // Action tool — execute and return (don't change activeTool)
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
        for (final o in _ctrl.activeObjects) { _ctrl.bringToFront(o); }
      case FabricTool.sendToBack:
        for (final o in _ctrl.activeObjects) { _ctrl.sendToBack(o); }
      case FabricTool.bringForward:
        for (final o in _ctrl.activeObjects) { _ctrl.bringForward(o); }
      case FabricTool.sendBackward:
        for (final o in _ctrl.activeObjects) { _ctrl.sendBackward(o); }
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
      default:
        break;
    }
  }

  FabricInteractionMode? _toolToMode(FabricTool tool) {
    switch (tool) {
      case FabricTool.select: return FabricInteractionMode.select;
      case FabricTool.pencil: return FabricInteractionMode.pencil;
      case FabricTool.eraser: return FabricInteractionMode.eraser;
      case FabricTool.spray: return FabricInteractionMode.spray;
      case FabricTool.drawRect: return FabricInteractionMode.drawRect;
      case FabricTool.drawCircle: return FabricInteractionMode.drawCircle;
      case FabricTool.drawEllipse: return FabricInteractionMode.drawEllipse;
      case FabricTool.drawTriangle: return FabricInteractionMode.drawTriangle;
      case FabricTool.drawLine: return FabricInteractionMode.drawLine;
      case FabricTool.addText: return FabricInteractionMode.addText;
      case FabricTool.addTextBox: return FabricInteractionMode.addTextBox;
      default: return null;
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
    // Apply to selected objects
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

    // Wrap with background child
    if (widget.child != null) {
      canvas = Stack(
        fit: StackFit.expand,
        children: [widget.child!, canvas],
      );
    }

    // Apply explicit size
    if (widget.width != null || widget.height != null) {
      canvas = SizedBox(width: widget.width, height: widget.height, child: canvas);
    }

    if (!widget.showToolbar) return canvas;

    final toolbar = _BoardToolbar(
      items: widget.toolbarItems ?? _kDefaultTools,
      activeTool: _activeTool,
      fillColor: _fillColor,
      strokeColor: _strokeColor,
      brushWidth: _brushWidth,
      style: widget.toolbarStyle,
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
        return Column(children: [toolbar, Expanded(child: canvas)]);
      case FabricToolbarPosition.bottom:
        return Column(children: [Expanded(child: canvas), toolbar]);
      case FabricToolbarPosition.left:
        return Row(children: [toolbar, Expanded(child: canvas)]);
      case FabricToolbarPosition.right:
        return Row(children: [Expanded(child: canvas), toolbar]);
      case FabricToolbarPosition.floating:
        return Stack(
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
          ? VerticalDivider(width: 16, thickness: 1, indent: 6, endIndent: 6,
              color: cs.outlineVariant)
          : Divider(height: 16, thickness: 1, indent: 6, endIndent: 6,
              color: cs.outlineVariant);
    }

    if (tool == FabricTool.colorPicker) {
      return _ColorSwatchButton(
        color: fillColor,
        tooltip: 'Fill color',
        onTap: () => _showColorPicker(context, fillColor, 'Fill Color', onFillColorChanged),
      );
    }

    if (tool == FabricTool.strokeColor) {
      return _ColorSwatchButton(
        color: strokeColor,
        tooltip: 'Stroke color',
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
        onTap: () => _showWidthPicker(context),
      );
    }

    final isMode = _toolToMode(tool) != null;
    final isActive = isMode && activeTool == tool;
    final selectedBg = style.selectedColor ?? cs.primaryContainer;
    final iconClr = isActive
        ? (style.selectedIconColor ?? cs.onPrimaryContainer)
        : (style.iconColor ?? cs.onSurface);

    final icon = _toolIcon(tool);
    Widget iconWidget = Icon(icon, size: style.iconSize, color: iconClr);

    // FlipV uses a rotated flip icon
    if (tool == FabricTool.flipV) {
      iconWidget = Transform.rotate(
        angle: 1.5708, // 90°
        child: iconWidget,
      );
    }

    return Tooltip(
      message: _toolLabel(tool),
      child: InkWell(
        onTap: () => onToolTap(tool),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: isActive
              ? BoxDecoration(color: selectedBg, borderRadius: BorderRadius.circular(8))
              : null,
          alignment: Alignment.center,
          child: iconWidget,
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

  // ── Lookup tables ──────────────────────────────────────────────────────────

  static FabricInteractionMode? _toolToMode(FabricTool tool) {
    switch (tool) {
      case FabricTool.select: return FabricInteractionMode.select;
      case FabricTool.pencil: return FabricInteractionMode.pencil;
      case FabricTool.eraser: return FabricInteractionMode.eraser;
      case FabricTool.spray: return FabricInteractionMode.spray;
      case FabricTool.drawRect: return FabricInteractionMode.drawRect;
      case FabricTool.drawCircle: return FabricInteractionMode.drawCircle;
      case FabricTool.drawEllipse: return FabricInteractionMode.drawEllipse;
      case FabricTool.drawTriangle: return FabricInteractionMode.drawTriangle;
      case FabricTool.drawLine: return FabricInteractionMode.drawLine;
      case FabricTool.addText: return FabricInteractionMode.addText;
      case FabricTool.addTextBox: return FabricInteractionMode.addTextBox;
      default: return null;
    }
  }

  static String _toolLabel(FabricTool tool) {
    switch (tool) {
      case FabricTool.select: return 'Select';
      case FabricTool.pencil: return 'Pencil';
      case FabricTool.eraser: return 'Eraser';
      case FabricTool.spray: return 'Spray';
      case FabricTool.drawRect: return 'Rectangle';
      case FabricTool.drawCircle: return 'Circle';
      case FabricTool.drawEllipse: return 'Ellipse';
      case FabricTool.drawTriangle: return 'Triangle';
      case FabricTool.drawLine: return 'Line';
      case FabricTool.addText: return 'Text';
      case FabricTool.addTextBox: return 'Text Box';
      case FabricTool.undo: return 'Undo';
      case FabricTool.redo: return 'Redo';
      case FabricTool.delete: return 'Delete';
      case FabricTool.clear: return 'Clear All';
      case FabricTool.duplicate: return 'Duplicate';
      case FabricTool.selectAll: return 'Select All';
      case FabricTool.group: return 'Group';
      case FabricTool.ungroup: return 'Ungroup';
      case FabricTool.bringToFront: return 'Bring to Front';
      case FabricTool.sendToBack: return 'Send to Back';
      case FabricTool.bringForward: return 'Bring Forward';
      case FabricTool.sendBackward: return 'Send Backward';
      case FabricTool.flipH: return 'Flip Horizontal';
      case FabricTool.flipV: return 'Flip Vertical';
      case FabricTool.zoomIn: return 'Zoom In';
      case FabricTool.zoomOut: return 'Zoom Out';
      case FabricTool.resetView: return 'Reset View';
      case FabricTool.colorPicker: return 'Fill Color';
      case FabricTool.strokeColor: return 'Stroke Color';
      case FabricTool.brushWidth: return 'Brush Width';
      case FabricTool.divider: return '';
    }
  }

  static IconData _toolIcon(FabricTool tool) {
    switch (tool) {
      case FabricTool.select: return Icons.near_me_outlined;
      case FabricTool.pencil: return Icons.edit_outlined;
      case FabricTool.eraser: return Icons.auto_fix_normal_outlined;
      case FabricTool.spray: return Icons.blur_on_outlined;
      case FabricTool.drawRect: return Icons.crop_square_outlined;
      case FabricTool.drawCircle: return Icons.circle_outlined;
      case FabricTool.drawEllipse: return Icons.radio_button_unchecked;
      case FabricTool.drawTriangle: return Icons.change_history_outlined;
      case FabricTool.drawLine: return Icons.horizontal_rule;
      case FabricTool.addText: return Icons.text_fields;
      case FabricTool.addTextBox: return Icons.wrap_text;
      case FabricTool.undo: return Icons.undo;
      case FabricTool.redo: return Icons.redo;
      case FabricTool.delete: return Icons.delete_outline;
      case FabricTool.clear: return Icons.delete_forever_outlined;
      case FabricTool.duplicate: return Icons.file_copy_outlined;
      case FabricTool.selectAll: return Icons.select_all;
      case FabricTool.group: return Icons.folder_outlined;
      case FabricTool.ungroup: return Icons.folder_open_outlined;
      case FabricTool.bringToFront: return Icons.flip_to_front;
      case FabricTool.sendToBack: return Icons.flip_to_back;
      case FabricTool.bringForward: return Icons.keyboard_arrow_up;
      case FabricTool.sendBackward: return Icons.keyboard_arrow_down;
      case FabricTool.flipH: return Icons.flip;
      case FabricTool.flipV: return Icons.flip; // rotated in build
      case FabricTool.zoomIn: return Icons.zoom_in;
      case FabricTool.zoomOut: return Icons.zoom_out;
      case FabricTool.resetView: return Icons.fit_screen;
      case FabricTool.colorPicker: return Icons.palette_outlined;
      case FabricTool.strokeColor: return Icons.border_color_outlined;
      case FabricTool.brushWidth: return Icons.line_weight;
      case FabricTool.divider: return Icons.more_vert;
    }
  }
}

// ── Color swatch button ───────────────────────────────────────────────────────

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.isOutline = false,
  });

  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool isOutline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isOutline ? null : color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isOutline ? color : cs.outline,
                  width: isOutline ? 3 : 1.5,
                ),
              ),
            ),
          ),
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
  });

  final double width;
  final double iconSize;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Brush Width (${width.toStringAsFixed(0)})',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Icon(Icons.line_weight, size: iconSize, color: iconColor),
          ),
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
    Color(0xFF000000), Color(0xFF212121), Color(0xFF424242), Color(0xFF757575),
    Color(0xFF9E9E9E), Color(0xFFBDBDBD), Color(0xFFE0E0E0), Color(0xFFFFFFFF),
    Color(0xFFB71C1C), Color(0xFFF44336), Color(0xFFE91E63), Color(0xFF9C27B0),
    Color(0xFF3F51B5), Color(0xFF2196F3), Color(0xFF03A9F4), Color(0xFF00BCD4),
    Color(0xFF009688), Color(0xFF4CAF50), Color(0xFF8BC34A), Color(0xFFCDDC39),
    Color(0xFFFFEB3B), Color(0xFFFFC107), Color(0xFFFF9800), Color(0xFFFF5722),
    Color(0xFF795548), Color(0xFF607D8B), Color(0xFF00BFA5), Color(0xFFAA00FF),
    Color(0xFF2962FF), Color(0xFF00C853), Color(0xFFFFD600), Color(0xFFDD2C00),
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
            // Preview strip
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              decoration: BoxDecoration(
                color: _selected,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Transparency option
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
                    child: const Icon(Icons.block, size: 18, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Transparent',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            // Color grid
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
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: c.computeLuminance() > 0.5
                                ? Colors.black87
                                : Colors.white,
                          )
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
