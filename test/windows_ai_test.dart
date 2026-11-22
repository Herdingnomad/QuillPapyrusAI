import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/ai_model_config.dart';
import 'package:quill_papyrus_ai/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Windows AI Engine and Model Discovery Tests', () {
    final aiService = AiService();

    test('Discovers Windows llama-server binary if LM Studio or PATH is available', () {
      if (!Platform.isWindows) return;
      final server = AiService.findWindowsLlamaServer();
      if (server == null) return; // Machine does not have local LM Studio installed
      expect(File(server).existsSync(), isTrue);
      expect(p.basename(server).toLowerCase(), equals('llama-server.exe'));
    });

    test('Discovers local GGUF models on Windows and filters out mmproj files', () async {
      if (!Platform.isWindows) return;
      final models = await aiService.findLocalModelFiles();
      if (models.isEmpty) return; // Machine has no local .gguf files installed
      for (final m in models) {
        expect(m.path.toLowerCase().endsWith('.gguf'), isTrue);
        expect(p.basename(m.path).toLowerCase().startsWith('mmproj-'), isFalse);
      }
    });

    test('Resolves E2B and E4B models on Windows correctly', () async {
      if (!Platform.isWindows) return;
      final models = await aiService.findLocalModelFiles();
      if (models.isEmpty) return;

      final path2B = await aiService.resolveModelPath(
        const AiModelConfig(modelType: GemmaModelType.gemma4E2B),
      );
      if (path2B != null) {
        expect(path2B.toLowerCase().contains('2b'), isTrue);
        expect(File(path2B).existsSync(), isTrue);
      }

      final path4B = await aiService.resolveModelPath(
        const AiModelConfig(modelType: GemmaModelType.gemma4E4B),
      );
      if (path4B != null) {
        expect(path4B.toLowerCase().contains('4b'), isTrue);
        expect(File(path4B).existsSync(), isTrue);
      }
    });

    test('Custom GGUF model path takes precedence when specified and exists', () async {
      final tempDir = Directory.systemTemp.createTempSync('quill_gguf_test_');
      try {
        final dummyGguf = File(p.join(tempDir.path, 'gemma-4-E2B-it-Q4_K_M.gguf'));
        dummyGguf.writeAsStringSync('dummy-gguf-content');

        final resolved = await aiService.resolveModelPath(
          AiModelConfig(
            modelType: GemmaModelType.customGGUF,
            customModelPath: dummyGguf.path,
          ),
        );
        expect(resolved, equals(dummyGguf.path));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
