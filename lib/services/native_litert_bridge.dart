import 'dart:async';
import 'package:flutter/services.dart';

/// Direct Dart bridge to our native Android `LiteRtLmBridge` (calling `litertlm-android:0.10.0`
/// with explicit `maxNumTokens`, `visionBackend`, and `audioBackend`).
class NativeLiteRtBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.jessiejensen.quill_papyrus_ai/litert_lm');
  static const EventChannel _eventChannel =
      EventChannel('com.jessiejensen.quill_papyrus_ai/litert_lm_stream');

  Future<String> createEngine({
    required String modelPath,
    String backend = 'gpu',
    String? visionBackend,
    String? audioBackend,
    int? maxNumTokens,
    String? cacheDir,
  }) async {
    final id = await _methodChannel.invokeMethod<String>('createEngine', {
      'modelPath': modelPath,
      'backend': backend,
      'visionBackend': ?visionBackend,
      'audioBackend': ?audioBackend,
      'maxNumTokens': ?maxNumTokens,
      'cacheDir': ?cacheDir,
    });
    if (id == null || id.isEmpty) {
      throw StateError('Failed to create LiteRT-LM engine');
    }
    return id;
  }

  Future<void> disposeEngine(String engineId) async {
    await _methodChannel.invokeMethod('disposeEngine', {'engineId': engineId});
  }

  Future<String> createConversation({
    required String engineId,
    String? systemInstruction,
    List<Map<String, String>>? initialMessages,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
  }) async {
    final id = await _methodChannel.invokeMethod<String>('createConversation', {
      'engineId': engineId,
      'config': {
        if (systemInstruction != null && systemInstruction.isNotEmpty)
          'systemInstruction': systemInstruction,
        if (initialMessages != null && initialMessages.isNotEmpty)
          'initialMessages': initialMessages,
        'samplerConfig': {
          'temperature': temperature,
          'topP': topP,
          'topK': topK,
        },
      },
    });
    if (id == null || id.isEmpty) {
      throw StateError('Failed to create LiteRT-LM conversation');
    }
    return id;
  }

  Future<void> disposeConversation(String conversationId) async {
    await _methodChannel.invokeMethod(
      'disposeConversation',
      {'conversationId': conversationId},
    );
  }

  Future<String> sendMessage({
    required String conversationId,
    required List<Map<String, dynamic>> contents,
  }) async {
    final result = await _methodChannel.invokeMethod<Map>('sendMessage', {
      'conversationId': conversationId,
      'contents': contents,
    });
    return (result?['text'] as String?) ?? '';
  }

  Stream<String> sendMessageStream({
    required String conversationId,
    required List<Map<String, dynamic>> contents,
  }) {
    final controller = StreamController<String>();
    StreamSubscription<dynamic>? sub;

    sub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final eventConvId = event['conversationId']?.toString();
          if (eventConvId != null && eventConvId != conversationId) return;
          final isDone = event['done'] == true;
          final text = event['text']?.toString() ?? '';
          if (text.isNotEmpty && !controller.isClosed) {
            controller.add(text);
          }
          if (isDone) {
            sub?.cancel();
            if (!controller.isClosed) controller.close();
          }
        }
      },
      onError: (Object err, StackTrace st) {
        if (!controller.isClosed) {
          controller.addError(err, st);
          controller.close();
        }
        sub?.cancel();
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    _methodChannel.invokeMethod('startMessageStream', {
      'conversationId': conversationId,
      'contents': contents,
    }).catchError((Object err, StackTrace st) {
      if (!controller.isClosed) {
        controller.addError(err, st);
        controller.close();
      }
      sub?.cancel();
    });

    controller.onCancel = () {
      sub?.cancel();
    };

    return controller.stream;
  }
}
