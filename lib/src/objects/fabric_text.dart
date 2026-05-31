import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// A non-editable text label on the canvas.
///
/// For interactive text editing, pair with [FabricIText] (coming soon) or
/// use the [FabricController.editText] helper to swap in a Flutter [TextField]
/// overlay when the object is double-tapped.
class FabricText extends FabricObject {
  FabricText(
    this._text, {
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
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle fontStyle = FontStyle.normal,
    String fontFamily = 'sans-serif',
    TextAlign textAlign = TextAlign.left,
    double lineHeight = 1.2,
  })  : _fontSize = fontSize,
        _fontWeight = fontWeight,
        _fontStyle = fontStyle,
        _fontFamily = fontFamily,
        _textAlign = textAlign,
        _lineHeight = lineHeight,
        super(width: 200, height: fontSize * lineHeight * 2);

  String _text;
  double _fontSize;
  FontWeight _fontWeight;
  FontStyle _fontStyle;
  String _fontFamily;
  TextAlign _textAlign;
  double _lineHeight;

  String get text => _text;
  set text(String v) {
    _text = v;
    notifyListeners();
  }

  double get fontSize => _fontSize;
  FontWeight get fontWeight => _fontWeight;
  FontStyle get fontStyle => _fontStyle;
  String get fontFamily => _fontFamily;
  TextAlign get textAlign => _textAlign;

  set fontSize(double v) {
    _fontSize = v;
    notifyListeners();
  }

  set fontWeight(FontWeight v) {
    _fontWeight = v;
    notifyListeners();
  }

  set fontStyle(FontStyle v) {
    _fontStyle = v;
    notifyListeners();
  }

  set fontFamily(String v) {
    _fontFamily = v;
    notifyListeners();
  }

  set textAlign(TextAlign v) {
    _textAlign = v;
    notifyListeners();
  }

  @override
  String get type => 'text';

  // Not private so subclasses (FabricTextBox, FabricIText) can reuse.
  TextPainter buildPainter(double w) {
    final style = TextStyle(
      color: fill,
      fontSize: _fontSize,
      fontWeight: _fontWeight,
      fontStyle: _fontStyle,
      fontFamily: _fontFamily,
      height: _lineHeight,
    );
    return TextPainter(
      text: TextSpan(text: _text, style: style),
      textAlign: _textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
  }

  @override
  void render(Canvas canvas, double w, double h) {
    final painter = buildPainter(w);
    painter.paint(canvas, Offset.zero);
  }

  /// Auto-size the bounding box to the rendered text.
  void autoSize(double maxWidth) {
    final painter = buildPainter(maxWidth);
    set(width: painter.width, height: painter.height);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'text': _text,
        'fontSize': _fontSize,
        'fontWeight': _fontWeight.value,
        'fontStyle': _fontStyle.index,
        'fontFamily': _fontFamily,
        'textAlign': _textAlign.index,
        'lineHeight': _lineHeight,
      };

  factory FabricText.fromJson(Map<String, dynamic> json) {
    final o = FabricText(
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
