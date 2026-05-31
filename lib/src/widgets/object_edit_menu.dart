import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../canvas/fabric_controller.dart';
import '../objects/fabric_object.dart';
import '../objects/fabric_text.dart';

/// A rich bottom-sheet editor that adapts its style controls to the object type.
///
/// For text objects: content, font size, bold/italic, text align, color.
/// For shapes: fill color, stroke color, stroke width.
/// For all objects: opacity, width/height, and arrangement actions.
class ObjectEditMenu extends StatefulWidget {
  const ObjectEditMenu({
    super.key,
    required this.controller,
    required this.object,
    required this.onDelete,
    required this.onDuplicate,
    required this.onBringToFront,
    required this.onSendToBack,
    required this.onBringForward,
    required this.onSendBackward,
    required this.onLockMovement,
    required this.onUnlockMovement,
    required this.onToggleVisible,
  });

  final FabricController controller;
  final FabricObject object;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback onBringForward;
  final VoidCallback onSendBackward;
  final VoidCallback onLockMovement;
  final VoidCallback onUnlockMovement;
  final VoidCallback onToggleVisible;

  @override
  State<ObjectEditMenu> createState() => _ObjectEditMenuState();
}

class _ObjectEditMenuState extends State<ObjectEditMenu> {
  late TextEditingController? _textContentCtrl;
  late TextEditingController _fontSizeCtrl;
  late TextEditingController _widthCtrl;
  late TextEditingController _heightCtrl;

  late FontWeight _fontWeight;
  late FontStyle _fontStyle;
  late TextAlign _textAlign;
  late Color _fillColor;
  late Color _strokeColor;
  late double _strokeWidth;
  late double _opacity;

  bool get _isText => widget.object is FabricText;
  FabricText? get _asText => _isText ? widget.object as FabricText : null;

  static const _kColors = [
    Color(0xFF000000), Color(0xFFFFFFFF),
    Color(0xFFB71C1C), Color(0xFFF44336), Color(0xFFE91E63),
    Color(0xFF9C27B0), Color(0xFF3F51B5), Color(0xFF2196F3),
    Color(0xFF03A9F4), Color(0xFF009688), Color(0xFF4CAF50),
    Color(0xFFCDDC39), Color(0xFFFFEB3B), Color(0xFFFFC107),
    Color(0xFFFF9800), Color(0xFF795548), Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    final obj = widget.object;
    _fillColor = obj.fill;
    _strokeColor = obj.stroke;
    _strokeWidth = obj.strokeWidth;
    _opacity = obj.opacity;

    _widthCtrl = TextEditingController(
        text: obj.scaledWidth.toStringAsFixed(0));
    _heightCtrl = TextEditingController(
        text: obj.scaledHeight.toStringAsFixed(0));

    if (_isText) {
      final t = _asText!;
      _textContentCtrl = TextEditingController(text: t.text);
      _fontSizeCtrl = TextEditingController(text: t.fontSize.toStringAsFixed(0));
      _fontWeight = t.fontWeight;
      _fontStyle = t.fontStyle;
      _textAlign = t.textAlign;
    } else {
      _textContentCtrl = null;
      _fontSizeCtrl = TextEditingController(text: '24');
      _fontWeight = FontWeight.normal;
      _fontStyle = FontStyle.normal;
      _textAlign = TextAlign.left;
    }
  }

  @override
  void dispose() {
    _textContentCtrl?.dispose();
    _fontSizeCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  String _typeName() {
    switch (widget.object.type) {
      case 'rect': return 'Rectangle';
      case 'circle': return 'Circle';
      case 'ellipse': return 'Ellipse';
      case 'triangle': return 'Triangle';
      case 'line': return 'Line';
      case 'text': return 'Text';
      case 'itext': return 'Text';
      case 'textbox': return 'Text Box';
      case 'path': return 'Drawing';
      case 'group': return 'Group';
      case 'image': return 'Image';
      default: return 'Object';
    }
  }

  IconData _typeIcon() {
    switch (widget.object.type) {
      case 'rect': return Icons.crop_square_outlined;
      case 'circle': return Icons.circle_outlined;
      case 'triangle': return Icons.change_history_outlined;
      case 'line': return Icons.horizontal_rule;
      case 'text':
      case 'itext': return Icons.text_fields;
      case 'textbox': return Icons.wrap_text;
      case 'path': return Icons.gesture;
      case 'group': return Icons.folder_outlined;
      default: return Icons.layers_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
            child: Row(children: [
              Icon(_typeIcon(), color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                _typeName(),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Style properties (scrollable)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isText) ..._textStyleSection(theme, cs),
                  if (!_isText) ..._shapeStyleSection(theme, cs),
                  const SizedBox(height: 14),
                  _opacityRow(theme, cs),
                  const SizedBox(height: 14),
                  _dimensionsRow(theme, cs),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Arrange actions
          _arrangeSection(theme, cs),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Text style section ─────────────────────────────────────────────────────

  List<Widget> _textStyleSection(ThemeData theme, ColorScheme cs) {
    final t = _asText!;
    return [
      _sectionLabel('Content', theme, cs),
      const SizedBox(height: 4),
      TextField(
        controller: _textContentCtrl!,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onChanged: (v) => t.text = v,
      ),
      const SizedBox(height: 12),

      // Font size + bold / italic + align
      Row(children: [
        _sectionLabel('Font Size', theme, cs),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: TextField(
            controller: _fontSizeCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              suffixText: 'px',
            ),
            onChanged: (v) {
              final d = double.tryParse(v);
              if (d != null && d >= 6) {
                setState(() {});
                t.fontSize = d;
              }
            },
          ),
        ),
        const Spacer(),
        // Bold toggle
        _toggleChip(
          child: const Text('B',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          isActive: _fontWeight == FontWeight.bold,
          onTap: () {
            final next = _fontWeight == FontWeight.bold
                ? FontWeight.normal
                : FontWeight.bold;
            setState(() => _fontWeight = next);
            t.fontWeight = next;
          },
          cs: cs,
        ),
        const SizedBox(width: 4),
        // Italic toggle
        _toggleChip(
          child: const Text('I',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14)),
          isActive: _fontStyle == FontStyle.italic,
          onTap: () {
            final next = _fontStyle == FontStyle.italic
                ? FontStyle.normal
                : FontStyle.italic;
            setState(() => _fontStyle = next);
            t.fontStyle = next;
          },
          cs: cs,
        ),
        const SizedBox(width: 6),
        // Text align
        _textAlignRow(cs),
      ]),
      const SizedBox(height: 12),

      // Text color
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _sectionLabel('Color', theme, cs),
        const SizedBox(width: 8),
        Expanded(
          child: _colorSwatches(
            _fillColor,
            _kColors,
            showTransparent: false,
            onPick: (c) {
              setState(() => _fillColor = c);
              widget.object.set(fill: c);
            },
          ),
        ),
      ]),
    ];
  }

  // ── Shape style section ────────────────────────────────────────────────────

  List<Widget> _shapeStyleSection(ThemeData theme, ColorScheme cs) {
    return [
      // Fill color
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 72, child: _sectionLabel('Fill', theme, cs)),
        Expanded(
          child: _colorSwatches(
            _fillColor,
            _kColors,
            showTransparent: true,
            onPick: (c) {
              setState(() => _fillColor = c);
              widget.object.set(fill: c);
            },
          ),
        ),
      ]),
      const SizedBox(height: 10),

      // Stroke color
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 72, child: _sectionLabel('Stroke', theme, cs)),
        Expanded(
          child: _colorSwatches(
            _strokeColor,
            _kColors,
            showTransparent: true,
            onPick: (c) {
              setState(() => _strokeColor = c);
              widget.object.set(stroke: c);
            },
          ),
        ),
      ]),
      const SizedBox(height: 8),

      // Stroke width
      Row(children: [
        SizedBox(width: 72, child: _sectionLabel('Stroke W.', theme, cs)),
        Expanded(
          child: Slider(
            value: _strokeWidth.clamp(0.0, 30.0),
            min: 0,
            max: 30,
            divisions: 30,
            label: '${_strokeWidth.toStringAsFixed(0)}px',
            onChanged: (v) {
              setState(() => _strokeWidth = v);
              widget.object.set(strokeWidth: v);
            },
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${_strokeWidth.toStringAsFixed(0)}px',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.right,
          ),
        ),
      ]),
    ];
  }

  // ── Shared rows ────────────────────────────────────────────────────────────

  Widget _opacityRow(ThemeData theme, ColorScheme cs) {
    return Row(children: [
      SizedBox(width: 72, child: _sectionLabel('Opacity', theme, cs)),
      Expanded(
        child: Slider(
          value: _opacity,
          min: 0,
          max: 1,
          divisions: 20,
          label: '${(_opacity * 100).toStringAsFixed(0)}%',
          onChanged: (v) {
            setState(() => _opacity = v);
            widget.object.set(opacity: v);
          },
        ),
      ),
      SizedBox(
        width: 42,
        child: Text(
          '${(_opacity * 100).toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.right,
        ),
      ),
    ]);
  }

  Widget _dimensionsRow(ThemeData theme, ColorScheme cs) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _widthCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Width',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            suffixText: 'px',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (v) {
            final d = double.tryParse(v);
            if (d != null && d > 0) {
              widget.object.set(width: d, scaleX: 1.0);
            }
          },
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: _heightCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Height',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            suffixText: 'px',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (v) {
            final d = double.tryParse(v);
            if (d != null && d > 0) {
              widget.object.set(height: d, scaleY: 1.0);
            }
          },
        ),
      ),
    ]);
  }

  // ── Arrange section ────────────────────────────────────────────────────────

  Widget _arrangeSection(ThemeData theme, ColorScheme cs) {
    final isLocked = widget.object.lockMovementX && widget.object.lockMovementY;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              'Arrange',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Wrap(
            children: [
              _actionBtn(Icons.copy_outlined, 'Duplicate',
                  widget.onDuplicate, cs),
              _actionBtn(Icons.delete_outline, 'Delete',
                  widget.onDelete, cs, destructive: true),
              _actionBtn(Icons.vertical_align_top, 'To Front',
                  widget.onBringToFront, cs),
              _actionBtn(Icons.vertical_align_bottom, 'To Back',
                  widget.onSendToBack, cs),
              _actionBtn(Icons.arrow_upward, 'Forward',
                  widget.onBringForward, cs),
              _actionBtn(Icons.arrow_downward, 'Backward',
                  widget.onSendBackward, cs),
              _actionBtn(
                isLocked ? Icons.lock_open_outlined : Icons.lock_outline,
                isLocked ? 'Unlock' : 'Lock',
                isLocked ? widget.onUnlockMovement : widget.onLockMovement,
                cs,
              ),
              _actionBtn(
                widget.object.visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                widget.object.visible ? 'Hide' : 'Show',
                widget.onToggleVisible,
                cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, ThemeData theme, ColorScheme cs) {
    return Text(
      text,
      style: theme.textTheme.labelSmall
          ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
    );
  }

  Widget _toggleChip({
    required Widget child,
    required bool isActive,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: DefaultTextStyle(
          style: TextStyle(
            color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _textAlignRow(ColorScheme cs) {
    const aligns = [TextAlign.left, TextAlign.center, TextAlign.right];
    const icons = [
      Icons.format_align_left,
      Icons.format_align_center,
      Icons.format_align_right
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = _textAlign == aligns[i];
        return GestureDetector(
          onTap: () {
            setState(() => _textAlign = aligns[i]);
            _asText!.textAlign = aligns[i];
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(
              icons[i],
              size: 16,
              color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        );
      }),
    );
  }

  Widget _colorSwatches(
    Color selected,
    List<Color> colors, {
    required void Function(Color) onPick,
    bool showTransparent = true,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (showTransparent)
            _colorChip(Colors.transparent, selected, onPick),
          ...colors.map((c) => _colorChip(c, selected, onPick)),
        ],
      ),
    );
  }

  Widget _colorChip(
      Color color, Color selected, void Function(Color) onPick) {
    final cs = Theme.of(context).colorScheme;
    final isTransparent = (color.a * 255.0).round() == 0;
    final isSelected = color.toARGB32() == selected.toARGB32();
    return GestureDetector(
      onTap: () => onPick(color),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: isTransparent ? null : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: isTransparent
            ? Icon(Icons.block, size: 12, color: cs.onSurfaceVariant)
            : isSelected
                ? Icon(
                    Icons.check,
                    size: 12,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    VoidCallback onTap,
    ColorScheme cs, {
    bool destructive = false,
  }) {
    final color = destructive ? cs.error : cs.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: color, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
