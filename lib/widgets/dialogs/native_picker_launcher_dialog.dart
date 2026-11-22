import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';

/// Modal dialog that wraps invocation of the native OS file manager or file picker,
/// always providing explicit Cancel and Back buttons so the user is never trapped
/// without a way to back out of the picker.
class NativePickerLauncherDialog<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final String actionButtonLabel;
  final Future<T?> Function() onLaunchPicker;
  final List<Widget>? quickOptions;
  final bool allowManualPath;
  final String? manualPathHint;
  final ValueChanged<String>? onManualPathSubmitted;

  const NativePickerLauncherDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    this.actionButtonLabel = 'Open Native File Manager',
    required this.onLaunchPicker,
    this.quickOptions,
    this.allowManualPath = false,
    this.manualPathHint,
    this.onManualPathSubmitted,
  });

  /// Displays the launcher dialog for directory selection.
  static Future<String?> showDirectoryPicker(
    BuildContext context, {
    String title = 'Choose Folder',
    String subtitle = 'Open your device\'s native file manager to select a folder.',
    IconData icon = Icons.folder_open_outlined,
    Color? iconColor,
    String actionButtonLabel = 'Open System Folder Picker',
    required Future<String?> Function() onLaunchPicker,
    List<Widget>? quickOptions,
    bool allowManualPath = false,
    String? manualPathHint,
    ValueChanged<String>? onManualPathSubmitted,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NativePickerLauncherDialog<String>(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor ?? GruvboxColors.yellow,
        actionButtonLabel: actionButtonLabel,
        onLaunchPicker: onLaunchPicker,
        quickOptions: quickOptions,
        allowManualPath: allowManualPath,
        manualPathHint: manualPathHint,
        onManualPathSubmitted: onManualPathSubmitted,
      ),
    );
  }

  /// Displays the launcher dialog for file selection.
  static Future<List<String>?> showFilePicker(
    BuildContext context, {
    String title = 'Select File',
    String subtitle = 'Open your device\'s native file manager to select a file.',
    IconData icon = Icons.file_open_outlined,
    Color? iconColor,
    String actionButtonLabel = 'Open System File Picker',
    required Future<List<String>?> Function() onLaunchPicker,
    List<Widget>? quickOptions,
  }) {
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NativePickerLauncherDialog<List<String>>(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor ?? GruvboxColors.aqua,
        actionButtonLabel: actionButtonLabel,
        onLaunchPicker: onLaunchPicker,
        quickOptions: quickOptions,
      ),
    );
  }

  @override
  State<NativePickerLauncherDialog<T>> createState() => _NativePickerLauncherDialogState<T>();
}

class _NativePickerLauncherDialogState<T> extends State<NativePickerLauncherDialog<T>> {
  bool _isPickerActive = false;
  String? _statusMessage;
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _handleLaunchPicker() async {
    setState(() {
      _isPickerActive = true;
      _statusMessage = null;
    });

    try {
      final result = await widget.onLaunchPicker();
      if (!mounted) return;

      if (result != null) {
        // If it's a List and empty, treat as cancelled
        if (result is List && result.isEmpty) {
          setState(() {
            _isPickerActive = false;
            _statusMessage = 'Picker cancelled or backed out. Tap Cancel / Back below to exit.';
          });
        } else {
          Navigator.of(context).pop(result);
        }
      } else {
        setState(() {
          _isPickerActive = false;
          _statusMessage = 'Picker cancelled or backed out. Tap Cancel / Back below to exit.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPickerActive = false;
        _statusMessage = 'Picker error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = widget.iconColor ?? GruvboxColors.aqua;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GruvboxColors.subtleDivider, width: 0.8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Navigation Bar with clear Back and Cancel buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: GruvboxColors.bgHard.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75)),
                ),
                child: Row(
                  children: [
                    TactilePressable(
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).pop(null),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(Icons.arrow_back_rounded, size: 20, color: GruvboxColors.fg),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.uiLabel(
                              GruvboxColors.fg0,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.uiLabel(
                              GruvboxColors.fgMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TactilePressable(
                      tooltip: 'Cancel',
                      onTap: () => Navigator.of(context).pop(null),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(Icons.close_rounded, size: 20, color: GruvboxColors.fgMuted),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isPickerActive) ...[
                      // Active state while native picker is open on device
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GruvboxColors.aqua.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: GruvboxColors.aqua,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Native File Picker is active',
                              style: AppTypography.uiLabel(
                                GruvboxColors.fg0,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select a location in the system file manager, or tap below to back out.',
                              textAlign: TextAlign.center,
                              style: AppTypography.uiLabel(
                                GruvboxColors.fgMuted,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Primary Back Out button during active picker
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GruvboxColors.red.withValues(alpha: 0.88),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: const Text('Back out of Picker / Cancel', style: TextStyle(fontSize: 12.5)),
                              onPressed: () => Navigator.of(context).pop(null),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Status / Cancelled alert message if user previously backed out
                      if (_statusMessage != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: GruvboxColors.yellow.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: GruvboxColors.yellow.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: GruvboxColors.yellow),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _statusMessage!,
                                  style: AppTypography.uiLabel(GruvboxColors.fg, fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Main button to launch native file picker
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: effectiveIconColor,
                          foregroundColor: GruvboxColors.bgHard,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(widget.icon, size: 19),
                        label: Text(
                          widget.actionButtonLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _handleLaunchPicker,
                      ),

                      // Optional manual path entry (for folder picker)
                      if (widget.allowManualPath) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: Divider(color: GruvboxColors.subtleDivider, height: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'OR ENTER PATH',
                                style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 10).copyWith(letterSpacing: 1),
                              ),
                            ),
                            Expanded(child: Divider(color: GruvboxColors.subtleDivider, height: 1)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _pathController,
                                  style: AppTypography.uiLabel(GruvboxColors.fg, fontSize: 12.5),
                                  decoration: InputDecoration(
                                    hintText: widget.manualPathHint ?? (Platform.isAndroid ? '/storage/emulated/0/Documents/...' : 'C:\\...'),
                                    hintStyle: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 11.5),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    filled: true,
                                    fillColor: GruvboxColors.bg.withValues(alpha: 0.7),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: effectiveIconColor, width: 1.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GruvboxColors.bg2,
                                foregroundColor: GruvboxColors.fg,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                final text = _pathController.text.trim();
                                if (text.isNotEmpty) {
                                  if (widget.onManualPathSubmitted != null) {
                                    widget.onManualPathSubmitted!(text);
                                  }
                                  Navigator.of(context).pop(text as T);
                                }
                              },
                              child: const Text('Open Path', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],

                      // Optional Quick Options (e.g. quick folder shortcuts or recent files)
                      if (widget.quickOptions != null && widget.quickOptions!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.quickOptions!,
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              // Bottom Actions Bar with explicit, unmissable Cancel/Back button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: GruvboxColors.bgHard.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GruvboxColors.fg,
                        side: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 15),
                      label: const Text('Cancel / Back', style: TextStyle(fontSize: 12.5)),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
