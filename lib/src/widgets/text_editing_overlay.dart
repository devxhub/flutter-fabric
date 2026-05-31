import 'package:flutter/material.dart';
import '../canvas/fabric_controller.dart';
import '../objects/fabric_itext.dart';
import '../utils/fabric_math.dart';

class TextEditingOverlay extends StatefulWidget {
  const TextEditingOverlay({
    required this.controller,
    required this.textObject,
    required this.onDismiss,
    super.key,
  });

  final FabricController controller;
  final FabricIText textObject;
  final VoidCallback onDismiss;

  @override
  State<TextEditingOverlay> createState() => _TextEditingOverlayState();
}

class _TextEditingOverlayState extends State<TextEditingOverlay> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.textObject.text);
    _focusNode = FocusNode()..requestFocus();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenPos = FabricMath.canvasToScreen(
      Offset(widget.textObject.left, widget.textObject.top),
      zoom: widget.controller.zoom,
      viewportOffset: widget.controller.viewportTransform,
    );
    final scaledWidth = widget.textObject.scaledWidth * widget.controller.zoom;
    final scaledHeight =
        widget.textObject.scaledHeight * widget.controller.zoom;
    return Positioned(
      left: screenPos.dx,
      top: screenPos.dy,
      width: scaledWidth,
      height: scaledHeight,
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue, width: 2)),
          contentPadding: const EdgeInsets.all(8),
        ),
        style: TextStyle(
          fontSize: widget.textObject.fontSize * widget.controller.zoom,
          fontWeight: widget.textObject.fontWeight,
          fontStyle: widget.textObject.fontStyle,
          fontFamily: widget.textObject.fontFamily,
          color: widget.textObject.fill,
        ),
        onSubmitted: (value) {
          widget.textObject.text = value;
          widget.controller.requestRepaint();
          widget.onDismiss();
        },
      ),
    );
  }
}
