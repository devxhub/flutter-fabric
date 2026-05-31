import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fabric/flutter_fabric.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_fabric demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _DemoShell(),
    );
  }
}

// ── Demo shell with three tabs ──────────────────────────────────────────────

class _DemoShell extends StatefulWidget {
  const _DemoShell();

  @override
  State<_DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<_DemoShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_fabric'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Full Board'),
            Tab(icon: Icon(Icons.edit), text: 'Draw Only'),
            Tab(icon: Icon(Icons.visibility), text: 'View Only'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _FullBoardTab(),
          _DrawOnlyTab(),
          _ViewOnlyTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: Full FabricBoard ─────────────────────────────────────────────────

/// Full-featured canvas with:
/// - [showUserGuide]: "Help" button with context-aware guide
/// - [showToolbarLabels]: optional labels toggle
/// - [onSubmit]: fires when the Submit toolbar button is tapped
/// - [onChangeJsonData]: receive canvas JSON on every edit
/// - Toolbar includes exportJson and exportImage tools
class _FullBoardTab extends StatefulWidget {
  const _FullBoardTab();

  @override
  State<_FullBoardTab> createState() => _FullBoardTabState();
}

class _FullBoardTabState extends State<_FullBoardTab> {
  final _key = GlobalKey<FabricBoardState>();
  String? _selectedId;
  bool _showLabels = false;

  // Updated on every canvas change via onChangeJsonData
  int _jsonLength = 0;

  /// Share or save the exported image bytes.
  ///
  /// [bytes] are PNG-encoded. When [format] is "jpg" we rename the temp file
  /// with a .jpg extension so the OS picker shows it as a photo.
  Future<void> _onImageExported(Uint8List bytes, String format) async {
    // Capture context-dependent values before any async gap (lint: no
    // BuildContext use across awaits).
    final screenSize = MediaQuery.of(context).size;
    final origin = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: 1,
      height: 1,
    );

    try {
      final dir = await getTemporaryDirectory();
      final ext = format == 'jpg' ? 'jpg' : 'png';
      final mime = format == 'jpg' ? 'image/jpeg' : 'image/png';
      final file = File('${dir.path}/canvas_export.$ext');
      await file.writeAsBytes(bytes);

      // iOS requires a non-zero sharePositionOrigin to anchor the share sheet.
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mime, name: 'canvas_export.$ext')],
        subject: 'Canvas export',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  void _onSubmit(String json) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Canvas JSON is ready to send.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                json.length > 500
                    ? '${json.substring(0, 500)}…\n(${json.length} chars total)'
                    : json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('JSON copied to clipboard'),
                    duration: Duration(seconds: 2)),
              );
            },
            child: const Text('Copy & Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // ── Controls bar ──────────────────────────────────────────────────
        Material(
          color: cs.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // Selected object id
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _selectedId != null
                        ? Text(
                            'Selected: $_selectedId',
                            key: ValueKey(_selectedId),
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            'JSON: $_jsonLength chars',
                            key: const ValueKey('none'),
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                  ),
                ),
                // Labels toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Labels',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 4),
                    Switch.adaptive(
                      value: _showLabels,
                      onChanged: (v) => setState(() => _showLabels = v),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Canvas ────────────────────────────────────────────────────────
        Expanded(
          child: FabricBoard(
            key: _key,

            // Feature toggles
            enableSelection: true,
            enableDrag: true,
            enablePan: true,
            enableZoom: true,
            enableMarqueeSelection: true,
            enableKeyboardShortcuts: true,
            enableDoubleTapEdit: true,
            enableLongPressMenu: true,

            // Toolbar — includes export tools and the submit button
            showToolbar: true,
            toolbarPosition: FabricToolbarPosition.top,
            toolbarItems: const [
              FabricTool.select,
              FabricTool.pencil,
              FabricTool.eraser,
              FabricTool.spray,
              FabricTool.divider,
              FabricTool.drawRect,
              FabricTool.drawCircle,
              FabricTool.drawEllipse,
              FabricTool.drawTriangle,
              FabricTool.drawLine,
              FabricTool.divider,
              FabricTool.addText,
              FabricTool.addTextBox,
              FabricTool.divider,
              FabricTool.undo,
              FabricTool.redo,
              FabricTool.delete,
              FabricTool.clear,
              FabricTool.divider,
              FabricTool.colorPicker,
              FabricTool.strokeColor,
              FabricTool.brushWidth,
              FabricTool.divider,
              FabricTool.exportJson, // opens JSON sheet
              FabricTool.exportImage, // renders & previews PNG
              FabricTool.submit, // calls onSubmit
            ],

            showToolbarLabels: _showLabels,
            showUserGuide: true,

            initialFillColor: Colors.indigo,
            initialStrokeColor: Colors.transparent,
            initialBrushWidth: 4,

            // ── Callbacks ──────────────────────────────────────────────
            onObjectSelected: (obj) => setState(() => _selectedId = obj.id),
            onSelectionCleared: () => setState(() => _selectedId = null),

            // Real-time JSON — update char-count indicator
            onChangeJsonData: (json) =>
                setState(() => _jsonLength = json.length),

            // Submit — show dialog with JSON
            onSubmit: _onSubmit,

            // Image export — share / save via share_plus
            onImageExported: _onImageExported,

            onReady: (ctrl) {
              ctrl.add(FabricText(
                'Tap "Help" · long-press objects · use Export / Submit tools',
                left: 20,
                top: 60,
                fontSize: 14,
                fill: Colors.indigo.shade600,
              ));
            },

            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://www.transparenttextures.com/patterns/grid-me.png',
                  ),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Drawing only ─────────────────────────────────────────────────────

/// Pure drawing surface — no selection or move.
/// [showToolbarLabels]: always on so every brush name is visible.
/// [exportJson] and [exportImage] still available.
class _DrawOnlyTab extends StatelessWidget {
  const _DrawOnlyTab();

  @override
  Widget build(BuildContext context) {
    return FabricBoard(
      enableSelection: false,
      enableDrag: false,
      enableMarqueeSelection: false,
      toolbarItems: const [
        FabricTool.pencil,
        FabricTool.eraser,
        FabricTool.spray,
        FabricTool.divider,
        FabricTool.colorPicker,
        FabricTool.brushWidth,
        FabricTool.divider,
        FabricTool.undo,
        FabricTool.redo,
        FabricTool.clear,
        FabricTool.divider,
        FabricTool.exportJson,
        FabricTool.exportImage,
      ],
      toolbarPosition: FabricToolbarPosition.top,
      showToolbarLabels: true,
      showUserGuide: true,
      toolbarStyle: FabricToolbarStyle(
        backgroundColor: Colors.white70,
        iconColor: Colors.grey.shade700,
        selectedColor: Theme.of(context).colorScheme.primary,
        selectedIconColor: Colors.white,
        borderRadius: 0,
        elevation: 4,
      ),
      initialFillColor: Colors.black,
      initialBrushWidth: 5,
    );
  }
}

// ── Tab 3: View only ────────────────────────────────────────────────────────

/// Read-only canvas — zoom & pan only.
/// The user guide reflects that selection / editing are disabled.
class _ViewOnlyTab extends StatefulWidget {
  const _ViewOnlyTab();

  @override
  State<_ViewOnlyTab> createState() => _ViewOnlyTabState();
}

class _ViewOnlyTabState extends State<_ViewOnlyTab> {
  final _ctrl = FabricController(backgroundColor: const Color(0xFFF5F5F5));

  @override
  void initState() {
    super.initState();
    _ctrl.add(FabricRect(
      left: 40,
      top: 60,
      width: 160,
      height: 100,
      fill: Colors.indigo.shade200,
    ));
    _ctrl.add(FabricCircle(
      left: 240,
      top: 60,
      radius: 50,
      fill: Colors.pink.shade200,
    ));
    _ctrl.add(FabricTriangle(
      left: 140,
      top: 200,
      width: 120,
      height: 100,
      fill: Colors.teal.shade200,
    ));
    _ctrl.add(FabricText(
      'Read-only · zoom & pan only',
      left: 30,
      top: 340,
      fontSize: 18,
      fill: Colors.grey.shade700,
    ));
    _ctrl.add(FabricText(
      'Tap "Help" to see what is enabled',
      left: 30,
      top: 375,
      fontSize: 13,
      fill: Colors.grey.shade500,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FabricCanvas(
          controller: _ctrl,
          enableSelection: false,
          enableDrag: false,
          enableMarqueeSelection: false,
          enableKeyboardShortcuts: false,
          enableDoubleTapEdit: false,
          enablePan: true,
          enableZoom: true,
        ),
        // Overlay a no-toolbar FabricBoard for the user guide + export tools
        Positioned.fill(
          child: FabricBoard(
            controller: _ctrl,
            showToolbar: false,
            enableSelection: false,
            enableDrag: false,
            enableMarqueeSelection: false,
            enableKeyboardShortcuts: false,
            enableDoubleTapEdit: false,
            enableLongPressMenu: false,
            enablePan: true,
            enableZoom: true,
            showUserGuide: true,
            showToolbarLabels: false,
            backgroundColor: Colors.transparent,
          ),
        ),
        // Pinch/pan hint
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Pinch to zoom · drag to pan',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
