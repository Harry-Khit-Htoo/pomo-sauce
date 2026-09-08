import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'mascot_mood.dart';
import 'tomato_mascot.dart';

/// A speech bubble with a tail, used wherever the mascot is coaching.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.tailAlignment = Alignment.bottomCenter,
    this.compact = false,
  });

  final String text;
  final Alignment tailAlignment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CustomPaint(
      painter: _BubbleTailPainter(
        color: context.colors.surface,
        alignment: tailAlignment,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(compact ? 14 : 18),
          boxShadow: tokens.cardShadow,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: (compact ? context.texts.bodyMedium : context.texts.bodyLarge)
              ?.copyWith(height: 1.35, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.alignment});

  final Color color;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 16.0;
    const h = 10.0;
    final path = Path();
    if (alignment == Alignment.bottomCenter) {
      final x = size.width / 2;
      path
        ..moveTo(x - w / 2, size.height - 1)
        ..lineTo(x, size.height + h)
        ..lineTo(x + w / 2, size.height - 1)
        ..close();
    } else {
      final x = size.width / 2;
      path
        ..moveTo(x - w / 2, 1)
        ..lineTo(x, -h)
        ..lineTo(x + w / 2, 1)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) =>
      old.color != color || old.alignment != alignment;
}

/// Mascot + bubble, the standard "coach" unit.
class MascotCoach extends StatelessWidget {
  const MascotCoach({
    super.key,
    required this.mood,
    required this.message,
    this.size = 140,
    this.bubbleAbove = true,
    this.animate = true,
  });

  final MascotMood mood;
  final String message;
  final double size;
  final bool bubbleAbove;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SpeechBubble(
        text: message,
        tailAlignment:
            bubbleAbove ? Alignment.bottomCenter : Alignment.topCenter,
      ),
    );
    final mascot = TomatoMascot(mood: mood, size: size, animate: animate);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: bubbleAbove
          ? [bubble, const SizedBox(height: 18), mascot]
          : [mascot, const SizedBox(height: 18), bubble],
    );
  }
}

/// The lines the mascot says. Kept in one place so the voice stays
/// consistent - short, warm, never nagging.
abstract final class MascotLines {
  static const welcome =
      "Hi! I'm your focus buddy. Let's get one small thing done today.";
  static const firstSession =
      "Ready? Tap start and I'll keep time. I'll shout when you're done.";
  static const noHabits =
      "No habits yet. Add one small thing you'd like to do most days.";
  static const noHistory =
      "Nothing here yet. Finish a session and I'll start filling this in.";
  static const focusing = 'Deep breath. I have got the clock.';
  static const breakTime = "Rest properly - I'll wake you up.";
  static const complete = 'Nice work! That one is in the books.';
  static const paused = 'Paused. Come back whenever you are ready.';

  static String streakAtRisk(String habit, int days) =>
      "Your $days-day $habit streak is still alive. Want to keep it going?";

  static String milestone(int sessions) => switch (sessions) {
        1 => 'Your first session is done. That is the hardest one!',
        5 => 'Five sessions. You are building something.',
        10 => 'Ten sessions! Look at you go.',
        25 => 'Twenty-five sessions. That is a real habit now.',
        50 => 'Fifty sessions. I am genuinely proud.',
        100 => 'One hundred sessions. Legend.',
        _ => 'Nice work! That one is in the books.',
      };

  static String greeting(int hour) {
    if (hour < 12) return 'Good morning!';
    if (hour < 18) return 'Good afternoon!';
    return 'Good evening!';
  }
}
