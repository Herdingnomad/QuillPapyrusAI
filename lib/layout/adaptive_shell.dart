import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/layout/three_pane_layout.dart';
import 'package:quill_papyrus_ai/layout/single_pane_nav.dart';
import 'package:quill_papyrus_ai/models/workspace_state.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/widgets/file_tree/file_tree_panel.dart';
import 'package:quill_papyrus_ai/widgets/editor/editor_pane.dart';
import 'package:quill_papyrus_ai/widgets/ai/ai_panel.dart';

import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show DisplayFeatureType;

class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key});

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(workspaceProvider);
      if (state.status == WorkspaceStatus.initial) {
        ref.read(workspaceProvider.notifier).loadDefaultWorkspace();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Free LLM RAM allocations and stop native C++ threads immediately on exit/minimize
      ref.read(aiProvider.notifier).unloadModel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Material 3 compact breakpoint is 600dp.
        // Samsung Galaxy Z Fold folded cover screen is ~360-410dp.
        // Samsung Galaxy Z Fold unfolded screen is ~768-884dp.
        // Devices with width >= 650dp or active unfolded foldables show the expansive ThreePaneLayout.
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
                    rightPane: AiPanel(),
                  ),
                ),
              );

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (ref.read(layoutProvider).isZenMode) {
                ref.read(layoutProvider.notifier).exitZenMode();
              }
            },
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
              ref.read(editorProvider.notifier).saveActiveFile();
            },
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
              ref.read(editorProvider.notifier).saveActiveFile();
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
