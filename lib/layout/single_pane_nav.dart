import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/quick_open_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/theme_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/editor/editor_pane.dart';
import 'package:quill_papyrus_ai/widgets/editor/voice_recorder_sheet.dart';
import 'package:quill_papyrus_ai/widgets/file_tree/file_tree_panel.dart';
import 'package:quill_papyrus_ai/widgets/sidecar/sidecar_pane.dart';

class SinglePaneNav extends ConsumerStatefulWidget {
  const SinglePaneNav({super.key});

  @override
  ConsumerState<SinglePaneNav> createState() => _SinglePaneNavState();
}

class _SinglePaneNavState extends ConsumerState<SinglePaneNav> {
  int _currentIndex = 1;
  late final PageController _pageController;
  bool _isAnimatingToPage = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int index) async {
    final target = index.clamp(0, 2);
    if (_currentIndex == target &&
        (!_pageController.hasClients || _pageController.page?.round() == target)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = target;
    });
    if (_pageController.hasClients) {
      _isAnimatingToPage = true;
      try {
        await _pageController.animateToPage(
          target,
          duration: AppMotion.paneTransition,
          curve: AppMotion.snappyEaseOut,
        );
      } finally {
        _isAnimatingToPage = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LayoutState>(layoutProvider, (previous, next) {
      if (previous == null) return;
      if (previous.isLeftPaneVisible != next.isLeftPaneVisible) {
        if (_currentIndex == 0 && !next.isLeftPaneVisible) {
          _goToPage(1);
        } else if (_currentIndex != 0 && next.isLeftPaneVisible) {
          _goToPage(0);
        }
      } else if (previous.isRightPaneVisible != next.isRightPaneVisible) {
        if (_currentIndex == 2 && !next.isRightPaneVisible) {
          _goToPage(1);
        } else if (_currentIndex != 2 && next.isRightPaneVisible) {
          _goToPage(2);
        }
      }
    });

    final layoutState = ref.watch(layoutProvider);
    final editorState = ref.watch(editorProvider);
    final isZen = layoutState.isZenMode;
    final activeTab = editorState.activeTab;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: GruvboxColors.bg,
      appBar: isZen
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: SafeArea(
                bottom: false,
                child: FrostedChrome(
                  blur: 20.0,
                  backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.92),
                  border: Border(
                    bottom: BorderSide(
                      color: GruvboxColors.subtleDivider,
                      width: 0.75,
                    ),
                  ),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        FountainNibMark(
                          size: 16,
                          color: GruvboxColors.accent,
                        ),
                        const SizedBox(width: 6),
                        if (activeTab != null)
                          Expanded(
                            child: Text(
                              activeTab.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.sectionTitle(
                                GruvboxColors.fg,
                                fontSize: 15,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Text(
                              'Quill & Papyrus',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.brandWordmark(
                                GruvboxColors.fg,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        TactilePressable(
                          tooltip: 'Quick Open (Ctrl+P)',
                          onTap: () => QuickOpenDialog.show(context),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(Icons.search, size: 19, color: GruvboxColors.fgMuted),
                          ),
                        ),
                        TactilePressable(
                          tooltip: 'Quick Note',
                          onTap: () => ref.read(quickNoteServiceProvider).createQuickNote(),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(Icons.add, size: 20, color: GruvboxColors.fgMuted),
                          ),
                        ),
                        TactilePressable(
                          tooltip: 'Record Voice Memo',
                          onTap: () => VoiceRecorderSheet.show(context),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(Icons.mic_none_rounded, size: 19, color: GruvboxColors.fgMuted),
                          ),
                        ),
                        TactilePressable(
                          tooltip: 'Themes',
                          onTap: () => showThemeManagerDialog(context, ref),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(Icons.palette_outlined, size: 19, color: GruvboxColors.fgMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        top: isZen,
        child: PageView(
          controller: _pageController,
          physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
          onPageChanged: (index) {
            if (_isAnimatingToPage) return;
            if (_currentIndex != index) {
              FocusManager.instance.primaryFocus?.unfocus();
              HapticFeedback.selectionClick();
              setState(() {
                _currentIndex = index;
              });
            }
          },
          children: const [
            _KeepAlivePane(child: FileTreePanel()),
            _KeepAlivePane(child: EditorPane()),
            _KeepAlivePane(child: SidecarPane()),
          ],
        ),
      ),
      bottomNavigationBar: (isZen || isKeyboardOpen)
          ? null
          : Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppMaterials.paperSheetShadows(
                  isDark: GruvboxColors.activeTheme.isDark,
                  elevationScale: 1.1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FrostedChrome(
                  backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.92),
                  blur: 22.0,
                  border: Border.all(
                    color: GruvboxColors.hairlineBorder,
                    width: 0.75,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedItemColor: GruvboxColors.accent,
                      unselectedItemColor: GruvboxColors.fgMuted,
                      selectedLabelStyle: AppTypography.uiLabel(
                        GruvboxColors.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: AppTypography.uiLabel(
                        GruvboxColors.fgMuted,
                        fontSize: 11.5,
                      ),
                      type: BottomNavigationBarType.fixed,
                      onTap: _goToPage,
                      items: [
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.folder_outlined, size: 20),
                          activeIcon: Icon(Icons.folder_rounded, size: 20),
                          label: 'Files',
                        ),
                        BottomNavigationBarItem(
                          icon: FountainNibMark(size: 19, color: GruvboxColors.fgMuted),
                          activeIcon: FountainNibMark(size: 19, color: GruvboxColors.accent),
                          label: 'Editor',
                        ),
                        BottomNavigationBarItem(
                          icon: InkQuillSparkMark(size: 19, color: GruvboxColors.fgMuted),
                          activeIcon: InkQuillSparkMark(size: 19, color: GruvboxColors.accent),
                          label: 'AI Chat',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _KeepAlivePane extends StatefulWidget {
  final Widget child;

  const _KeepAlivePane({required this.child});

  @override
  State<_KeepAlivePane> createState() => _KeepAlivePaneState();
}

class _KeepAlivePaneState extends State<_KeepAlivePane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
