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
        bool isFoldedOrNarrow = constraints.maxWidth < 840;

        try {
          final displayFeatures = MediaQuery.of(context).displayFeatures;
          if (displayFeatures.isNotEmpty) {
            // Foldable display support
          }
        } catch (_) {
          // Fallback to width-based
        }

        if (isFoldedOrNarrow) {
          return const SinglePaneNav();
        }

        return const Scaffold(
          body: SafeArea(
            child: ThreePaneLayout(
              leftPane: FileTreePanel(),
              centerPane: EditorPane(),
              rightPane: AiPanel(),
            ),
          ),
        );
      },
    );
  }
}
