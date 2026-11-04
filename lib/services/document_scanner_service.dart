import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/windows_camera_scan_dialog.dart';

class DocumentScannerService {
  static const MethodChannel _channel = MethodChannel('com.jessiejensen.quill_papyrus_ai/document_scanner');
  final Ref _ref;

  DocumentScannerService(this._ref);

  /// Checks if the native Document Scanner is available on this platform
  Future<bool> isScannerAvailable() async {
    if (Platform.isAndroid) {
      try {
        final available = await _channel.invokeMethod<bool>('isScannerAvailable');
        return available ?? false;
      } catch (_) {
        return false;
      }
    } else if (Platform.isWindows) {
      return true;
    }
    return false;
  }

  /// Triggers document scanning with camera (Windows native Camera in Document mode
  /// or Android Google Document Scanner), saves the resulting PDF into [targetFolderUri],
  /// refreshes the workspace file tree, and opens the PDF in the editor.
  Future<String?> scanAndSave(BuildContext context, [String? targetFolderUri]) async {
    try {
      final workspace = _ref.read(workspaceProvider);
      final destFolderUri = targetFolderUri ?? workspace.selectedFolderUri ?? workspace.fileTree?.uri;
      if (destFolderUri == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please open a workspace folder first.')),
          );
        }
        return null;
      }

      // Desktop Windows: Use native Windows Camera document scanning workflow
      if (Platform.isWindows) {
        return await WindowsCameraScanDialog.show(
          context,
          targetFolderUri: destFolderUri,
        );
      }

      String? tempPdfPath;

      if (Platform.isAndroid) {
        try {
          tempPdfPath = await _channel.invokeMethod<String>('scanDocument');
        } on PlatformException catch (e) {
          final errorMsg = (e.message != null && e.message!.isNotEmpty)
              ? e.message!
              : (e.details?.toString() ?? e.code);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Document scanner error: $errorMsg')),
            );
          }
          return null;
        }
      } else {
        // Fallback for non-Android/non-Windows platforms
        final result = await FilePickerPlatform.instance.pickFiles(
          dialogTitle: 'Select Scanned PDF Document',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result.isNotEmpty && result.first.path != null) {
          tempPdfPath = result.first.path;
        }
      }

      if (tempPdfPath == null || tempPdfPath.isEmpty) {
        // User cancelled scan
        return null;
      }

      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'Scan_$dateSlug.pdf';

      final storage = _ref.read(safStorageServiceProvider);
      final createdUri = await storage.createFile(destFolderUri, fileName);

      // Copy bytes to the destination file
      final pdfBytes = await File(tempPdfPath).readAsBytes();
      await storage.writeBytes(createdUri, pdfBytes);

      // Refresh workspace file tree
      await _ref.read(workspaceProvider.notifier).refreshWorkspace();

      // Open the new PDF tab in editor
      await _ref.read(editorProvider.notifier).openFile(createdUri, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document scanned & saved as $fileName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return createdUri;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save scanned document: $e')),
        );
      }
      return null;
    }
  }
}

final documentScannerServiceProvider = Provider<DocumentScannerService>((ref) {
  return DocumentScannerService(ref);
});
