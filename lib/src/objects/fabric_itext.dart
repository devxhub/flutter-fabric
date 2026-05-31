import 'package:flutter/material.dart';
import 'fabric_text.dart';

class FabricIText extends FabricText {
  FabricIText(
    super.text, {
    super.left,
    super.top,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill,
    super.stroke,
    super.strokeWidth,
    super.selectable,
    super.visible,
    super.id,
    super.fontSize,
    super.fontWeight,
    super.fontStyle,
    super.fontFamily,
    super.textAlign,
    super.lineHeight,
  });

  @override
  String get type => 'itext';

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'type': 'itext'};

  factory FabricIText.fromJson(Map<String, dynamic> json) {
    final o = FabricIText(
      json['text'] as String? ?? '',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24,
      fontWeight: FontWeight.values[(json['fontWeight'] as int?) ?? 3],
      fontStyle: FontStyle.values[(json['fontStyle'] as int?) ?? 0],
      fontFamily: json['fontFamily'] as String? ?? 'sans-serif',
      textAlign: TextAlign.values[(json['textAlign'] as int?) ?? 0],
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.2,
      id: json['id'] as String?,
    );
    o.applyJson(json);
    return o;
  }
}
