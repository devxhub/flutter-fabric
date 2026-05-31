import 'package:flutter/material.dart';
import 'package:flutter_fabric/flutter_fabric.dart';

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

// ── Tab 1: Full FabricBoard — all features enabled ─────────────────────────

/// Demonstrates the minimal code needed for a fully-featured canvas editor.
class _FullBoardTab extends StatefulWidget {
  const _FullBoardTab();

  @override
  State<_FullBoardTab> createState() => _FullBoardTabState();
}

class _FullBoardTabState extends State<_FullBoardTab> {
  final _key = GlobalKey<FabricBoardState>();
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status bar — shows selected object id
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _selectedId != null ? 36 : 0,
          color: Theme.of(context).colorScheme.primaryContainer,
          alignment: Alignment.center,
          child: Text(
            'Selected: $_selectedId',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),

        // ── The entire canvas editor — just one widget ──────────────────
        Expanded(
          child: FabricBoard(
            key: _key,

            // Feature toggles — all on by default
            enableSelection: true,
            enableDrag: true,
            enablePan: true,
            enableZoom: true,
            enableMarqueeSelection: true,
            enableKeyboardShortcuts: true,
            enableDoubleTapEdit: true,
            enableLongPressMenu: true,

            // Toolbar
            showToolbar: true,
            toolbarPosition: FabricToolbarPosition.bottom,

            // Initial colors
            initialFillColor: Colors.indigo,
            initialStrokeColor: Colors.transparent,
            initialBrushWidth: 4,

            // Callbacks
            onObjectSelected: (obj) => setState(() => _selectedId = obj.id),
            onSelectionCleared: () => setState(() => _selectedId = null),
            onReady: (ctrl) {
              ctrl.add(FabricText(
                'Use the toolbar below!',
                left: 60,
                top: 80,
                fontSize: 22,
                fill: Colors.indigo,
              ));
            },

            // Background: any Flutter widget goes here (must be last)
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

/// Demonstrates disabling selection/move and showing only drawing tools.
class _DrawOnlyTab extends StatelessWidget {
  const _DrawOnlyTab();

  @override
  Widget build(BuildContext context) {
    return FabricBoard(
      // No selection or object moving — pure drawing surface
      enableSelection: false,
      enableDrag: false,
      enableMarqueeSelection: false,

      // Only drawing tools in the toolbar
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
      ],
      toolbarPosition: FabricToolbarPosition.top,

      toolbarStyle: FabricToolbarStyle(
        backgroundColor: Colors.grey.shade900,
        iconColor: Colors.white70,
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

/// Demonstrates a read-only canvas — zoom & pan but no editing.
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
    // Populate with some objects
    _ctrl.add(FabricRect(
      left: 40, top: 60, width: 160, height: 100,
      fill: Colors.indigo.shade200,
    ));
    _ctrl.add(FabricCircle(
      left: 240, top: 60, radius: 50,
      fill: Colors.pink.shade200,
    ));
    _ctrl.add(FabricTriangle(
      left: 140, top: 200, width: 120, height: 100,
      fill: Colors.teal.shade200,
    ));
    _ctrl.add(FabricText(
      'Read-only: zoom & pan only',
      left: 30, top: 340,
      fontSize: 18,
      fill: Colors.grey.shade700,
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
        // Use FabricCanvas directly with all editing disabled
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
        // Overlay hint
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
