import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../data/models/timer_preset.dart';
import '../../providers.dart';

class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presets'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                ref.read(presetsProvider.notifier).restoreDefaults();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'reset',
                child: Text('Restore default presets'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New preset'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final preset = presets[i];
          return SectionCard(
            onTap: () => _edit(context, ref, preset),
            child: Row(
              children: [
                Text(preset.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              preset.name,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (preset.builtIn) ...[
                            const SizedBox(width: 8),
                            const TagChip(label: 'Built in', dense: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.summary,
                        style: context.texts.bodySmall
                            ?.copyWith(color: context.tokens.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          );
        },
      ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref, TimerPreset? preset) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PresetEditor(preset: preset),
    );
  }
}

class _PresetEditor extends ConsumerStatefulWidget {
  const _PresetEditor({this.preset});

  final TimerPreset? preset;

  @override
  ConsumerState<_PresetEditor> createState() => _PresetEditorState();
}

class _PresetEditorState extends ConsumerState<_PresetEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.preset?.name ?? '');
  late int _focus = widget.preset?.focusMinutes ?? 25;
  late int _short = widget.preset?.shortBreakMinutes ?? 5;
  late int _long = widget.preset?.longBreakMinutes ?? 15;
  late int _cycles = widget.preset?.sessionsBeforeLongBreak ?? 4;
  late String _emoji = widget.preset?.emoji ?? '🍅';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final existing = widget.preset;
    final preset = existing == null
        ? TimerPreset(
            id: 'preset_${DateTime.now().microsecondsSinceEpoch}',
            name: name,
            description: 'Your own rhythm.',
            emoji: _emoji,
            focusMinutes: _focus,
            shortBreakMinutes: _short,
            longBreakMinutes: _long,
            sessionsBeforeLongBreak: _cycles,
          )
        : existing.copyWith(
            name: name,
            emoji: _emoji,
            focusMinutes: _focus,
            shortBreakMinutes: _short,
            longBreakMinutes: _long,
            sessionsBeforeLongBreak: _cycles,
          );
    await ref.read(presetsProvider.notifier).save(preset);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.preset == null ? 'New preset' : 'Edit preset',
              style: context.texts.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    initialValue: _emoji,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: (v) =>
                        _emoji = v.trim().isEmpty ? '🍅' : v.trim(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MinuteRow(
              label: 'Focus',
              value: _focus,
              min: 1,
              max: 120,
              onChanged: (v) => setState(() => _focus = v),
            ),
            _MinuteRow(
              label: 'Short break',
              value: _short,
              min: 1,
              max: 60,
              onChanged: (v) => setState(() => _short = v),
            ),
            _MinuteRow(
              label: 'Long break',
              value: _long,
              min: 1,
              max: 90,
              onChanged: (v) => setState(() => _long = v),
            ),
            _MinuteRow(
              label: 'Sessions before long break',
              value: _cycles,
              min: 2,
              max: 8,
              suffix: '',
              onChanged: (v) => setState(() => _cycles = v),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                if (widget.preset != null && !widget.preset!.builtIn) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(presetsProvider.notifier)
                            .remove(widget.preset!.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.error,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save preset'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MinuteRow extends StatelessWidget {
  const _MinuteRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = ' min',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.texts.bodyLarge)),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 62,
            child: Text(
              '$value$suffix',
              textAlign: TextAlign.center,
              style: context.texts.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
