import 'package:flutter/material.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/layout/adaptive_shell.dart';

class QuillPapyrusApp extends StatelessWidget {
  const QuillPapyrusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quill & Papyrus AI',
      theme: GruvboxTheme.darkTheme(),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const AdaptiveShell(),
    );
  }
}
