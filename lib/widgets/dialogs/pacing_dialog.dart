import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/pacing_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class PacingDialog extends ConsumerStatefulWidget {
  const PacingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const PacingDialog(),
    );
  }

  @override
  ConsumerState<PacingDialog> createState() => _PacingDialogState();
}

class _PacingDialogState extends ConsumerState<PacingDialog> {
  late TextEditingController _msTargetController;
  late TextEditingController _dailyTargetController;

  @override
  void initState() {
    super.initState();
    final target = ref.read(pacingProvider).target;
    _msTargetController = TextEditingController(text: target.targetManuscriptWords.toString());
    _dailyTargetController = TextEditingController(text: target.targetDailyWords.toString());
  }

  @override
  void dispose() {
    _msTargetController.dispose();
    _dailyTargetController.dispose();
    super.dispose();
  }

  Future<void> _saveTargets() async {
    final msWords = int.tryParse(_msTargetController.text.trim()) ?? 80000;
    final dailyWords = int.tryParse(_dailyTargetController.text.trim()) ?? 1500;

    await ref.read(pacingProvider.notifier).updateTarget(
          manuscriptWords: msWords,
          dailyWords: dailyWords,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pacing = ref.watch(pacingProvider);
    final target = pacing.target;
    final history = pacing.recentHistory;
    final totalWords = pacing.totalManuscriptWords;
    final readingHours = target.estimatedReadingHours(totalWords);

    return Dialog(
      backgroundColor: GruvboxColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: GruvboxColors.bg3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.speed, color: GruvboxColors.yellow, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Writing Quotas & Pacing Tracker',
                    style: TextStyle(
                      color: GruvboxColors.fg0,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Overview Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Manuscript',
                      value: '$totalWords words',
                      subvalue: '${(pacing.manuscriptProgress * 100).toStringAsFixed(1)}% of goal',
                      color: GruvboxColors.aqua,
                      progress: pacing.manuscriptProgress,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: "Today's Net Gain",
                      value: '${pacing.todayNetWords} words',
                      subvalue: '${(pacing.dailyProgress * 100).toStringAsFixed(1)}% of daily quota',
                      color: pacing.dailyProgress >= 1.0 ? GruvboxColors.green : GruvboxColors.yellow,
                      progress: pacing.dailyProgress,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Estimated Reading',
                      value: '${readingHours.toStringAsFixed(1)} hrs',
                      subvalue: 'At 250 wpm',
                      color: GruvboxColors.purple,
                      progress: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Target Inputs
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manuscript Target Words', style: TextStyle(color: GruvboxColors.gray, fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg1,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GruvboxColors.bg3),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _msTargetController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                            cursorColor: GruvboxColors.yellow,
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Session Target Words', style: TextStyle(color: GruvboxColors.gray, fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg1,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GruvboxColors.bg3),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _dailyTargetController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                            cursorColor: GruvboxColors.yellow,
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GruvboxColors.yellow,
                        foregroundColor: GruvboxColors.bg,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: _saveTargets,
                      child: const Text('Update Goals'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recent Writing History
              Text(
                'Recent Writing History (Daily Net Words)',
                style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg1,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GruvboxColors.bg3),
                  ),
                  child: history.isEmpty
                      ? Center(
                          child: Text(
                            'Start writing today to track your daily progress logs!',
                            style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                          ),
                        )
                      : ListView.separated(
                          itemCount: history.length,
                          separatorBuilder: (ctx, i) => Divider(color: GruvboxColors.bg2, height: 1),
                          itemBuilder: (context, index) {
                            final session = history[index];
                            final isMet = session.netWords >= target.targetDailyWords;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    isMet ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: isMet ? GruvboxColors.green : GruvboxColors.yellow,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    session.date,
                                    style: TextStyle(
                                      color: GruvboxColors.fg,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '+${session.wordsWritten} / -${session.wordsDeleted}',
                                    style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Net: ${session.netWords} words',
                                    style: TextStyle(
                                      color: session.netWords >= 0 ? GruvboxColors.green : GruvboxColors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subvalue,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GruvboxColors.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: GruvboxColors.gray, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(subvalue, style: TextStyle(color: GruvboxColors.gray, fontSize: 10)),
        ],
      ),
    );
  }
}
