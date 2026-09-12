import 'dart:io';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:quill_papyrus_ai/models/app_theme_data.dart';

class ThemedExportService {
  ThemedExportService._();
  static final ThemedExportService instance = ThemedExportService._();

  String generateThemedHtml({
    required String title,
    required String markdownContent,
    required AppThemeData theme,
  }) {
    // Parse Markdown to HTML using GFM extensions
    final htmlBody = md.markdownToHtml(
      markdownContent,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    final bgHex = AppThemeData.colorToHex(theme.bg);
    final fgHex = AppThemeData.colorToHex(theme.fg);
    final fgMutedHex = AppThemeData.colorToHex(theme.fgMuted);
    final bg1Hex = AppThemeData.colorToHex(theme.bg1);
    final bg2Hex = AppThemeData.colorToHex(theme.bg2);
    final bg3Hex = AppThemeData.colorToHex(theme.bg3);
    final accentHex = AppThemeData.colorToHex(theme.accent);
    final accent2Hex = AppThemeData.colorToHex(theme.accentSecondary);
    final redHex = AppThemeData.colorToHex(theme.red);
    final greenHex = AppThemeData.colorToHex(theme.green);
    final yellowHex = AppThemeData.colorToHex(theme.yellow);
    final blueHex = AppThemeData.colorToHex(theme.blue);

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <style>
    :root {
      --bg: $bgHex;
      --fg: $fgHex;
      --fg-muted: $fgMutedHex;
      --card-bg: $bg1Hex;
      --hover-bg: $bg2Hex;
      --border: $bg3Hex;
      --accent: $accentHex;
      --accent2: $accent2Hex;
      --red: $redHex;
      --green: $greenHex;
      --yellow: $yellowHex;
      --blue: $blueHex;
    }

    * {
      box-sizing: border-box;
    }

    body {
      background-color: var(--bg);
      color: var(--fg);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      margin: 0;
      padding: 40px 20px;
    }

    .container {
      max-width: 820px;
      margin: 0 auto;
      background: var(--card-bg);
      padding: 40px;
      border-radius: 8px;
      border: 1px solid var(--border);
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
    }

    h1, h2, h3, h4, h5, h6 {
      color: var(--fg);
      margin-top: 24px;
      margin-bottom: 12px;
      font-weight: 700;
      line-height: 1.25;
    }

    h1 {
      color: var(--green);
      font-size: 2em;
      border-bottom: 1px solid var(--border);
      padding-bottom: 8px;
    }

    h2 {
      color: var(--yellow);
      font-size: 1.5em;
      border-bottom: 1px solid var(--border);
      padding-bottom: 6px;
    }

    h3 {
      color: var(--accent);
      font-size: 1.25em;
    }

    p, ul, ol {
      margin-top: 0;
      margin-bottom: 16px;
    }

    a {
      color: var(--blue);
      text-decoration: none;
    }

    a:hover {
      text-decoration: underline;
    }

    code {
      font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;
      font-size: 0.88em;
      background-color: var(--hover-bg);
      padding: 0.2em 0.4em;
      border-radius: 4px;
      color: var(--accent2);
    }

    pre {
      background-color: var(--bg);
      padding: 16px;
      overflow: auto;
      border-radius: 6px;
      border: 1px solid var(--border);
      margin-bottom: 16px;
    }

    pre code {
      background: transparent;
      padding: 0;
      color: var(--fg);
    }

    blockquote {
      margin: 0 0 16px 0;
      padding: 8px 16px;
      color: var(--fg-muted);
      border-left: 4px solid var(--accent);
      background-color: var(--hover-bg);
      border-radius: 0 4px 4px 0;
    }

    table {
      border-collapse: collapse;
      width: 100%;
      margin-bottom: 16px;
    }

    table th, table td {
      border: 1px solid var(--border);
      padding: 8px 12px;
      text-align: left;
    }

    table th {
      background-color: var(--hover-bg);
      font-weight: 600;
    }

    table tr:nth-child(even) {
      background-color: rgba(255, 255, 255, 0.02);
    }

    hr {
      height: 1px;
      background-color: var(--border);
      border: none;
      margin: 24px 0;
    }

    .export-footer {
      margin-top: 32px;
      padding-top: 12px;
      border-top: 1px solid var(--border);
      color: var(--fg-muted);
      font-size: 0.8em;
      display: flex;
      justify-content: space-between;
    }

    @media print {
      body {
        background-color: white;
        color: black;
        padding: 0;
      }
      .container {
        box-shadow: none;
        border: none;
        padding: 0;
        max-width: 100%;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    $htmlBody
    <div class="export-footer">
      <span>Exported from Quill &amp; Papyrus AI</span>
      <span>Theme: ${theme.name}</span>
    </div>
  </div>
</body>
</html>
''';
  }

  Future<void> copyHtmlToClipboard({
    required String title,
    required String markdownContent,
    required AppThemeData theme,
  }) async {
    final html = generateThemedHtml(
      title: title,
      markdownContent: markdownContent,
      theme: theme,
    );
    await Clipboard.setData(ClipboardData(text: html));
  }

  Future<File> saveHtmlToFile({
    required String title,
    required String markdownContent,
    required AppThemeData theme,
    required String filePath,
  }) async {
    final html = generateThemedHtml(
      title: title,
      markdownContent: markdownContent,
      theme: theme,
    );
    final file = File(filePath);
    return await file.writeAsString(html);
  }
}
