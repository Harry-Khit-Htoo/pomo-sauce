import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'mascot_mood.dart';

/// The Tomato Focus mascot, built to `docs/mascot-style-guide.md`.
///
/// One rig, one base model: near-spherical clay-render body, curved stem with
/// five veined calyx leaves, thin-rimmed glossy eyes, soft blush, and dark
/// maroon hand-drawn linework. Moods change only brows, eyes, mouth, blush
/// placement and the floating accent mark - never the body or the style. That
/// is the same separation a Rive rig would use, so the moods stay on-model and
/// the file stays small.
class TomatoMascot extends StatefulWidget {
  const TomatoMascot({
    super.key,
    required this.mood,
    this.size = 160,
    this.animate = true,
    this.frame,
  });

  final MascotMood mood;
  final double size;

  /// False for the dimmed desk display, where movement is a distraction and
  /// every frame costs battery.
  final bool animate;

  /// Pins the loop to a specific 0..1 phase. Only used by the golden test that
  /// renders every pose for art review; null everywhere else.
  @visibleForTesting
  final double? frame;

  @override
  State<TomatoMascot> createState() => _TomatoMascotState();
}

// Two controllers - the loop and the mood cross-fade - so this needs the
// multi-ticker mixin, not the single one.
class _TomatoMascotState extends State<TomatoMascot>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  /// Blinks ride the same 6s loop rather than a second timer.
  static const _blinkPoints = [0.28, 0.74];
  static const _blinkWidth = 0.022;

  /// Cross-fades between moods so the tomato never snaps from cheering to
  /// cross in a single frame.
  late final AnimationController _moodFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late MascotMood _from = widget.mood;
  late MascotMood _to = widget.mood;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(TomatoMascot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
    if (widget.mood != _to) {
      _from = _to;
      _to = widget.mood;
      _moodFade.forward(from: 0);
      if (widget.animate) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _moodFade.dispose();
    super.dispose();
  }

  double _blink(double t) {
    if (_to.eyesClosed) return 1;
    for (final point in _blinkPoints) {
      final d = (t - point).abs();
      if (d < _blinkWidth) return 1 - (d / _blinkWidth);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _moodFade]),
        builder: (context, _) {
          final t = widget.frame ?? (widget.animate ? _controller.value : 0.15);
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _TomatoPainter(
              from: _from,
              to: _to,
              blend: Curves.easeOutCubic.transform(_moodFade.value),
              t: t,
              blink: _blink(t),
            ),
          );
        },
      ),
    );
  }
}

/// Which floating accent mark sits beside the head. The yellow accent is the
/// only non-red/green/maroon colour in the system and is used sparingly.
enum _Mark { none, sparkle, anger, alert }

/// Per-mood pose, all derived from one 0..1 loop phase. Every numeric field
/// interpolates during a mood change, which is what makes a transition read as
/// a performance rather than a swap.
class _Motion {
  const _Motion({
    this.bob = 0,
    this.squash = 1,
    this.tilt = 0,
    this.mouthOpen = 0.3,
    this.mouthCurve = 1,
    this.mouthTongue = 0,
    this.browAngle = 0,
    this.browWeight = 1,
    this.browLift = 0,
    this.browArc = 1,
    this.browAsym = 0,
    this.pupilX = 0,
    this.pupilY = 0,
    this.eyeOpen = 1,
    this.wink = 0,
    this.blushDrop = 0,
    this.blushWide = 1,
    this.blushWarm = 0,
    this.sweat = 0,
    this.leafWave = 0,
    this.markStrength = 0,
    this.mark = _Mark.none,
  });

  final double bob;          // vertical offset, fraction of size
  final double squash;       // >1 wider and shorter
  final double tilt;         // radians
  final double mouthOpen;    // 0 = line, 1 = wide open
  final double mouthCurve;   // 1 = smile, -1 = frown
  final double mouthTongue;  // inner-mouth pink
  final double browAngle;    // + drops inner ends (cross); - raises them (worried)
  final double browWeight;   // stroke thickness multiplier
  final double browLift;     // vertical offset
  final double browArc;      // 1 = soft arc, 0 = straight angled stroke
  final double browAsym;     // raises the left brow only (playful)
  final double pupilX;
  final double pupilY;
  final double eyeOpen;      // 1 = round, <1 = narrowed
  final double wink;         // 0..1, closes the right eye only
  final double blushDrop;    // moves blush down the cheek
  final double blushWide;
  final double blushWarm;    // 0 = pink, 1 = orange (annoyed, not sick)
  final double sweat;
  final double leafWave;     // radians, waves the upper-right leaf
  final double markStrength;
  final _Mark mark;

  static double _l(double a, double b, double u) => a + (b - a) * u;

  static _Motion lerp(_Motion a, _Motion b, double u) => _Motion(
        bob: _l(a.bob, b.bob, u),
        squash: _l(a.squash, b.squash, u),
        tilt: _l(a.tilt, b.tilt, u),
        mouthOpen: _l(a.mouthOpen, b.mouthOpen, u),
        mouthCurve: _l(a.mouthCurve, b.mouthCurve, u),
        mouthTongue: _l(a.mouthTongue, b.mouthTongue, u),
        browAngle: _l(a.browAngle, b.browAngle, u),
        browWeight: _l(a.browWeight, b.browWeight, u),
        browLift: _l(a.browLift, b.browLift, u),
        browArc: _l(a.browArc, b.browArc, u),
        browAsym: _l(a.browAsym, b.browAsym, u),
        pupilX: _l(a.pupilX, b.pupilX, u),
        pupilY: _l(a.pupilY, b.pupilY, u),
        eyeOpen: _l(a.eyeOpen, b.eyeOpen, u),
        wink: _l(a.wink, b.wink, u),
        blushDrop: _l(a.blushDrop, b.blushDrop, u),
        blushWide: _l(a.blushWide, b.blushWide, u),
        blushWarm: _l(a.blushWarm, b.blushWarm, u),
        sweat: _l(a.sweat, b.sweat, u),
        leafWave: _l(a.leafWave, b.leafWave, u),
        // The mark swaps at the halfway point rather than cross-fading, so two
        // different accents are never on screen at once.
        mark: u < 0.5 ? a.mark : b.mark,
        markStrength: u < 0.5
            ? a.markStrength * (1 - u * 2)
            : b.markStrength * ((u - 0.5) * 2),
      );
}

/// The pose table. Each entry is one anchor pose from the style guide.
_Motion _poseFor(MascotMood mood, double t) {
  final wave = math.sin(t * 2 * math.pi);
  final fast = math.sin(t * 8 * math.pi);

  switch (mood) {
    // Anchor pose 1, resting: upward brow arcs, round open eyes, small smile.
    case MascotMood.idle:
      return _Motion(
        bob: wave * 0.012,
        squash: 1 + wave * 0.018,
        tilt: wave * 0.02,
        mouthOpen: 0.26,
        pupilY: wave * 0.004,
      );

    // Anchor pose 2, playful: one brow raised, closed-mouth smile, and a wink
    // that lands once per loop rather than being held.
    case MascotMood.neutral:
      final beat = math.max(0.0, math.sin((t - 0.55) * 14 * math.pi));
      return _Motion(
        bob: wave * 0.006,
        squash: 1 + wave * 0.008,
        mouthOpen: 0.0,
        mouthCurve: 0.75,
        browAsym: 0.020,
        browLift: -0.004,
        pupilY: 0.004,
        wink: t > 0.55 && t < 0.62 ? beat : 0,
      );

    // Attentive, never worried: brows up and straighter, flat neutral mouth,
    // and a yellow "!" beside the head.
    case MascotMood.alert:
      return _Motion(
        bob: wave * 0.010,
        squash: 1 + wave * 0.012,
        tilt: math.sin(t * 4 * math.pi) * 0.03,
        mouthOpen: 0.0,
        mouthCurve: 0.12,
        browAngle: -0.10,
        browLift: -0.026,
        browArc: 0.25,
        eyeOpen: 1.04,
        mark: _Mark.alert,
        markStrength: 0.75 + 0.25 * wave,
      );

    // Anchor pose 1, animated: open smile, a little bounce.
    case MascotMood.happy:
      return _Motion(
        bob: wave * 0.020,
        squash: 1 + wave * 0.022,
        tilt: wave * 0.04,
        mouthOpen: 0.55,
        mouthTongue: 0.85,
        browLift: -0.012,
        pupilY: -0.004,
        blushWide: 1.04,
      );

    // Anchor pose 3: eyes shut in cheerful crescents, wide open mouth with the
    // pink inner shade, sparkle dashes.
    case MascotMood.celebrating:
      final hop = math.max(0.0, math.sin(t * 6 * math.pi));
      return _Motion(
        bob: -hop * 0.075,
        squash: 1 + (1 - hop) * 0.05 - hop * 0.03,
        tilt: fast * 0.05,
        mouthOpen: 0.80 + hop * 0.16,
        mouthTongue: 1,
        browLift: -0.022,
        eyeOpen: 0,
        blushWide: 1.08,
        mark: _Mark.sparkle,
        markStrength: 0.65 + 0.35 * hop,
      );

    // Anchor pose 4: low angled brows pressing down, narrowed eyes, small
    // frown, jagged anger mark, blush pushed lower/wider and warmer so it
    // reads annoyed rather than unwell.
    case MascotMood.angry:
      return _Motion(
        bob: math.sin(t * 10 * math.pi) * 0.006,
        squash: 1.02,
        tilt: math.sin(t * 6 * math.pi) * 0.02,
        mouthOpen: 0,
        mouthCurve: -0.9,
        browAngle: 0.46,
        browWeight: 2.0,
        browLift: 0.020,
        browArc: 0,
        pupilY: 0.012,
        eyeOpen: 0.66,
        blushDrop: 0.022,
        blushWide: 1.18,
        blushWarm: 1,
        mark: _Mark.anger,
        markStrength: 0.7 + 0.3 * (0.5 + 0.5 * fast),
      );

    // Worried tilt is the mirror of angry: inner brow corners lift instead of
    // dropping. Slumped silhouette, gentle frown, one small sweat drop.
    case MascotMood.sad:
      return _Motion(
        bob: 0.016 + wave * 0.004,
        squash: 1.06,
        tilt: 0.07,
        mouthOpen: 0,
        mouthCurve: -0.5,
        browAngle: -0.34,
        browWeight: 1.15,
        browLift: 0.012,
        browArc: 0.5,
        pupilY: 0.016,
        eyeOpen: 0.82,
        blushDrop: 0.010,
        sweat: 0.9,
      );

    // Cheering face plus a waving leaf, per the usher note in the guide.
    case MascotMood.welcoming:
      return _Motion(
        bob: wave * 0.024,
        squash: 1 + wave * 0.024,
        tilt: wave * 0.05,
        mouthOpen: 0.62,
        mouthTongue: 0.9,
        browLift: -0.016,
        blushWide: 1.06,
        leafWave: math.sin(t * 6 * math.pi) * 0.34,
      );

    case MascotMood.sleepy:
      final breathe = math.sin(t * math.pi * 2);
      return _Motion(
        bob: breathe * 0.020,
        squash: 1 + breathe * 0.030,
        tilt: 0.06 + breathe * 0.01,
        mouthOpen: 0.10 + breathe.abs() * 0.06,
        mouthCurve: 0.35,
        browLift: 0.010,
        eyeOpen: 0,
        blushDrop: 0.006,
      );
  }
}

class _TomatoPainter extends CustomPainter {
  _TomatoPainter({
    required this.from,
    required this.to,
    required this.blend,
    required this.t,
    required this.blink,
  });

  final MascotMood from;
  final MascotMood to;
  final double blend;
  final double t;
  final double blink;

  static const _ink = AppColors.ink;

  /// Body colour is the second, wordless mood cue: riper when pleased, duller
  /// and browner when disappointed.
  (Color, Color) _bodyFor(MascotMood mood) {
    if (mood.isUp) {
      return (AppColors.tomatoTopBright, AppColors.tomatoBottomBright);
    }
    if (mood.isDown) {
      return (AppColors.tomatoTopDull, AppColors.tomatoBottomDull);
    }
    return (AppColors.tomatoTop, AppColors.tomatoBottom);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final m = _Motion.lerp(_poseFor(from, t), _poseFor(to, t), blend);
    final fromBody = _bodyFor(from);
    final toBody = _bodyFor(to);
    final top = Color.lerp(fromBody.$1, toBody.$1, blend)!;
    final bottom = Color.lerp(fromBody.$2, toBody.$2, blend)!;

    // Shadow and accent marks sit outside the squash/tilt so they stay put
    // while the body squishes.
    _paintShadow(canvas, size, s, m);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + m.bob * s);
    canvas.rotate(m.tilt);
    canvas.scale(m.squash, 2 - m.squash);
    canvas.translate(-size.width / 2, -size.height / 2);

    _paintCalyx(canvas, size, s, m);
    _paintBody(canvas, size, s, top, bottom);
    _paintBlush(canvas, size, s, m);
    _paintEyes(canvas, size, s, m);
    _paintBrows(canvas, size, s, m);
    _paintMouth(canvas, size, s, m);

    canvas.restore();

    if (m.markStrength > 0.02) _paintMark(canvas, size, s, m);
    if (m.sweat > 0.02) _paintSweat(canvas, size, s, m);
  }

  Offset _p(Size size, double x, double y) =>
      Offset(size.width * x, size.height * y);

  Rect _box(Size size, double cx, double cy, double rx, double ry) =>
      Rect.fromCenter(
        center: _p(size, cx, cy),
        width: size.width * rx * 2,
        height: size.height * ry * 2,
      );

  /// Soft blurred contact shadow - the only ground treatment in the system.
  void _paintShadow(Canvas canvas, Size size, double s, _Motion m) {
    final spread = (1 - m.bob.abs() * 4).clamp(0.62, 1.0);
    canvas.drawOval(
      _box(size, 0.5, 0.905, 0.255 * spread, 0.034),
      Paint()
        ..color = const Color(0xFF7A2A1E).withValues(alpha: 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.022),
    );
  }

  /// A thick curved stem with five rounded calyx leaves fanned around its
  /// base, each with a centre vein and its own small highlight.
  void _paintCalyx(Canvas canvas, Size size, double s, _Motion m) {
    const leaves = [
      (-90.0, 0.090, 0.150, 0.058),
      (-145.0, 0.115, 0.165, 0.062),
      (-35.0, 0.115, 0.165, 0.062),
      (168.0, 0.120, 0.150, 0.056),
      (12.0, 0.120, 0.150, 0.056),
    ];

    final fill = Paint()..color = AppColors.leaf;
    final vein = Paint()
      ..color = AppColors.leafShade.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.008
      ..strokeCap = StrokeCap.round;
    final sheen = Paint()..color = Colors.white.withValues(alpha: 0.24);

    for (var i = 0; i < leaves.length; i++) {
      final (angle, reach, len, width) = leaves[i];
      // Only the upper-right leaf waves, so the usher pose reads as a wave
      // rather than the whole crown flapping.
      final a = (angle + (i == 2 ? m.leafWave * 57.3 : 0)) * math.pi / 180;
      final centre = _p(
        size,
        0.5 + math.cos(a) * reach,
        0.300 + math.sin(a) * reach,
      );
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(a);
      final w = size.width * len;
      final h = size.height * width;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2),
        fill,
      );
      canvas.drawLine(Offset(-w * 0.55, 0), Offset(w * 0.7, 0), vein);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-w * 0.15, -h * 0.42),
          width: w * 0.7,
          height: h * 0.42,
        ),
        sheen,
      );
      canvas.restore();
    }

    // Stem: a thick, slightly curved stroke rather than a straight bar.
    final base = _p(size, 0.5, 0.300);
    final tip = _p(size, 0.523, 0.150);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          base.dx - size.width * 0.018,
          (base.dy + tip.dy) / 2,
          tip.dx,
          tip.dy,
        ),
      Paint()
        ..color = AppColors.leafShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.052
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBody(Canvas canvas, Size size, double s, Color top, Color bottom) {
    // Near-spherical, very slightly flattened top to bottom.
    final rect = _box(size, 0.5, 0.58, 0.345, 0.320);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.30, -0.45),
          radius: 1.05,
          colors: [top, bottom],
          stops: const [0.0, 1.0],
        ).createShader(rect),
    );
    // Glossy specular highlight, upper right.
    canvas.save();
    canvas.translate(size.width * 0.665, size.height * 0.418);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.190,
        height: size.height * 0.115,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018),
    );
    canvas.restore();
  }

  void _paintBlush(Canvas canvas, Size size, double s, _Motion m) {
    final colour = Color.lerp(
      AppColors.blush,
      const Color(0xFFFF9A5C),
      m.blushWarm,
    )!;
    final paint = Paint()..color = colour.withValues(alpha: 0.44);
    for (final cx in const [0.292, 0.708]) {
      canvas.drawOval(
        _box(size, cx, 0.672 + m.blushDrop, 0.058 * m.blushWide, 0.033),
        paint,
      );
    }
  }

  /// Large glossy irises with a bright specular dot near the upper left. The
  /// sclera shows only as a thin rim except where the pose opens the eye wide.
  void _paintEyes(Canvas canvas, Size size, double s, _Motion m) {
    final sclera = Paint()..color = Colors.white;
    final iris = Paint()..color = const Color(0xFF3B1D14);

    for (final (index, ex) in const [(0, 0.383), (1, 0.617)]) {
      // Only the right eye winks.
      final closing = index == 1 ? math.max(blink, m.wink) : blink;
      final open = ((1 - closing) * m.eyeOpen).clamp(0.0, 1.2);

      if (open < 0.16) {
        _paintClosedEye(canvas, size, s, ex);
        continue;
      }

      final rx = 0.076;
      final ry = 0.092;
      canvas.save();
      // Lids close from the top, which is what makes a narrowed eye read as
      // cross rather than sleepy.
      final full = _box(size, ex, 0.548, rx + 0.01, ry + 0.01);
      canvas.clipRect(
        Rect.fromLTRB(
          full.left,
          full.bottom - full.height * open.clamp(0.0, 1.0),
          full.right,
          full.bottom,
        ),
      );
      canvas.drawOval(_box(size, ex, 0.548, rx, ry), sclera);
      // The iris nearly fills the eye, leaving the sclera as a rim.
      canvas.drawOval(
        _box(size, ex + m.pupilX, 0.556 + m.pupilY, rx * 0.86, ry * 0.86),
        iris,
      );
      canvas.drawOval(
        _box(size, ex - 0.024 + m.pupilX, 0.524 + m.pupilY, 0.021, 0.021),
        sclera,
      );
      canvas.drawOval(
        _box(size, ex + 0.028 + m.pupilX, 0.585 + m.pupilY, 0.009, 0.009),
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
      canvas.restore();
    }
  }

  /// A cheerful upward crescent, as in the cheering anchor pose.
  void _paintClosedEye(Canvas canvas, Size size, double s, double ex) {
    final c = _p(size, ex, 0.560);
    final w = size.width * 0.072;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w, c.dy)
        ..quadraticBezierTo(c.dx, c.dy - w * 0.95, c.dx + w, c.dy),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.026
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Soft arcs by default; low straight wedges when cross. Positive
  /// [browAngle] drops the inner ends, negative lifts them - the single
  /// difference between "annoyed" and "worried".
  void _paintBrows(Canvas canvas, Size size, double s, _Motion m) {
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.019 * m.browWeight
      ..strokeCap = StrokeCap.round;

    for (final (ex, dir) in const [(0.383, 1.0), (0.617, -1.0)]) {
      // browAsym raises the left brow only, for the playful pose.
      final asym = dir > 0 ? -m.browAsym : 0.0;
      final c = _p(size, ex, 0.432 + m.browLift + asym);
      final half = size.width * 0.058;
      final lift = m.browAngle * size.height * 0.115;
      final inner = Offset(c.dx - half * dir, c.dy - lift);
      final outer = Offset(c.dx + half * dir, c.dy + lift * 0.5);

      if (m.browArc < 0.12) {
        canvas.drawLine(inner, outer, paint);
        continue;
      }
      // Bow the arc away from the eye, scaled by how "soft" the brow is.
      final bow = size.height * 0.022 * m.browArc;
      canvas.drawPath(
        Path()
          ..moveTo(inner.dx, inner.dy)
          ..quadraticBezierTo(
            (inner.dx + outer.dx) / 2,
            math.min(inner.dy, outer.dy) - bow,
            outer.dx,
            outer.dy,
          ),
        paint,
      );
    }
  }

  void _paintMouth(Canvas canvas, Size size, double s, _Motion m) {
    final centre = _p(size, 0.5, 0.722);
    final halfWidth = size.width * 0.082;
    final curve = m.mouthCurve;

    // Closed mouth: a single soft curve, smiling or frowning.
    if (m.mouthOpen < 0.10) {
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx - halfWidth, centre.dy)
          ..quadraticBezierTo(
            centre.dx,
            centre.dy + size.height * 0.052 * curve,
            centre.dx + halfWidth,
            centre.dy,
          ),
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.024
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final depth = size.height * 0.078 * m.mouthOpen;
    final path = Path()
      ..moveTo(centre.dx - halfWidth, centre.dy)
      ..quadraticBezierTo(
        centre.dx,
        centre.dy + depth * 2,
        centre.dx + halfWidth,
        centre.dy,
      )
      ..quadraticBezierTo(
        centre.dx,
        centre.dy - depth * 0.42,
        centre.dx - halfWidth,
        centre.dy,
      )
      ..close();

    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(path, Paint()..color = _ink);
    if (m.mouthTongue > 0.02) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centre.dx, centre.dy + depth * 1.45),
          width: halfWidth * 1.2,
          height: depth * 1.35,
        ),
        Paint()
          ..color = AppColors.tongue.withValues(alpha: m.mouthTongue),
      );
    }
    canvas.restore();
  }

  /// The floating accent beside the head. Yellow is reserved for sparkle and
  /// alert; the anger mark uses the same dark maroon as the face linework.
  void _paintMark(Canvas canvas, Size size, double s, _Motion m) {
    switch (m.mark) {
      case _Mark.none:
        return;
      case _Mark.sparkle:
        _paintSparkles(canvas, size, s, m.markStrength);
      case _Mark.anger:
        _paintAngerMark(canvas, size, s, m.markStrength);
      case _Mark.alert:
        _paintAlertMark(canvas, size, s, m.markStrength);
    }
  }

  /// Two compressed jagged strokes floating clear of the head, upper right.
  void _paintAngerMark(Canvas canvas, Size size, double s, double strength) {
    final centre = _p(size, 0.845, 0.300);
    final paint = Paint()
      ..color = _ink.withValues(alpha: strength.clamp(0, 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.020
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    for (final (scale, offset) in const [(1.0, Offset(0, 0)), (0.55, Offset(0.055, 0.075))]) {
      final r = size.width * 0.042 * scale * (0.9 + 0.1 * strength);
      final o = Offset(
        centre.dx + size.width * offset.dx,
        centre.dy + size.height * offset.dy,
      );
      // An astroid: four sharp spikes joined by inward-curving sides. That is
      // the compressed cross shape the reference uses.
      final path = Path();
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final th = i / steps * 2 * math.pi;
        final c = math.cos(th);
        final sn = math.sin(th);
        final point = o +
            Offset(c * c * c, sn * sn * sn) * r * 1.25;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path..close(), paint);
    }
  }

  /// Three tapered yellow dashes, as in the cheering anchor pose.
  void _paintSparkles(Canvas canvas, Size size, double s, double strength) {
    final paint = Paint()
      ..color = AppColors.sparkle
          .withValues(alpha: (0.55 + 0.45 * strength).clamp(0, 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.024
      ..strokeCap = StrokeCap.round;

    // Three dashes radiating outward from the head, upper right, as in the
    // cheering anchor pose. They start at different radii so they read as
    // motion lines rather than converging into an arrowhead.
    final head = _p(size, 0.5, 0.575);
    for (final (degrees, start, len) in const [
      (-72.0, 0.375, 0.058),
      (-48.0, 0.400, 0.070),
      (-24.0, 0.380, 0.055),
    ]) {
      final a = degrees * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      final inner = size.width * start;
      final outer = inner + size.width * len * (0.7 + 0.3 * strength);
      canvas.drawLine(head + dir * inner, head + dir * outer, paint);
    }
  }

  /// A small yellow exclamation beside the head for the reminder pose.
  void _paintAlertMark(Canvas canvas, Size size, double s, double strength) {
    final paint = Paint()
      ..color = AppColors.sparkle.withValues(alpha: strength.clamp(0, 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.030
      ..strokeCap = StrokeCap.round;
    final top = _p(size, 0.855, 0.250);
    canvas.drawLine(top, Offset(top.dx, top.dy + size.height * 0.070), paint);
    canvas.drawCircle(
      Offset(top.dx, top.dy + size.height * 0.104),
      s * 0.017,
      Paint()..color = AppColors.sparkle.withValues(alpha: strength.clamp(0, 1)),
    );
  }

  /// One small drop by the temple - gentle and sympathetic, not distressed.
  void _paintSweat(Canvas canvas, Size size, double s, _Motion m) {
    final o = _p(size, 0.855, 0.520);
    final r = size.width * 0.040;
    final path = Path()
      ..moveTo(o.dx, o.dy - r * 1.5)
      ..quadraticBezierTo(o.dx + r, o.dy + r * 0.15, o.dx, o.dy + r * 0.85)
      ..quadraticBezierTo(o.dx - r, o.dy + r * 0.15, o.dx, o.dy - r * 1.5)
      ..close();
    // Deliberately not the usual anime blue: the style guide keeps yellow as
    // the only accent outside red/green/maroon, so the drop is a translucent
    // white bead with a maroon outline instead.
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.82 * m.sweat),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _ink.withValues(alpha: 0.55 * m.sweat)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TomatoPainter old) =>
      old.t != t ||
      old.blink != blink ||
      old.from != from ||
      old.to != to ||
      old.blend != blend;
}
