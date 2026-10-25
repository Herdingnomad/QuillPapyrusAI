import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/audio_playback_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';

class AudioPlayerCard extends ConsumerStatefulWidget {
  final String audioPath;
  final String? title;
  final VoidCallback? onTranscriptionComplete;

  const AudioPlayerCard({
    super.key,
    required this.audioPath,
    this.title,
    this.onTranscriptionComplete,
  });

  @override
  ConsumerState<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends ConsumerState<AudioPlayerCard> {
  bool _isTranscribing = false;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _handleTranscribe() async {
    if (_isTranscribing) return;
    setState(() => _isTranscribing = true);
    HapticFeedback.mediumImpact();

    try {
      final file = File(widget.audioPath);
      final fileName = p.basename(widget.audioPath);

      // Call AI Service to transcribe audio
      final transcription = await ref.read(aiProvider.notifier).transcribeAudioFile(file);

      if (!mounted) return;

      // Insert transcribed text right below the audio tag in the active document if open
      final activeTab = ref.read(editorProvider).activeTab;
      if (activeTab != null) {
        final currentContent = activeTab.content;
        final escapedPath = RegExp.escape(p.basename(widget.audioPath));
        final audioPattern = RegExp(r'(!\[\[.*?' + escapedPath + r'.*?\]\]|\[.*?\]\(.*?' + escapedPath + r'.*?\))');

        String newContent;
        final transcribedBlock = '\n\n### Transcription\n$transcription\n';

        if (audioPattern.hasMatch(currentContent)) {
          newContent = currentContent.replaceFirstMapped(audioPattern, (m) {
            return '${m.group(0)}$transcribedBlock';
          });
        } else {
          newContent = '$currentContent\n$transcribedBlock';
        }

        ref.read(editorProvider.notifier).updateActiveTabContent(newContent);
        await ref.read(editorProvider.notifier).saveCurrentTab();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          content: Text(
            'Transcription complete for $fileName',
            style: TextStyle(color: GruvboxColors.green),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      widget.onTranscriptionComplete?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            content: Text(
              'Transcription failed: $e',
              style: TextStyle(color: GruvboxColors.red),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(audioPlaybackProvider);
    final isThisAudioActive = playbackState.activeUri == widget.audioPath;
    final isPlaying = isThisAudioActive && playbackState.isPlaying;

    final currentPosition = isThisAudioActive ? playbackState.position : Duration.zero;
    final totalDuration = isThisAudioActive ? playbackState.duration : Duration.zero;

    final fileName = widget.title ?? p.basename(widget.audioPath);
    final file = File(widget.audioPath);
    final fileExists = file.existsSync();

    final maxMilliseconds = totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds.toDouble() : 1.0;
    final currentMilliseconds = currentPosition.inMilliseconds.toDouble().clamp(0.0, maxMilliseconds);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying ? GruvboxColors.aqua.withValues(alpha: 0.6) : GruvboxColors.bg3,
          width: isPlaying ? 1.25 : 1.0,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: GruvboxColors.aqua.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Audio Icon, Title, and Speed / Transcribe Actions
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? GruvboxColors.aqua.withValues(alpha: 0.2)
                      : GruvboxColors.bg2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  size: 16,
                  color: isPlaying ? GruvboxColors.aqua : GruvboxColors.fg4,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GruvboxColors.fg0,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      fileExists ? 'Voice Memo • ${_formatDuration(totalDuration)}' : 'File missing on device',
                      style: TextStyle(
                        color: fileExists ? GruvboxColors.gray : GruvboxColors.red,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Playback Speed button
              TactilePressable(
                tooltip: 'Playback Speed',
                onTap: () {
                  final speeds = [1.0, 1.25, 1.5, 2.0];
                  final currentIndex = speeds.indexOf(playbackState.playbackSpeed);
                  final nextSpeed = speeds[(currentIndex + 1) % speeds.length];
                  ref.read(audioPlaybackProvider.notifier).setPlaybackSpeed(nextSpeed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GruvboxColors.bg3, width: 0.75),
                  ),
                  child: Text(
                    '${playbackState.playbackSpeed}x',
                    style: TextStyle(
                      color: GruvboxColors.fg3,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Transcribe with AI Button
              TactilePressable(
                tooltip: 'Transcribe audio with AI',
                onTap: _isTranscribing ? null : _handleTranscribe,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GruvboxColors.yellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GruvboxColors.yellow.withValues(alpha: 0.5), width: 0.75),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isTranscribing)
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: GruvboxColors.yellow,
                          ),
                        )
                      else
                        Icon(Icons.auto_awesome, size: 12, color: GruvboxColors.yellow),
                      const SizedBox(width: 4),
                      Text(
                        _isTranscribing ? 'Transcribing...' : 'Transcribe',
                        style: TextStyle(
                          color: GruvboxColors.yellow,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Player Controls Row: Play/Pause, Scrubber Slider, and Time Label
          Row(
            children: [
              // Play/Pause Button
              TactilePressable(
                tooltip: isPlaying ? 'Pause' : 'Play',
                onTap: fileExists
                    ? () {
                        HapticFeedback.selectionClick();
                        ref.read(audioPlaybackProvider.notifier).playOrToggle(widget.audioPath);
                      }
                    : null,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: fileExists ? GruvboxColors.aqua : GruvboxColors.bg3,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 20,
                    color: GruvboxColors.bgHard,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Scrubber
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3.5,
                    activeTrackColor: GruvboxColors.aqua,
                    inactiveTrackColor: GruvboxColors.bg3,
                    thumbColor: GruvboxColors.aqua,
                    overlayColor: GruvboxColors.aqua.withValues(alpha: 0.2),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: currentMilliseconds,
                    min: 0.0,
                    max: maxMilliseconds,
                    onChanged: (val) {
                      if (isThisAudioActive) {
                        ref.read(audioPlaybackProvider.notifier).seek(Duration(milliseconds: val.toInt()));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Current / Duration Time Label
              Text(
                '${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)}',
                style: TextStyle(
                  color: GruvboxColors.gray,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
