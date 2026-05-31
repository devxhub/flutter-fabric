import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fabric_object.dart';

class FabricGroup extends FabricObject {
  FabricGroup({
    required List<FabricObject> objects,
    super.left,
    super.top,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.selectable,
    super.visible,
    super.id,
  })  : _objects = List.of(objects),
        super(
          fill: Colors.transparent,
          stroke: Colors.transparent,
          width: _computeWidth(objects),
          height: _computeHeight(objects),
        );

  final List<FabricObject> _objects;
  List<FabricObject> get objects => List.unmodifiable(_objects);

  static double _computeWidth(List<FabricObject> objs) {
    if (objs.isEmpty) return 0;
    final maxR = objs.map((o) => o.left + o.scaledWidth).reduce(math.max);
    final minL = objs.map((o) => o.left).reduce(math.min);
    return maxR - minL;
  }

  static double _computeHeight(List<FabricObject> objs) {
    if (objs.isEmpty) return 0;
    final maxB = objs.map((o) => o.top + o.scaledHeight).reduce(math.max);
    final minT = objs.map((o) => o.top).reduce(math.min);
    return maxB - minT;
  }

  void add(FabricObject obj) {
    _objects.add(obj);
    notifyListeners();
  }

  void remove(FabricObject obj) {
    _objects.remove(obj);
    notifyListeners();
  }

  @override
  String get type => 'group';

  @override
  void render(Canvas canvas, double w, double h) {
    final minX =
        _objects.isEmpty ? 0.0 : _objects.map((o) => o.left).reduce(math.min);
    final minY =
        _objects.isEmpty ? 0.0 : _objects.map((o) => o.top).reduce(math.min);

    for (final obj in _objects) {
      if (!obj.visible) continue;
      canvas.save();

      // Position the child relative to the group origin WITHOUT double-applying
      // the child's own left/top (which paint() would also apply).
      final relLeft = obj.left - minX;
      final relTop = obj.top - minY;
      final cx = relLeft + obj.scaledWidth / 2;
      final cy = relTop + obj.scaledHeight / 2;

      canvas.translate(cx, cy);
      canvas.rotate(obj.angle * math.pi / 180);
      if (obj.flipX || obj.flipY) {
        canvas.scale(obj.flipX ? -1.0 : 1.0, obj.flipY ? -1.0 : 1.0);
      }
      canvas.translate(-obj.scaledWidth / 2, -obj.scaledHeight / 2);

      canvas.saveLayer(
        Rect.fromLTWH(0, 0, obj.scaledWidth, obj.scaledHeight),
        Paint()
          ..blendMode = obj.blendMode
          ..color = Color.fromARGB((obj.opacity * 255).round(), 255, 255, 255),
      );
      obj.render(canvas, obj.scaledWidth, obj.scaledHeight);
      canvas.restore(); // saveLayer
      canvas.restore(); // translate / rotate
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'objects': _objects.map((o) => o.toJson()).toList(),
      };

  /// Deserialize a group from JSON.
  ///
  /// Pass [childFactory] (e.g. `FabricObjectFactory.deserialize`) to
  /// recursively reconstruct child objects.  Without it, children are empty.
  factory FabricGroup.fromJson(
    Map<String, dynamic> json, {
    FabricObject? Function(Map<String, dynamic>)? childFactory,
  }) {
    final children = childFactory != null
        ? (json['objects'] as List<dynamic>? ?? [])
            .map((c) => childFactory(c as Map<String, dynamic>))
            .whereType<FabricObject>()
            .toList()
        : <FabricObject>[];
    final g = FabricGroup(objects: children, id: json['id'] as String?);
    g.applyJson(json);
    return g;
  }
}
