import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../objects/fabric_object.dart';
import '../utils/fabric_object_factory.dart';
import '../canvas/fabric_controller.dart';

const int _kSchemaVersion = 1;

abstract final class FabricSerializer {
  // ── Canvas export / import ─────────────────────────────────────────────────

  static String exportCanvas(FabricController controller) {
    final payload = <String, dynamic>{
      'version': _kSchemaVersion,
      'background': controller.backgroundColor.toARGB32(),
      'zoom': controller.zoom,
      'viewportX': controller.viewportTransform.dx,
      'viewportY': controller.viewportTransform.dy,
      'objects': controller.objects.map((o) => o.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static bool importCanvas(
    String jsonString,
    FabricController controller, {
    bool restoreViewport = true,
  }) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = data['version'] as int? ?? 0;
      if (version > _kSchemaVersion) {
        debugPrint(
            '[FabricSerializer] schema version $version > supported $_kSchemaVersion');
        return false;
      }
      final compact = jsonEncode({
        'objects': data['objects'],
        'background': data['background'],
      });
      controller.loadFromJson(compact);
      if (restoreViewport) {
        if (data['zoom'] != null) {
          controller.zoomTo((data['zoom'] as num).toDouble());
        }
        if (data['viewportX'] != null && data['viewportY'] != null) {
          final savedOffset = Offset(
            (data['viewportX'] as num).toDouble(),
            (data['viewportY'] as num).toDouble(),
          );
          controller.panBy(savedOffset - controller.viewportTransform);
        }
      }
      return true;
    } catch (e) {
      debugPrint('[FabricSerializer] importCanvas error: $e');
      return false;
    }
  }

  // ── Per-object helpers ─────────────────────────────────────────────────────

  static String objectToJson(FabricObject obj) => jsonEncode(obj.toJson());

  static FabricObject? objectFromJson(String jsonString) {
    try {
      return FabricObjectFactory.deserialize(
          jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[FabricSerializer] objectFromJson error: $e');
      return null;
    }
  }

  static List<FabricObject> objectListFromJson(String jsonString) {
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(FabricObjectFactory.deserialize)
          .whereType<FabricObject>()
          .toList();
    } catch (e) {
      debugPrint('[FabricSerializer] objectListFromJson error: $e');
      return [];
    }
  }

  static String objectListToJson(List<FabricObject> objects) =>
      jsonEncode(objects.map((o) => o.toJson()).toList());

  /// Deep-clone [obj] with a new id, optionally nudged by [nudge].
  static FabricObject? clone(FabricObject obj,
      {Offset nudge = const Offset(10, 10)}) {
    try {
      final map = Map<String, dynamic>.from(obj.toJson())
        ..remove('id')
        ..['left'] = ((obj.toJson()['left'] as num?)?.toDouble() ?? 0) + nudge.dx
        ..['top'] = ((obj.toJson()['top'] as num?)?.toDouble() ?? 0) + nudge.dy;
      return FabricObjectFactory.deserialize(map);
    } catch (e) {
      debugPrint('[FabricSerializer] clone error: $e');
      return null;
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  static List<String> validate(String jsonString) {
    final warnings = <String>[];
    try {
      final data = jsonDecode(jsonString);
      if (data is! Map<String, dynamic>) {
        warnings.add('Root element is not an object.');
        return warnings;
      }
      if (!data.containsKey('objects')) {
        warnings.add('Missing "objects" key.');
      } else {
        final objs = data['objects'];
        if (objs is! List) {
          warnings.add('"objects" is not an array.');
        } else {
          for (int i = 0; i < objs.length; i++) {
            final obj = objs[i];
            if (obj is! Map) {
              warnings.add('objects[$i] is not an object.');
            } else if (!obj.containsKey('type')) {
              warnings.add('objects[$i] is missing "type".');
            }
          }
        }
      }
      final version = data['version'];
      if (version is int && version > _kSchemaVersion) {
        warnings.add(
            'Schema version $version is newer than supported $_kSchemaVersion.');
      }
    } catch (e) {
      warnings.add('Invalid JSON: $e');
    }
    return warnings;
  }

  // ── SVG export ─────────────────────────────────────────────────────────────

  static String exportSvg(FabricController controller,
      {double width = 800, double height = 600}) {
    final buf = StringBuffer()
      ..writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height"'
          ' viewBox="0 0 $width $height">');
    buf.writeln(
        '  <rect width="100%" height="100%" fill="${_hex(controller.backgroundColor)}"/>');
    for (final obj in controller.objects) {
      if (!obj.visible) continue;
      _writeSvgObject(buf, obj.toJson(), '  ');
    }
    buf.writeln('</svg>');
    return buf.toString();
  }

  static void _writeSvgObject(
      StringBuffer buf, Map<String, dynamic> json, String indent) {
    final type = json['type'] as String?;
    final xf = _svgTransform(json);
    final fs = _svgFillStroke(json);

    switch (type) {
      case 'rect':
        buf.writeln('$indent<rect'
            ' x="${_n(json['left'])}" y="${_n(json['top'])}"'
            ' width="${_n(json['width'])}" height="${_n(json['height'])}"'
            ' rx="${_n(json['rx'])}" ry="${_n(json['ry'])}"'
            '$fs$xf/>');
        break;

      case 'circle':
        final r = _d(json['radius'], 50);
        final cx = _d(json['left'], 0) + r;
        final cy = _d(json['top'], 0) + r;
        buf.writeln('$indent<circle cx="${_n(cx)}" cy="${_n(cy)}" r="${_n(r)}"$fs$xf/>');
        break;

      case 'ellipse':
        final rx = _d(json['rx'], 60);
        final ry = _d(json['ry'], 40);
        final cx = _d(json['left'], 0) + rx;
        final cy = _d(json['top'], 0) + ry;
        buf.writeln(
            '$indent<ellipse cx="${_n(cx)}" cy="${_n(cy)}" rx="${_n(rx)}" ry="${_n(ry)}"$fs$xf/>');
        break;

      case 'line':
        buf.writeln('$indent<line'
            ' x1="${_n(json['x1'])}" y1="${_n(json['y1'])}"'
            ' x2="${_n(json['x2'])}" y2="${_n(json['y2'])}"$fs$xf/>');
        break;

      case 'triangle':
        // Isosceles triangle, same as FabricTriangle.render logic
        final l = _d(json['left'], 0);
        final t = _d(json['top'], 0);
        final w = _d(json['width'], 100) * _d(json['scaleX'], 1);
        final h = _d(json['height'], 100) * _d(json['scaleY'], 1);
        final pts = '${_n(l + w / 2)},${_n(t)} '
            '${_n(l + w)},${_n(t + h)} '
            '${_n(l)},${_n(t + h)}';
        buf.writeln('$indent<polygon points="$pts"$fs/>');
        break;

      case 'polygon':
        final points = (json['points'] as List<dynamic>?)
                ?.map((p) => '${_n(p['x'])},${_n(p['y'])}')
                .join(' ') ??
            '';
        buf.writeln('$indent<polygon points="$points"$fs$xf/>');
        break;

      case 'polyline':
        final points = (json['points'] as List<dynamic>?)
                ?.map((p) => '${_n(p['x'])},${_n(p['y'])}')
                .join(' ') ??
            '';
        buf.writeln('$indent<polyline points="$points"$fs$xf/>');
        break;

      case 'text':
      case 'itext':
      case 'textbox':
        final text = (json['text'] as String? ?? '')
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;');
        final fs2 = _d(json['fontSize'], 24);
        final fill = _hexFromValue(json['fill'] as int?);
        final op = _svgOpacity(json);
        buf.writeln('$indent<text'
            ' x="${_n(json['left'])}"'
            ' y="${_n(_d(json['top'], 0) + fs2)}"'
            ' font-size="${_n(fs2)}" fill="$fill"$op$xf>$text</text>');
        break;

      case 'path':
        final d = json['path'] as String? ?? '';
        buf.writeln('$indent<path d="$d"$fs$xf/>');
        break;

      case 'group':
        final l = _d(json['left'], 0);
        final t = _d(json['top'], 0);
        buf.writeln('$indent<g transform="translate(${_n(l)},${_n(t)})"${_svgOpacity(json)}>');
        for (final child
            in (json['objects'] as List<dynamic>? ?? [])) {
          _writeSvgObject(buf, child as Map<String, dynamic>, '$indent  ');
        }
        buf.writeln('$indent</g>');
        break;

      default:
        break;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static double _d(dynamic v, double fallback) =>
      v is num ? v.toDouble() : fallback;

  static String _n(dynamic v) =>
      v is num ? v.toDouble().toStringAsFixed(2) : '0.00';

  static String _hex(Color c) {
    final v = c.toARGB32();
    final r = (v >> 16) & 0xFF;
    final g = (v >> 8) & 0xFF;
    final b = v & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  static String _hexFromValue(int? value) {
    if (value == null) return 'none';
    final alpha = (value >> 24) & 0xFF;
    return alpha == 0 ? 'none' : _hex(Color(value));
  }

  static String _svgFillStroke(Map<String, dynamic> json) {
    final fill = _hexFromValue(json['fill'] as int?);
    final stroke = _hexFromValue(json['stroke'] as int?);
    final sw = _d(json['strokeWidth'], 1.0);
    return ' fill="$fill" stroke="$stroke" stroke-width="${_n(sw)}"${_svgOpacity(json)}';
  }

  static String _svgOpacity(Map<String, dynamic> json) {
    final op = _d(json['opacity'], 1.0);
    return op < 1.0 ? ' opacity="${_n(op)}"' : '';
  }

  static String _svgTransform(Map<String, dynamic> json) {
    final angle = _d(json['angle'], 0.0);
    final sx = _d(json['scaleX'], 1.0);
    final sy = _d(json['scaleY'], 1.0);
    final flipX = json['flipX'] as bool? ?? false;
    final flipY = json['flipY'] as bool? ?? false;
    final skewX = _d(json['skewX'], 0.0);
    final skewY = _d(json['skewY'], 0.0);

    if (angle == 0 && sx == 1.0 && sy == 1.0 && !flipX && !flipY &&
        skewX == 0 && skewY == 0) {
      return '';
    }

    final l = _d(json['left'], 0.0);
    final t = _d(json['top'], 0.0);
    final w = _d(json['width'], 0.0);
    final h = _d(json['height'], 0.0);
    final cx = l + w * sx / 2;
    final cy = t + h * sy / 2;

    final parts = <String>[];
    if (angle != 0) parts.add('rotate(${_n(angle)} ${_n(cx)} ${_n(cy)})');
    if (sx != 1.0 || sy != 1.0) parts.add('scale(${_n(sx)} ${_n(sy)})');
    if (flipX || flipY) {
      parts.add('scale(${flipX ? -1 : 1} ${flipY ? -1 : 1})');
    }
    if (skewX != 0) {
      parts.add('skewX(${_n(skewX * 180 / math.pi)})');
    }
    if (skewY != 0) {
      parts.add('skewY(${_n(skewY * 180 / math.pi)})');
    }
    return parts.isEmpty ? '' : ' transform="${parts.join(' ')}"';
  }
}
