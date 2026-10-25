import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AudioPlaybackStatus { stopped, playing, paused }

class AudioPlaybackState {
  final String? activeUri;
  final AudioPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final double playbackSpeed;
  final String? errorMessage;

  const AudioPlaybackState({
    this.activeUri,
    this.status = AudioPlaybackStatus.stopped,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackSpeed = 1.0,
    this.errorMessage,
  });

  bool get isPlaying => status == AudioPlaybackStatus.playing;
  bool get isPaused => status == AudioPlaybackStatus.paused;

  AudioPlaybackState copyWith({
    String? activeUri,
    AudioPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    double? playbackSpeed,
    String? errorMessage,
    bool clearActive = false,
  }) {
    return AudioPlaybackState(
      activeUri: clearActive ? null : (activeUri ?? this.activeUri),
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorMessage: errorMessage,
    );
  }
}

class AudioPlaybackNotifier extends StateNotifier<AudioPlaybackState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  AudioPlaybackNotifier() : super(const AudioPlaybackState()) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) {
        state = state.copyWith(position: pos);
      }
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted) {
        state = state.copyWith(duration: dur);
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((pState) {
      if (!mounted) return;
      switch (pState) {
        case PlayerState.playing:
          state = state.copyWith(status: AudioPlaybackStatus.playing);
          break;
        case PlayerState.paused:
          state = state.copyWith(status: AudioPlaybackStatus.paused);
          break;
        case PlayerState.completed:
          state = state.copyWith(
            status: AudioPlaybackStatus.stopped,
            position: Duration.zero,
          );
          break;
        case PlayerState.stopped:
          state = state.copyWith(status: AudioPlaybackStatus.stopped);
          break;
        default:
          break;
      }
    });
  }

  Future<void> playOrToggle(String filePath) async {
    try {
      if (state.activeUri == filePath) {
        if (state.isPlaying) {
          await pause();
        } else if (state.isPaused) {
          await resume();
        } else {
          await _startPlay(filePath);
        }
      } else {
        await _startPlay(filePath);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Playback error: $e');
      }
    }
  }

  Future<void> _startPlay(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      state = state.copyWith(errorMessage: 'File does not exist: $filePath');
      return;
    }

    await _player.stop();
    state = state.copyWith(
      activeUri: filePath,
      status: AudioPlaybackStatus.playing,
      position: Duration.zero,
      duration: Duration.zero,
      errorMessage: null,
    );

    await _player.setPlaybackRate(state.playbackSpeed);
    await _player.play(DeviceFileSource(filePath));
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      if (mounted) {
        state = state.copyWith(status: AudioPlaybackStatus.paused);
      }
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _player.resume();
      if (mounted) {
        state = state.copyWith(status: AudioPlaybackStatus.playing);
      }
    } catch (_) {}
  }

  Future<void> seek(Duration pos) async {
    try {
      await _player.seek(pos);
      if (mounted) {
        state = state.copyWith(position: pos);
      }
    } catch (_) {}
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _player.setPlaybackRate(speed);
      if (mounted) {
        state = state.copyWith(playbackSpeed: speed);
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      if (mounted) {
        state = state.copyWith(
          status: AudioPlaybackStatus.stopped,
          position: Duration.zero,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final audioPlaybackProvider = StateNotifierProvider<AudioPlaybackNotifier, AudioPlaybackState>((ref) {
  return AudioPlaybackNotifier();
});
