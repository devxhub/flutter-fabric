import 'package:flutter/material.dart';
import 'fabric_text.dart';

/// A text object with a **fixed bounding width** that word-wraps its content.
///
/// Unlike [FabricText] (which auto-sizes width to content), [FabricTextBox]
/// keeps a user-defined width and grows only vertically as text wraps.
/// Double-tap to edit inline.
class FabricTextBox extends FabricText {
  FabricTextBox(
    super.text, {
    super.left,
    super.top,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.black,
    super.stroke = Colors.transparent,
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
    double fixedWidth = 200,
  }) {
    // FabricText hard-codes width: 200 in its super call.
    // Override to honour the caller's fixedWidth without modifying FabricText's API.
    set(width: fixedWidth);
  }

  @override
  String get type => 'textbox';

  /// Adjusts the object height to exactly fit the wrapped text at current width.
  void fitHeight() {
    final painter = buildPainter(scaledWidth);
    set(height: painter.height);
  }

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'type': 'textbox'};

  factory FabricTextBox.fromJson(Map<String, dynamic> json) {
    final o = FabricTextBox(
      json['text'] as String? ?? '',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24,
      fontWeight: FontWeight.values[(json['fontWeight'] as int?) ?? 3],
      fontStyle: FontStyle.values[(json['fontStyle'] as int?) ?? 0],
      fontFamily: json['fontFamily'] as String? ?? 'sans-serif',
      textAlign: TextAlign.values[(json['textAlign'] as int?) ?? 0],
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.2,
      fixedWidth: (json['width'] as num?)?.toDouble() ?? 200,
      id: json['id'] as String?,
    );
    o.applyJson(json);
    return o;
  }
}
