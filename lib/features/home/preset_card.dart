import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/models/timer_preset.dart';

class PresetCard extends StatelessWidget {
  const PresetCard({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final TimerPreset preset;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tint = context.colors.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SizedBox(
        width: 178,
        child: Material(
          color: selected ? tint.withValues(alpha: 0.12) : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? tint : context.colors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(preset.emoji, style: const TextStyle(fontSize: 22)),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle_rounded, size: 20, color: tint),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${preset.focusMinutes} min focus',
                    style: context.texts.bodySmall?.copyWith(color: tint),
                  ),
                  const Spacer(),
                  Text(
                    preset.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.tokens.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
