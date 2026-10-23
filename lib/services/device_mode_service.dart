import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceModeState {
  final bool isDeX;
  final bool isMultiWindow;

  const DeviceModeState({
    this.isDeX = false,
    this.isMultiWindow = false,
  });

  bool get isDeXOrMultiWindow => isDeX || isMultiWindow;
}

class DeviceModeNotifier extends StateNotifier<DeviceModeState> {
  static const MethodChannel _channel =
      MethodChannel('com.jessiejensen.quill_papyrus_ai/device_mode');

  DeviceModeNotifier([DeviceModeState? initialState])
      : super(initialState ?? const DeviceModeState()) {
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb || (!Platform.isAndroid)) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceModeChanged') {
        final data = call.arguments;
        if (data is Map) {
          final isDeX = data['isDeX'] == true;
          final isMultiWindow = data['isMultiWindow'] == true;
          state = DeviceModeState(isDeX: isDeX, isMultiWindow: isMultiWindow);
        }
      }
    });

    await refresh();
  }

  Future<void> refresh() async {
    if (kIsWeb || (!Platform.isAndroid)) return;
    try {
      final res = await _channel.invokeMethod<Map>('getDeviceMode');
      if (res != null) {
        final isDeX = res['isDeX'] == true;
        final isMultiWindow = res['isMultiWindow'] == true;
        state = DeviceModeState(isDeX: isDeX, isMultiWindow: isMultiWindow);
      }
    } catch (_) {}
  }
}

final deviceModeProvider =
    StateNotifierProvider<DeviceModeNotifier, DeviceModeState>((ref) {
  return DeviceModeNotifier();
});
