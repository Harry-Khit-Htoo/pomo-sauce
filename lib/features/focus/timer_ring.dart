import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatting.dart';

/// The countdown ring.
///
/// Repaints come from a [ValueListenable] clock rather than from the timer
/// state, so a running session only invalidates this widget - not the screen
/// around it.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.clock,
    required this.remaining,
    required this.progress,
    required this.color,
    required this.label,
    this.size = 280,
    this.dimmed = false,
    this.child,
  });

  /// Ticks while the timer runs; used only to drive repaints.
  final ValueListenable<DateTime> clock;

  /// Recomputed for the current instant.
  final Duration Function(DateTime now) remaining;
  final double Function(DateTime now) progress;

  final Color color;
  final String label;
  final double size;
  final bool dimmed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<DateTime>(
        valueListenable: clock,
        builder: (context, now, _) {
          final left = remaining(now);
          final value = progress(now);
          return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(
                progress: value,
                color: color,
                track: dimmed
                    ? context.colors.outline.withValues(alpha: 0.25)
                    : context.colors.outlineVariant,
                strokeWidth: size * 0.055,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (child != null) ...[child!, SizedBox(height: size * 0.02)],
                    Text(
                      formatCountdown(left),
                      style: TextStyle(
                        fontSize: size * 0.20,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -1.5,
                        height: 1.05,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: dimmed
                            ? context.colors.onSurface.withValues(alpha: 0.75)
                            : context.colors.onSurface,
                      ),
                    ),
                    SizedBox(height: size * 0.015),
                    Text(
                      label.toUpperCase(),
                      style: context.texts.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 1.5 * math.pi,
          colors: [color.withValues(alpha: 0.55), color],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: centre, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // A dot rides the leading edge so progress is readable at a glance.
    final angle = -math.pi / 2 + sweep;
    canvas.drawCircle(
      centre + Offset(math.cos(angle), math.sin(angle)) * radius,
      strokeWidth * 0.42,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
