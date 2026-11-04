import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img_lib;
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/document_scanner_service.dart';
import 'package:quill_papyrus_ai/services/pdf_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/windows_camera_scan_dialog.dart';

class MockSafStorageService extends SafStorageService {
  final Map<String, List<int>> writtenBytes = {};
  final List<String> createdFiles = [];

  @override
  Future<String> createFile(String directoryUri, String fileName) async {
    final path = '$directoryUri/$fileName';
    createdFiles.add(path);
    return path;
  }

  @override
  Future<void> writeBytes(String uri, List<int> bytes) async {
    writtenBytes[uri] = bytes;
  }

  @override
  Future<String> readFile(String uri) async => '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Windows Native Camera Document Scanning Tests', () {
    test('PdfService compiles scanned image bytes into valid multi-page PDF', () async {
      // Create two sample JPG images
      final img1 = img_lib.Image(width: 200, height: 300);
      img_lib.fill(img1, color: img_lib.ColorRgb8(200, 50, 50));
      final bytes1 = Uint8List.fromList(img_lib.encodeJpg(img1));

      final img2 = img_lib.Image(width: 400, height: 600);
      img_lib.fill(img2, color: img_lib.ColorRgb8(50, 200, 50));
      final bytes2 = Uint8List.fromList(img_lib.encodeJpg(img2));

      final pdfBytes = await PdfService.instance.generatePdfFromScannedImages([bytes1, bytes2]);

      expect(pdfBytes, isNotEmpty);
      // Valid PDF magic header
      expect(String.fromCharCodes(pdfBytes.sublist(0, 4)), equals('%PDF'));
    });

    test('DocumentScannerService reports scanner available on Windows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final scannerService = container.read(documentScannerServiceProvider);
      final isAvailable = await scannerService.isScannerAvailable();

      if (Platform.isWindows) {
        expect(isAvailable, isTrue);
      }
    });

    testWidgets('WindowsCameraScanDialog displays Windows Camera guidance and Document mode tips', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool cameraLaunched = false;
      final tempDir = Directory.systemTemp.createTempSync('win_camera_test_');
      addTearDown(() {
        try {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: WindowsCameraScanDialog(
                targetFolderUri: tempDir.path,
                overrideCandidateDirs: [tempDir],
                autoPoll: false,
                onLaunchCamera: () async {
                  cameraLaunched = true;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify header and Windows Native badge
      expect(find.text('Windows Camera Document Scanner'), findsOneWidget);
      expect(find.text('Windows Native'), findsOneWidget);

      // Verify guidance mentions "Document" mode
      expect(find.textContaining('Document'), findsWidgets);
      expect(find.textContaining('edge-detection'), findsOneWidget);

      // Verify camera launch hook was called
      expect(cameraLaunched, isTrue);

      // Verify initial empty state
      expect(find.text('Waiting for camera captures...'), findsOneWidget);
      expect(find.text('Waiting for first scan...'), findsOneWidget);
    });

    testWidgets('WindowsCameraScanDialog detects camera captures in Camera Roll and compiles to PDF', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('win_camera_scan_poll_');
      addTearDown(() {
        try {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final mockStorage = MockSafStorageService();
      final container = ProviderContainer(
        overrides: [
          safStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );
      addTearDown(container.dispose);

      String? createdUri;
      final dialogKey = GlobalKey<WindowsCameraScanDialogState>();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    createdUri = await showDialog<String?>(
                      context: context,
                      builder: (_) => WindowsCameraScanDialog(
                        key: dialogKey,
                        targetFolderUri: tempDir.path,
                        overrideCandidateDirs: [tempDir],
                        autoPoll: false,
                        onLaunchCamera: () async => true,
                      ),
                    );
                  },
                  child: const Text('Open Scanner'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open the dialog
      await tester.tap(find.text('Open Scanner'));
      await tester.pump();

      expect(find.text('Windows Camera Document Scanner'), findsOneWidget);

      // Simulate Windows Camera saving a photo to Camera Roll
      final sampleImg = img_lib.Image(width: 300, height: 400);
      img_lib.fill(sampleImg, color: img_lib.ColorRgb8(100, 150, 200));
      final jpgBytes = img_lib.encodeJpg(sampleImg);

      final capturedFile = File('${tempDir.path}/WIN_20261103_223000_Scan.jpg');
      capturedFile.writeAsBytesSync(jpgBytes);

      // Trigger poll manually
      dialogKey.currentState?.pollForNewCaptures();
      await tester.pump();

      // Page 1 should be detected
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('1 page ready to compile'), findsOneWidget);
      expect(find.text('Save as PDF'), findsOneWidget);

      // Compile and save
      await tester.runAsync(() async {
        await dialogKey.currentState?.compileAndSave();
      });
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Windows Camera Document Scanner'), findsNothing);

      // Verify file was written via mock storage
      expect(mockStorage.createdFiles, isNotEmpty);
      expect(mockStorage.createdFiles.first, contains('Scan_'));
      expect(mockStorage.createdFiles.first, endsWith('.pdf'));

      final writtenBytes = mockStorage.writtenBytes[mockStorage.createdFiles.first];
      expect(writtenBytes, isNotNull);
      expect(String.fromCharCodes(writtenBytes!.sublist(0, 4)), equals('%PDF'));
      expect(createdUri, equals(mockStorage.createdFiles.first));
    });
  });
}
