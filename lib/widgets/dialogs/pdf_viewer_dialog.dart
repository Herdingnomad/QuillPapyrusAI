import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/native_picker_launcher_dialog.dart';
import 'package:quill_papyrus_ai/widgets/pdf/pdf_viewer_widget.dart';

/// Modal dialog for viewing a PDF directly within the app
class PdfViewerDialog extends StatelessWidget {
  final String? filePath;
  final String title;

  const PdfViewerDialog({
    super.key,
    this.filePath,
    required this.title,
  });

  /// Displays the PDF viewer modal
  static Future<void> show(
    BuildContext context, {
    String? filePath,
    String? title,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => PdfViewerDialog(
        filePath: filePath,
        title: title ?? (filePath != null ? p.basename(filePath) : 'PDF Document'),
      ),
    );
  }

  /// Prompts the user to pick any PDF from disk and opens it in the in-app viewer
  static Future<void> pickAndOpenPdf(BuildContext context) async {
    try {
      final pickedPaths = await NativePickerLauncherDialog.showFilePicker(
        context,
        title: 'Open PDF Document',
        subtitle: 'Select a PDF using your device\'s file manager.',
        icon: Icons.picture_as_pdf_outlined,
        iconColor: GruvboxColors.red,
        actionButtonLabel: 'Open System File Picker',
        onLaunchPicker: () async {
          final result = await FilePickerPlatform.instance.pickFiles(
            dialogTitle: 'Select PDF Document to View',
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
          if (result.isNotEmpty && result.first.path != null) {
            return [result.first.path!];
          }
          return null;
        },
      );

      if (pickedPaths != null && pickedPaths.isNotEmpty) {
        final path = pickedPaths.first;
        if (context.mounted) {
          await show(context, filePath: path, title: p.basename(path));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            content: Text('Error opening PDF: $e', style: TextStyle(color: GruvboxColors.red)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 900,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: GruvboxColors.bgHard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GruvboxColors.bg3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: GruvboxColors.bg,
                  border: Border(bottom: BorderSide(color: GruvboxColors.bg3)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: GruvboxColors.fg, size: 20),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.picture_as_pdf, color: GruvboxColors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: GruvboxColors.fg0,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                      tooltip: 'Close Viewer',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // PDF View body
              Expanded(
                child: PdfViewerWidget(
                  filePath: filePath,
                  fileName: title,
                  showAppBar: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
