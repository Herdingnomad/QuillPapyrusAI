import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/layout/adaptive_shell.dart';
import 'package:quill_papyrus_ai/providers/theme_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class QuillPapyrusApp extends ConsumerWidget {
  const QuillPapyrusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final activeTheme = themeState.activeTheme;

    // Ensure GruvboxColors static pointer is always in sync with activeTheme
    GruvboxColors.setActiveTheme(activeTheme);

    final themeData = GruvboxTheme.buildTheme(activeTheme);

    return MaterialApp(
      title: 'Quill & Papyrus AI',
      theme: themeData,
      darkTheme: themeData,
      themeAnimationDuration: const Duration(milliseconds: 220),
      themeAnimationCurve: Curves.easeOutCubic,
      themeMode: activeTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const AdaptiveShell(),
    );
  }
}
