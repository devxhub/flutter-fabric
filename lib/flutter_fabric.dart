/// Flutter Fabric — an interactive canvas library inspired by Fabric.js.
///
/// Provides a [FabricCanvas] widget backed by a [FabricController] that lets
/// you place, select, move, scale, rotate, and style canvas objects at runtime.
///
/// ## Quick start
///
/// ```dart
/// final controller = FabricController();
///
/// controller.add(FabricRect(
///   left: 50, top: 50, width: 120, height: 80,
///   fill: Colors.blue,
/// ));
///
/// FabricCanvas(controller: controller)
/// ```
library flutter_fabric;

// ─── Canvas ────────────────────────────────────────────────────────────────
export 'src/canvas/fabric_canvas.dart';
export 'src/canvas/fabric_controller.dart';

// ─── Objects ───────────────────────────────────────────────────────────────
export 'src/objects/fabric_object.dart';
export 'src/objects/fabric_rect.dart';
export 'src/objects/fabric_circle.dart';
export 'src/objects/fabric_ellipse.dart';
export 'src/objects/fabric_line.dart';
export 'src/objects/fabric_triangle.dart';
export 'src/objects/fabric_polygon.dart';
export 'src/objects/fabric_polyline.dart';
export 'src/objects/fabric_text.dart';
export 'src/objects/fabric_itext.dart';
export 'src/objects/fabric_textbox.dart';
export 'src/objects/fabric_path.dart';
export 'src/objects/fabric_group.dart';
export 'src/objects/fabric_image.dart';

// ─── Brushes ──────────────────────────────────────────────────────────────
export 'src/brushes/base_brush.dart';
export 'src/brushes/pencil_brush.dart';
export 'src/brushes/spray_brush.dart';
export 'src/brushes/pattern_brush.dart';
export 'src/brushes/eraser_brush.dart';

// ─── High-level widget ───────────────────────────────────────────────────
export 'src/widgets/fabric_board.dart';

// ─── Controls & Overlays ─────────────────────────────────────────────────
export 'src/controls/selection_overlay.dart';
export 'src/widgets/text_editing_overlay.dart';
export 'src/widgets/object_edit_menu.dart';

// ─── Utilities ───────────────────────────────────────────────────────────
export 'src/utils/fabric_math.dart';
export 'src/utils/fabric_serializer.dart';
export 'src/utils/fabric_object_factory.dart';
