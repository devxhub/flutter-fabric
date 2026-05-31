import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'fabric_object.dart';

/// Fit/alignment modes for [FabricImage].
enum FabricImageFit {
  fill,
  contain,
  cover,
  none,
}

/// A canvas object that renders a [ui.Image].
class FabricImage extends FabricObject {
  FabricImage({
    required ui.Image image,
    super.left,
    super.top,
    double? width,
    double? height,
    super.angle,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.fill = Colors.transparent,
    super.stroke = Colors.transparent,
    super.strokeWidth,
    super.selectable,
    super.visible,
    super.id,
    super.flipX,
    super.flipY,
    FabricImageFit fit = FabricImageFit.fill,
    Rect? cropRect,
    String? src,
  })  : _image = image,
        _fit = fit,
        _cropRect = cropRect,
        _src = src,
        super(
          width: width ?? image.width.toDouble(),
          height: height ?? image.height.toDouble(),
        );

  ui.Image _image;
  FabricImageFit _fit;
  Rect? _cropRect;
  String? _src;

  ui.Image get image => _image;
  set image(ui.Image v) {
    _image = v;
    notifyListeners();
  }

  FabricImageFit get fit => _fit;
  set fit(FabricImageFit v) {
    _fit = v;
    notifyListeners();
  }

  // flipX / flipY are inherited from FabricObject — no overrides needed.

  Rect? get cropRect => _cropRect;
  set cropRect(Rect? v) {
    _cropRect = v;
    notifyListeners();
  }

  String? get src => _src;
  set src(String? v) {
    _src = v;
    notifyListeners();
  }

  @override
  String get type => 'image';

  @override
  void render(Canvas canvas, double w, double h) {
    final srcRect = _cropRect ??
        Rect.fromLTWH(0, 0, _image.width.toDouble(), _image.height.toDouble());

    Rect dst;
    switch (_fit) {
      case FabricImageFit.fill:
        dst = Rect.fromLTWH(0, 0, w, h);
        break;
      case FabricImageFit.contain:
        final scale = (w / srcRect.width).clamp(0.0, h / srcRect.height);
        final fw = srcRect.width * scale;
        final fh = srcRect.height * scale;
        dst = Rect.fromLTWH((w - fw) / 2, (h - fh) / 2, fw, fh);
        break;
      case FabricImageFit.cover:
        final scale =
            (w / srcRect.width).clamp(h / srcRect.height, double.infinity);
        final fw = srcRect.width * scale;
        final fh = srcRect.height * scale;
        dst = Rect.fromLTWH((w - fw) / 2, (h - fh) / 2, fw, fh);
        break;
      case FabricImageFit.none:
        dst = Rect.fromLTWH(0, 0, srcRect.width, srcRect.height);
        break;
    }

    // flipX / flipY are handled by FabricObject.paint via _applySkewFlip,
    // so no additional transform is needed here.
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
    canvas.drawImageRect(_image, srcRect, dst, Paint());

    if (stroke != Colors.transparent && strokeWidth > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), strokePaint);
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'src': _src,
        'fit': _fit.index,
        'cropRect': _cropRect == null
            ? null
            : {
                'left': _cropRect!.left,
                'top': _cropRect!.top,
                'width': _cropRect!.width,
                'height': _cropRect!.height,
              },
      };

  factory FabricImage.fromJson(Map<String, dynamic> json,
      {Future<ui.Image> Function(String)? imageResolver}) {
    final width = (json['width'] as num?)?.toDouble() ?? 100;
    final height = (json['height'] as num?)?.toDouble() ?? 100;
    final o = FabricImage(
      image: _placeholder(width, height),
      left: (json['left'] as num?)?.toDouble() ?? 0.0,
      top: (json['top'] as num?)?.toDouble() ?? 0.0,
      width: width,
      height: height,
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1.0,
      scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      flipX: json['flipX'] as bool? ?? false,
      flipY: json['flipY'] as bool? ?? false,
      fit: FabricImageFit.values[(json['fit'] as int?) ?? 0],
      src: json['src'] as String?,
    );
    o.applyJson(json);
    return o;
  }

  static ui.Image _placeholder(double width, double height) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.grey);
    return recorder.endRecording().toImageSync(width.toInt(), height.toInt());
  }
}
