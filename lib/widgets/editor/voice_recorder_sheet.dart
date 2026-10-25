import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/audio_playback_service.dart';
import 'package:quill_papyrus_ai/services/audio_recording_service.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';

class VoiceRecorderSheet extends ConsumerStatefulWidget {
  const VoiceRecorderSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceRecorderSheet(),
    );
  }

  @override
  ConsumerState<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends ConsumerState<VoiceRecorderSheet> {
  bool _isSavingOrTranscribing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initiateRecording());
  }

  Future<void> _initiateRecording() async {
    final dirs = await ref.read(quickNoteServiceProvider).ensureVaultDirectories();
    final voiceDir = dirs['voiceNotes']!;

    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final targetPath = p.join(voiceDir, 'Voice_$timestamp.m4a');

    await ref.read(audioRecordingProvider.notifier).startRecording(targetPath);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleSaveRaw(String filePath) async {
    if (_isSavingOrTranscribing) return;
    setState(() {
      _isSavingOrTranscribing = true;
      _statusMessage = 'Saving raw voice memo...';
    });

    try {
      final fileName = p.basename(filePath);
      final relPath = 'Assets/VoiceNotes/$fileName';
      final mediaEmbed = '![[$relPath]]';

      final activeTab = ref.read(editorProvider).activeTab;
      if (activeTab != null) {
        final currentContent = activeTab.content;
        final separator = currentContent.endsWith('\n\n')
            ? ''
            : currentContent.endsWith('\n')
                ? '\n'
                : '\n\n';
        final newContent = '$currentContent$separator$mediaEmbed\n';
        ref.read(editorProvider.notifier).updateActiveTabContent(newContent);
        await ref.read(editorProvider.notifier).saveCurrentTab();
      } else {
        await ref.read(quickNoteServiceProvider).appendEntryToDailyNote(
          sectionTitle: 'Voice Memo',
          content: mediaEmbed,
          sourceTag: 'voice',
        );
      }

      await ref.read(workspaceProvider.notifier).refreshWorkspace();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          content: Text(
            'Raw voice memo saved to note: $fileName',
            style: TextStyle(color: GruvboxColors.green),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingOrTranscribing = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _handleSaveAndTranscribe(String filePath) async {
    if (_isSavingOrTranscribing) return;
    setState(() {
      _isSavingOrTranscribing = true;
      _statusMessage = 'Transcribing voice memo with AI...';
    });

    try {
      final file = File(filePath);
      final fileName = p.basename(filePath);
      final relPath = 'Assets/VoiceNotes/$fileName';
      final mediaEmbed = '![[$relPath]]';

      // Run AI audio transcription
      final transcription = await ref.read(aiProvider.notifier).transcribeAudioFile(file);

      final combinedContent = '''$mediaEmbed

### Transcription
$transcription
''';

      final activeTab = ref.read(editorProvider).activeTab;
      if (activeTab != null) {
        final currentContent = activeTab.content;
        final separator = currentContent.endsWith('\n\n')
            ? ''
            : currentContent.endsWith('\n')
                ? '\n'
                : '\n\n';
        final newContent = '$currentContent$separator$combinedContent';
        ref.read(editorProvider.notifier).updateActiveTabContent(newContent);
        await ref.read(editorProvider.notifier).saveCurrentTab();
      } else {
        await ref.read(quickNoteServiceProvider).appendEntryToDailyNote(
          sectionTitle: 'Voice Memo (Transcribed)',
          content: combinedContent,
          sourceTag: 'voice',
        );
      }

      await ref.read(workspaceProvider.notifier).refreshWorkspace();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          content: Text(
            'Voice memo transcribed & added to note: $fileName',
            style: TextStyle(color: GruvboxColors.green),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingOrTranscribing = false;
          _statusMessage = 'Transcription error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(audioRecordingProvider);
    final isRecording = recordingState.isRecording;
    final isPaused = recordingState.isPaused;
    final isStopped = recordingState.isStopped;
    final filePath = recordingState.recordedFilePath;

    return FrostedChrome(
      blur: 24,
      backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.95),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(color: GruvboxColors.hairlineBorder, width: 0.75),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Bar
              Row(
                children: [
                  Icon(
                    isRecording ? Icons.fiber_manual_record : Icons.mic,
                    color: isRecording ? GruvboxColors.red : GruvboxColors.aqua,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isStopped ? 'Voice Memo Ready' : 'Voice Memo Recorder',
                    style: TextStyle(
                      color: GruvboxColors.fg0,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  TactilePressable(
                    tooltip: 'Cancel Recording',
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await ref.read(audioRecordingProvider.notifier).cancelRecording();
                      nav.pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close, size: 20, color: GruvboxColors.gray),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Timer & Dynamic Audio Waveform
              Center(
                child: Column(
                  children: [
                    Text(
                      _formatDuration(recordingState.elapsed),
                      style: TextStyle(
                        color: isRecording ? GruvboxColors.red : GruvboxColors.fg,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Animated Waveform Bars
                    SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(15, (index) {
                          final baseHeight = isRecording
                              ? (8.0 + (recordingState.currentAmplitude * 32.0 * ((index % 3 + 1) / 3)))
                              : (isPaused ? 6.0 : 4.0);
                          return Container(
                            width: 3.5,
                            height: baseHeight.clamp(4.0, 42.0),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            decoration: BoxDecoration(
                              color: isRecording
                                  ? GruvboxColors.aqua.withValues(alpha: 0.8)
                                  : GruvboxColors.bg3,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (recordingState.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GruvboxColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GruvboxColors.red.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    recordingState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: GruvboxColors.red, fontSize: 11),
                  ),
                ),

              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: GruvboxColors.aqua),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _statusMessage!,
                        style: TextStyle(color: GruvboxColors.aqua, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // Controls based on state: While Recording vs. Stopped/Ready
              if (!isStopped) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Pause / Resume
                    TactilePressable(
                      tooltip: isPaused ? 'Resume' : 'Pause',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (isPaused) {
                          ref.read(audioRecordingProvider.notifier).resumeRecording();
                        } else {
                          ref.read(audioRecordingProvider.notifier).pauseRecording();
                        }
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg2,
                          shape: BoxShape.circle,
                          border: Border.all(color: GruvboxColors.bg3),
                        ),
                        child: Icon(
                          isPaused ? Icons.play_arrow : Icons.pause,
                          color: GruvboxColors.fg,
                          size: 24,
                        ),
                      ),
                    ),

                    // Stop / Complete Recording
                    TactilePressable(
                      tooltip: 'Stop & Review Options',
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await ref.read(audioRecordingProvider.notifier).stopRecording();
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: GruvboxColors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: GruvboxColors.red.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.stop, color: Colors.white, size: 30),
                      ),
                    ),

                    // Cancel
                    TactilePressable(
                      tooltip: 'Cancel & Discard',
                      onTap: () async {
                        final nav = Navigator.of(context);
                        HapticFeedback.lightImpact();
                        await ref.read(audioRecordingProvider.notifier).cancelRecording();
                        nav.pop();
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg2,
                          shape: BoxShape.circle,
                          border: Border.all(color: GruvboxColors.bg3),
                        ),
                        child: Icon(Icons.delete_outline, color: GruvboxColors.gray, size: 22),
                      ),
                    ),
                  ],
                ),
              ] else if (filePath != null) ...[
                // Choice Row: Save as Raw vs. Transcribe with AI
                Row(
                  children: [
                    // Preview Playback Button
                    TactilePressable(
                      tooltip: 'Preview Recording',
                      onTap: () {
                        ref.read(audioPlaybackProvider.notifier).playOrToggle(filePath);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GruvboxColors.bg3),
                        ),
                        child: Icon(Icons.play_arrow, color: GruvboxColors.aqua, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Option A: Save as Raw Voice Note
                    Expanded(
                      child: TactilePressable(
                        tooltip: 'Embed audio player without text transcription',
                        onTap: _isSavingOrTranscribing ? null : () => _handleSaveRaw(filePath),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GruvboxColors.yellow.withValues(alpha: 0.6)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bookmark_border, size: 16, color: GruvboxColors.yellow),
                              const SizedBox(width: 6),
                              Text(
                                'Save Raw',
                                style: TextStyle(
                                  color: GruvboxColors.yellow,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Option B: Transcribe with AI
                    Expanded(
                      child: TactilePressable(
                        tooltip: 'Transcribe spoken audio into markdown text',
                        onTap: _isSavingOrTranscribing ? null : () => _handleSaveAndTranscribe(filePath),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: GruvboxColors.aqua,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: GruvboxColors.aqua.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.auto_awesome, size: 16, color: Colors.black87),
                              const SizedBox(width: 6),
                              const Text(
                                'Transcribe AI',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
