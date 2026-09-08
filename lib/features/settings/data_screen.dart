import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_theme.dart';
import '../../core/day_key.dart';
import '../../core/widgets.dart';
import '../../providers.dart';

class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;

  /// Everything the app holds, as one JSON file the user owns.
  Future<Map<String, Object?>> _buildExport() async {
    final habits = await ref.read(habitRepositoryProvider).allHabits(
          includeArchived: true,
        );
    final sessions = await ref.read(sessionRepositoryProvider).exportRows();
    final logs = <Map<String, Object?>>[];
    for (final habit in habits) {
      for (final day in await ref
          .read(habitRepositoryProvider)
          .completedDays(habit.id)) {
        logs.add({'habit_id': habit.id, 'day': day});
      }
    }
    return {
      'app': 'Pomo Sauce',
      'exported_at': DateTime.now().toIso8601String(),
      'schema_version': 1,
      'habits': habits.map((h) => h.toRow()).toList(),
      'habit_logs': logs,
      'sessions': sessions,
    };
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = const JsonEncoder.withIndent('  ').convert(await _buildExport());
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, 'pomo-sauce-${DayKey.today()}.json'),
      );
      await file.writeAsString(json);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Pomo Sauce data export',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'Every habit, streak and session in this app will be permanently '
          'removed. Export first if you want a copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    await ref.read(pomodoroProvider.notifier).stop(recordPartial: false);
    await ref.read(bootstrapProvider).database.wipe();
    ref.invalidate(habitProgressProvider);
    ref.invalidate(habitsProvider);
    ref.invalidate(heatmapProvider);
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(weeklyChartProvider);
    ref.invalidate(totalSessionsProvider);
    ref.invalidate(sessionsOnDayProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('All data deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export',
                  style: context.texts.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Saves your habits, streaks and full session history as a '
                  'single JSON file you can keep anywhere.',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.tokens.textMuted, height: 1.45),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Export my data'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset',
                  style: context.texts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colors.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deletes everything stored on this device. There is no '
                  'server copy, so this cannot be undone.',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.tokens.textMuted, height: 1.45),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.error,
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete all data'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
