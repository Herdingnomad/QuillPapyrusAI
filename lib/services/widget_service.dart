import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.jessiejensen.quill_papyrus_ai/widget');

  final StreamController<String> _actionController = StreamController<String>.broadcast();
  Stream<String> get actionStream => _actionController.stream;

  WidgetService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onActionReceived') {
        final action = call.arguments as String?;
        if (action != null && action.isNotEmpty) {
          _actionController.add(action);
        }
      }
    });
  }

  /// Checks if the app was launched via a widget action or deep-link
  Future<String?> getInitialAction() async {
    try {
      final String? action = await _channel.invokeMethod<String>('getInitialAction');
      return action;
    } catch (_) {
      return null;
    }
  }

  /// Updates the Android home screen widget with the latest note title and excerpt
  Future<void> updateWidgetData({
    required String title,
    required String snippet,
  }) async {
    try {
      await _channel.invokeMethod('updateWidgetData', {
        'title': title,
        'snippet': snippet,
      });
    } catch (_) {
      // Ignore if platform not supported
    }
  }

  /// Persists the active workspace root path so QuickCaptureActivity and notifications write to the same directory
  Future<void> updateWorkspaceRoot(String path) async {
    try {
      await _channel.invokeMethod('updateWorkspaceRoot', {'root': path});
    } catch (_) {}
  }

  /// Displays or refreshes the persistent quick note notification with inline RemoteInput field
  Future<void> showQuickNoteNotification() async {
    try {
      await _channel.invokeMethod('showQuickNoteNotification');
    } catch (_) {}
  }

  /// Dismisses the persistent quick note notification
  Future<void> cancelQuickNoteNotification() async {
    try {
      await _channel.invokeMethod('cancelQuickNoteNotification');
    } catch (_) {}
  }

  void dispose() {
    _actionController.close();
  }
}

final widgetServiceProvider = Provider<WidgetService>((ref) {
  final service = WidgetService();
  ref.onDispose(service.dispose);
  return service;
});
