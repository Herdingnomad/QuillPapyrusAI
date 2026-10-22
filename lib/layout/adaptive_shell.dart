import 'dart:async';
import 'dart:ui' show DisplayFeatureType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/layout/single_pane_nav.dart';
import 'package:quill_papyrus_ai/layout/three_pane_layout.dart';
import 'package:quill_papyrus_ai/models/workspace_state.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/services/widget_service.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/quick_open_dialog.dart';
import 'package:quill_papyrus_ai/widgets/editor/editor_pane.dart';
import 'package:quill_papyrus_ai/widgets/file_tree/file_tree_panel.dart';
import 'package:quill_papyrus_ai/widgets/sidecar/sidecar_pane.dart';

class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key});

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> with WidgetsBindingObserver {
  Timer? _inactivityUnloadTimer;
  StreamSubscription<String>? _actionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = ref.read(workspaceProvider);
      if (state.status == WorkspaceStatus.initial) {
        await ref.read(workspaceProvider.notifier).loadDefaultWorkspace();
      }
      if (!mounted) return;

      // Check if launched via AppWidget action or deep-link
      final initialAction = await ref.read(widgetServiceProvider).getInitialAction();
      if (!mounted) return;
      if (initialAction != null && initialAction.isNotEmpty) {
        ref.read(quickNoteServiceProvider).handleActionUri(initialAction);
      }

      // Sync workspace root and initialize quick note notification
      final wsRoot = ref.read(workspaceProvider).rootUri;
      if (wsRoot != null) {
        ref.read(widgetServiceProvider).updateWorkspaceRoot(wsRoot);
      }
      ref.read(widgetServiceProvider).showQuickNoteNotification();
    });

    // Listen for incoming widget actions while app is already running
    _actionSubscription = ref.read(widgetServiceProvider).actionStream.listen((action) {
      if (mounted) {
        ref.read(quickNoteServiceProvider).handleActionUri(action);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityUnloadTimer?.cancel();
    _actionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned / focused app - cancel any pending model unload timer
      _inactivityUnloadTimer?.cancel();
      _inactivityUnloadTimer = null;
    } else if (state == AppLifecycleState.detached) {
      // Process is terminating - immediately unload native C++ model allocations
      _inactivityUnloadTimer?.cancel();
      ref.read(aiProvider.notifier).unloadModel();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // In Samsung DeX multi-window, clicking an adjacent window sends Quill to paused.
      // Do NOT unload immediately. Start a 5-minute grace timer before unloading RAM.
      _inactivityUnloadTimer?.cancel();
      _inactivityUnloadTimer = Timer(const Duration(minutes: 5), () {
        ref.read(aiProvider.notifier).unloadModel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Material 3 compact breakpoint is 600dp.
        // Samsung Galaxy Z Fold folded cover screen is ~360-410dp.
        // Samsung Galaxy Z Fold unfolded screen is ~768-884dp.
        // Samsung DeX desktop display is typically >= 1000dp.
        bool isFoldedOrNarrow = constraints.maxWidth < 650;

        try {
          final displayFeatures = MediaQuery.of(context).displayFeatures;
          final hasActiveFold = displayFeatures.any(
            (f) => f.type == DisplayFeatureType.hinge || f.type == DisplayFeatureType.fold,
          );
          if (hasActiveFold && constraints.maxWidth >= 600) {
            isFoldedOrNarrow = false;
          }
        } catch (_) {
          // Fallback to width-based
        }

        final isZenMode = ref.watch(layoutProvider).isZenMode;
        final Widget content = isFoldedOrNarrow
            ? const SinglePaneNav()
            : const Scaffold(
                body: SafeArea(
                  child: ThreePaneLayout(
                    leftPane: FileTreePanel(),
                    centerPane: EditorPane(),
                    rightPane: SidecarPane(),
                  ),
                ),
              );

        return CallbackShortcuts(
          bindings: {
            // Escape: Exit Zen Mode
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (ref.read(layoutProvider).isZenMode) {
                ref.read(layoutProvider.notifier).exitZenMode();
              }
            },
            // Save: Ctrl+S / Cmd+S
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
              ref.read(editorProvider.notifier).saveActiveFile();
            },
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
              ref.read(editorProvider.notifier).saveActiveFile();
            },
            // Quick Note / New Note: Ctrl+N / Cmd+N
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
              ref.read(quickNoteServiceProvider).createQuickNote();
            },
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
              ref.read(quickNoteServiceProvider).createQuickNote();
            },
            // Quick Open File Switcher: Ctrl+P / Cmd+P & Ctrl+O / Cmd+O
            const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
              QuickOpenDialog.show(context);
            },
            const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () {
              QuickOpenDialog.show(context);
            },
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
              QuickOpenDialog.show(context);
            },
            const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () {
              QuickOpenDialog.show(context);
            },
            // Close Active Tab: Ctrl+W / Cmd+W
            const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
              ref.read(editorProvider.notifier).closeActiveTab();
            },
            const SingleActivator(LogicalKeyboardKey.keyW, meta: true): () {
              ref.read(editorProvider.notifier).closeActiveTab();
            },
            // Cycle Tabs: Ctrl+Tab (next) & Ctrl+Shift+Tab (prev)
            const SingleActivator(LogicalKeyboardKey.tab, control: true): () {
              ref.read(editorProvider.notifier).nextTab();
            },
            const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): () {
              ref.read(editorProvider.notifier).previousTab();
            },
            // Toggle File Explorer Sidebar: Ctrl+B / Cmd+B
            const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
              ref.read(layoutProvider.notifier).toggleLeftPane();
            },
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
              ref.read(layoutProvider.notifier).toggleLeftPane();
            },
            // Toggle AI Assistant Sidebar: Ctrl+J / Cmd+J
            const SingleActivator(LogicalKeyboardKey.keyJ, control: true): () {
              ref.read(layoutProvider.notifier).toggleRightPane();
            },
            const SingleActivator(LogicalKeyboardKey.keyJ, meta: true): () {
              ref.read(layoutProvider.notifier).toggleRightPane();
            },
            // View Mode shortcuts: Ctrl+1 (Source), Ctrl+2 (Split), Ctrl+3 (Preview)
            const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
              ref.read(editorProvider.notifier).setViewMode(EditorViewMode.source);
            },
            const SingleActivator(LogicalKeyboardKey.digit2, control: true): () {
              ref.read(editorProvider.notifier).setViewMode(EditorViewMode.split);
            },
            const SingleActivator(LogicalKeyboardKey.digit3, control: true): () {
              ref.read(editorProvider.notifier).setViewMode(EditorViewMode.preview);
            },
          },
          child: Focus(
            autofocus: true,
            child: PopScope(
              canPop: !isZenMode,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && isZenMode) {
                  ref.read(layoutProvider.notifier).exitZenMode();
                }
              },
              child: content,
            ),
          ),
        );
      },
    );
  }
}
