import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

enum AudioRecordingStatus { idle, recording, paused, stopped }

class AudioRecordingState {
  final AudioRecordingStatus status;
  final Duration elapsed;
  final double currentAmplitude;
  final String? recordedFilePath;
  final String? errorMessage;

  const AudioRecordingState({
    this.status = AudioRecordingStatus.idle,
    this.elapsed = Duration.zero,
    this.currentAmplitude = 0.0,
    this.recordedFilePath,
    this.errorMessage,
  });

  bool get isRecording => status == AudioRecordingStatus.recording;
  bool get isPaused => status == AudioRecordingStatus.paused;
  bool get isIdle => status == AudioRecordingStatus.idle;
  bool get isStopped => status == AudioRecordingStatus.stopped;

  AudioRecordingState copyWith({
    AudioRecordingStatus? status,
    Duration? elapsed,
    double? currentAmplitude,
    String? recordedFilePath,
    String? errorMessage,
    bool clearError = false,
    bool clearPath = false,
  }) {
    return AudioRecordingState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      currentAmplitude: currentAmplitude ?? this.currentAmplitude,
      recordedFilePath: clearPath ? null : (recordedFilePath ?? this.recordedFilePath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AudioRecordingNotifier extends StateNotifier<AudioRecordingState> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  StreamSubscription<Amplitude>? _ampSub;

  AudioRecordingNotifier() : super(const AudioRecordingState());

  Future<bool> startRecording(String destinationFilePath) async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(errorMessage: 'Microphone permission denied.');
        return false;
      }

      // Ensure target directory exists
      final targetDir = Directory(p.dirname(destinationFilePath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // If file already exists, delete it first
      final file = File(destinationFilePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: destinationFilePath,
      );

      _startTimer();
      _startAmplitudeTracking();

      state = state.copyWith(
        status: AudioRecordingStatus.recording,
        elapsed: Duration.zero,
        currentAmplitude: 0.0,
        recordedFilePath: destinationFilePath,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        status: AudioRecordingStatus.idle,
        errorMessage: 'Failed to start recording: $e',
      );
      return false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && state.isRecording) {
        state = state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
      }
    });
  }

  void _startAmplitudeTracking() {
    _ampSub?.cancel();
    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
      if (mounted && state.isRecording) {
        // amp.current is typically in dB (e.g. -160 to 0)
        // Normalize roughly to 0.0 - 1.0 for UI waveforms
        final normalized = ((amp.current + 50.0) / 50.0).clamp(0.0, 1.0);
        state = state.copyWith(currentAmplitude: normalized);
      }
    });
  }

  Future<void> pauseRecording() async {
    try {
      if (state.isRecording) {
        await _recorder.pause();
        state = state.copyWith(status: AudioRecordingStatus.paused);
      }
    } catch (_) {}
  }

  Future<void> resumeRecording() async {
    try {
      if (state.isPaused) {
        await _recorder.resume();
        state = state.copyWith(status: AudioRecordingStatus.recording);
      }
    } catch (_) {}
  }

  Future<String?> stopRecording() async {
    try {
      _timer?.cancel();
      _ampSub?.cancel();
      final path = await _recorder.stop();
      state = state.copyWith(
        status: AudioRecordingStatus.stopped,
        recordedFilePath: path ?? state.recordedFilePath,
      );
      return path ?? state.recordedFilePath;
    } catch (e) {
      state = state.copyWith(
        status: AudioRecordingStatus.idle,
        errorMessage: 'Failed to stop recording: $e',
      );
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _timer?.cancel();
      _ampSub?.cancel();
      final path = state.recordedFilePath;
      await _recorder.cancel();

      if (path != null) {
        final f = File(path);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }

      state = const AudioRecordingState();
    } catch (_) {
      state = const AudioRecordingState();
    }
  }

  void reset() {
    _timer?.cancel();
    _ampSub?.cancel();
    state = const AudioRecordingState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}

final audioRecordingProvider = StateNotifierProvider<AudioRecordingNotifier, AudioRecordingState>((ref) {
  return AudioRecordingNotifier();
});
