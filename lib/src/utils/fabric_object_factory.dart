import '../objects/fabric_object.dart';
import '../objects/fabric_rect.dart';
import '../objects/fabric_circle.dart';
import '../objects/fabric_ellipse.dart';
import '../objects/fabric_line.dart';
import '../objects/fabric_triangle.dart';
import '../objects/fabric_polygon.dart';
import '../objects/fabric_polyline.dart';
import '../objects/fabric_text.dart';
import '../objects/fabric_itext.dart';
import '../objects/fabric_textbox.dart';
import '../objects/fabric_path.dart';
import '../objects/fabric_group.dart';
import '../objects/fabric_image.dart';

/// Central deserializer shared by [FabricController], [FabricSerializer], and
/// [FabricGroup.fromJson].  Avoids the duplicated switch-statement that previously
/// lived in both the controller and the serializer.
abstract final class FabricObjectFactory {
  static FabricObject? deserialize(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'rect':
        return FabricRect.fromJson(json);
      case 'circle':
        return FabricCircle.fromJson(json);
      case 'ellipse':
        return FabricEllipse.fromJson(json);
      case 'line':
        return FabricLine.fromJson(json);
      case 'triangle':
        return FabricTriangle.fromJson(json);
      case 'polygon':
        return FabricPolygon.fromJson(json);
      case 'polyline':
        return FabricPolyline.fromJson(json);
      case 'text':
        return FabricText.fromJson(json);
      case 'itext':
        return FabricIText.fromJson(json);
      case 'textbox':
        return FabricTextBox.fromJson(json);
      case 'path':
        return FabricPath.fromJson(json);
      case 'group':
        return FabricGroup.fromJson(json, childFactory: deserialize);
      case 'image':
        return FabricImage.fromJson(json);
      default:
        return null;
    }
  }
}
