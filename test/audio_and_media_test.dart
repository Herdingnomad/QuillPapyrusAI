import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/journal_ingest_models.dart';
import 'package:quill_papyrus_ai/services/asset_resolver_service.dart';
import 'package:quill_papyrus_ai/services/audio_playback_service.dart';
import 'package:quill_papyrus_ai/services/audio_recording_service.dart';
import 'package:quill_papyrus_ai/services/image_preprocess_service.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/services/wikilink_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/widgets/preview/audio_player_card.dart';
import 'package:quill_papyrus_ai/widgets/preview/source_ocr_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WikilinkService Media and Embedding Tests', () {
    test('isMediaTarget accurately detects images and audio files', () {
      expect(WikilinkService.isMediaTarget('sketch.png'), isTrue);
      expect(WikilinkService.isMediaTarget('photo.JPG'), isTrue);
      expect(WikilinkService.isMediaTarget('recording.m4a'), isTrue);
      expect(WikilinkService.isMediaTarget('track.mp3'), isTrue);
      expect(WikilinkService.isMediaTarget('audio.wav'), isTrue);
      expect(WikilinkService.isMediaTarget('daily_note.md'), isFalse);
      expect(WikilinkService.isMediaTarget('Journal Note'), isFalse);
    });

    test('findMediaWikilinks extracts obsidian-style media links ![[...]]', () {
      const text = 'Here is the diagram: ![[Sketches/system_flow.png]] and audio ![[VoiceNotes/memo.m4a|Morning Thoughts]]';
      final links = WikilinkService.findMediaWikilinks(text);

      expect(links.length, 2);
      expect(links[0].target, 'Sketches/system_flow.png');
      expect(links[0].displayText, isNull);
      expect(WikilinkService.isMediaTarget(links[0].target), isTrue);

      expect(links[1].target, 'VoiceNotes/memo.m4a');
      expect(links[1].displayText, 'Morning Thoughts');
      expect(WikilinkService.isMediaTarget(links[1].target), isTrue);
    });

    test('resolveWikilink preserves media extension without appending .md', () {
      const root = FileNode(
        uri: '/vault',
        name: 'vault',
        path: '',
        isDirectory: true,
        children: [
          FileNode(
            uri: '/vault/Assets/Sketches/diagram.png',
            name: 'diagram.png',
            path: 'Assets/Sketches/diagram.png',
            isDirectory: false,
          ),
          FileNode(
            uri: '/vault/Assets/VoiceNotes/note.m4a',
            name: 'note.m4a',
            path: 'Assets/VoiceNotes/note.m4a',
            isDirectory: false,
          ),
        ],
      );

      final imgUri = WikilinkService.resolveWikilink('diagram.png', root);
      expect(imgUri, '/vault/Assets/Sketches/diagram.png');

      final audioUri = WikilinkService.resolveWikilink('note.m4a', root);
      expect(audioUri, '/vault/Assets/VoiceNotes/note.m4a');
    });
  });

  group('AssetResolverService Tests', () {
    late Directory tempDir;
    late File sketchFile;
    late File audioFile;
    late File noteFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('quill_asset_test_');
      final sketchesDir = Directory('${tempDir.path}/Assets/Sketches')..createSync(recursive: true);
      final voiceDir = Directory('${tempDir.path}/Assets/VoiceNotes')..createSync(recursive: true);
      final logsDir = Directory('${tempDir.path}/Daily-Logs')..createSync(recursive: true);

      sketchFile = File('${sketchesDir.path}/sketch_01.png')..writeAsStringSync('dummy image data');
      audioFile = File('${voiceDir.path}/memo_01.m4a')..writeAsStringSync('dummy audio data');
      noteFile = File('${logsDir.path}/2026-10-24.md')..writeAsStringSync('# Log');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('resolves relative paths based on current note file path', () {
      final resolved = AssetResolverService.resolvePath(
        rawPath: '../Assets/Sketches/sketch_01.png',
        currentDocUri: noteFile.path,
      );

      expect(resolved, isNotNull);
      expect(File(resolved!).existsSync(), isTrue);
      expect(p.canonicalize(resolved), p.canonicalize(sketchFile.path));
    });

    test('resolves relative path to workspace root', () {
      final resolved = AssetResolverService.resolvePath(
        rawPath: 'Assets/Sketches/sketch_01.png',
        workspaceRoot: tempDir.path,
      );

      expect(resolved, isNotNull);
      expect(File(resolved!).existsSync(), isTrue);
    });

    test('falls back to searching filename in workspace tree', () {
      final rootNode = FileNode(
        uri: tempDir.path,
        name: 'root',
        path: '',
        isDirectory: true,
        children: [
          FileNode(
            uri: audioFile.path,
            name: 'memo_01.m4a',
            path: 'Assets/VoiceNotes/memo_01.m4a',
            isDirectory: false,
          ),
        ],
      );

      final resolved = AssetResolverService.resolvePath(
        rawPath: 'memo_01.m4a',
        workspaceTree: rootNode,
      );

      expect(resolved, audioFile.path);
    });

    test('returns null for empty path', () {
      final resolved = AssetResolverService.resolvePath(
        rawPath: '   ',
        currentDocUri: noteFile.path,
      );
      expect(resolved, isNull);
    });
  });

  group('Audio State Models Tests', () {
    test('AudioPlaybackState default and copyWith work as expected', () {
      const state = AudioPlaybackState();
      expect(state.isPlaying, isFalse);
      expect(state.activeUri, isNull);
      expect(state.playbackSpeed, 1.0);

      final updated = state.copyWith(
        activeUri: '/test/audio.m4a',
        status: AudioPlaybackStatus.playing,
        playbackSpeed: 1.5,
        duration: const Duration(seconds: 45),
        position: const Duration(seconds: 15),
      );

      expect(updated.activeUri, '/test/audio.m4a');
      expect(updated.isPlaying, isTrue);
      expect(updated.playbackSpeed, 1.5);
      expect(updated.duration.inSeconds, 45);
      expect(updated.position.inSeconds, 15);
    });

    test('AudioRecordingState default and copyWith work as expected', () {
      const state = AudioRecordingState();
      expect(state.isRecording, isFalse);
      expect(state.status, AudioRecordingStatus.idle);
      expect(state.elapsed, Duration.zero);
      expect(state.currentAmplitude, 0.0);

      final updated = state.copyWith(
        status: AudioRecordingStatus.recording,
        elapsed: const Duration(seconds: 10),
        currentAmplitude: 0.8,
        recordedFilePath: '/test/audio.m4a',
      );

      expect(updated.isRecording, isTrue);
      expect(updated.elapsed.inSeconds, 10);
      expect(updated.currentAmplitude, 0.8);
      expect(updated.recordedFilePath, '/test/audio.m4a');
    });
  });

  group('Image Preprocessing Service Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('quill_img_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('cropBoundingBox accurately crops normalized [ymin, xmin, ymax, xmax]', () async {
      // Create a 1000x1000 test image with a red background
      final image = img.Image(width: 1000, height: 1000);
      img.fill(image, color: img.ColorRgba8(255, 0, 0, 255));
      final pngBytes = img.encodePng(image);

      final srcFile = File('${tempDir.path}/source.png')..writeAsBytesSync(pngBytes);
      final outDir = Directory('${tempDir.path}/out');

      // Crop normalized [100, 200, 500, 600] -> y: 100-500 (height 400), x: 200-600 (width 400)
      final result = await ImagePreprocessService.cropBoundingBox(
        sourceImagePath: srcFile.path,
        box2d: const [100, 200, 500, 600],
        outputDirectory: outDir.path,
        label: 'Flowchart',
      );

      expect(result, isNotNull);
      expect(result!.width, 400);
      expect(result.height, 400);
      expect(File(result.croppedFilePath).existsSync(), isTrue);

      final croppedImage = img.decodeImage(File(result.croppedFilePath).readAsBytesSync());
      expect(croppedImage, isNotNull);
      expect(croppedImage!.width, 400);
      expect(croppedImage.height, 400);
    });

    test('enhancePaperContrast applies contrast and saves enhanced image', () async {
      final image = img.Image(width: 200, height: 200);
      img.fill(image, color: img.ColorRgba8(200, 200, 190, 255));
      final pngBytes = img.encodePng(image);

      final srcFile = File('${tempDir.path}/paper.png')..writeAsBytesSync(pngBytes);
      final outFile = File('${tempDir.path}/paper_enhanced.jpg');

      final enhancedPath = await ImagePreprocessService.enhancePaperContrast(
        inputImagePath: srcFile.path,
        outputImagePath: outFile.path,
      );

      expect(enhancedPath, isNotNull);
      expect(File(enhancedPath!).existsSync(), isTrue);

      final decoded = img.decodeImage(File(enhancedPath).readAsBytesSync());
      expect(decoded, isNotNull);
      expect(decoded!.width, 200);
      expect(decoded.height, 200);
    });
  });

  group('JournalPageAnalysisResult Parsing Tests', () {
    test('parses clean valid JSON response from vision model', () {
      const jsonStr = '''
      {
        "transcribed_text": "Morning reflection: plan the system architecture.",
        "tags": ["planning", "architecture"],
        "artworks": [
          {
            "box_2d": [120, 150, 480, 800],
            "label": "Architecture diagram"
          }
        ]
      }
      ''';

      final result = JournalPageAnalysisResult.tryParseJson(jsonStr);
      expect(result, isNotNull);
      expect(result!.transcribedText, contains('Morning reflection'));
      expect(result.tags, ['planning', 'architecture']);
      expect(result.artworks.length, 1);
      expect(result.artworks.first.label, 'Architecture diagram');
      expect(result.artworks.first.box2d, [120, 150, 480, 800]);
    });

    test('parses fenced ```json markdown from LLM output', () {
      const fenced = '''
      Here is the extracted information from the journal page:
      ```json
      {
        "transcribed_text": "Sketched new UI layout.",
        "tags": [],
        "artworks": [
          {
            "box_2d": [50, 50, 300, 300],
            "label": "UI Layout wireframe"
          }
        ]
      }
      ```
      ''';

      final result = JournalPageAnalysisResult.tryParseJson(fenced);
      expect(result, isNotNull);
      expect(result!.transcribedText, 'Sketched new UI layout.');
      expect(result.artworks.length, 1);
      expect(result.artworks.first.label, 'UI Layout wireframe');
    });

    test('returns null for completely invalid JSON text', () {
      const invalid = 'I could not detect any text or drawings on this page.';
      final result = JournalPageAnalysisResult.tryParseJson(invalid);
      expect(result, isNull);
    });
  });

  group('Vault Directory Initialization and Daily Log Appending Tests', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.jessiejensen.quill_papyrus_ai/widget'),
        (MethodCall methodCall) async => null,
      );

      tempDir = Directory.systemTemp.createTempSync('quill_vault_test_');
      container = ProviderContainer();
      await container.read(workspaceProvider.notifier).loadWorkspace(tempDir.path);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.jessiejensen.quill_papyrus_ai/widget'),
        null,
      );
      container.dispose();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('ensureVaultDirectories creates all required folder structures', () async {
      final service = container.read(quickNoteServiceProvider);
      await service.ensureVaultDirectories();

      expect(Directory('${tempDir.path}/Daily-Logs').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/Assets/Sketches').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/Assets/VoiceNotes').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/Assets/Raw-Exports').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/Inbox-Dropzone').existsSync(), isTrue);
    });

    test('appendEntryToDailyNote appends entry with timestamp and updates frontmatter', () async {
      final service = container.read(quickNoteServiceProvider);
      final dailyPath = await service.openOrCreateDailyNote();
      expect(dailyPath, isNotNull);

      // Append an entry
      await service.appendEntryToDailyNote(
        sectionTitle: 'VoiceMemo_Test',
        content: 'Finished implementing voice recorder and image ingestion.',
        sourceTag: 'VoiceMemo_Test',
      );

      final fileContent = File(dailyPath!).readAsStringSync();
      expect(fileContent.contains('VoiceMemo_Test'), isTrue);
      expect(fileContent.contains('Finished implementing voice recorder and image ingestion.'), isTrue);
      expect(fileContent.contains('sources: [native, VoiceMemo_Test]'), isTrue);
    });
  });

  group('Media Cards Widget Tests', () {
    testWidgets('AudioPlayerCard displays title, playback controls and transcribe button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AudioPlayerCard(
                audioPath: '/vault/Assets/VoiceNotes/memo.m4a',
                title: 'Daily Voice Memo',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Daily Voice Memo'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('Transcribe'), findsOneWidget);
    });

    testWidgets('SourceOcrCard displays transcribed text and toggles split mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SourceOcrCard(
              imagePath: '/vault/Assets/Sketches/drawing.png',
              title: 'Journal Sketch 1',
              transcribedText: 'Detailed flowchart of architecture pipeline',
            ),
          ),
        ),
      );

      expect(find.text('Journal Sketch 1'), findsOneWidget);
      expect(find.text('Detailed flowchart of architecture pipeline'), findsOneWidget);
      expect(find.text('Verify OCR'), findsOneWidget);

      await tester.tap(find.text('Verify OCR'));
      await tester.pumpAndSettle();

      expect(find.text('Split OCR Active'), findsOneWidget);
    });
  });
}
