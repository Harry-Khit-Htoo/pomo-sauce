import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_focus/core/app_colors.dart';
import 'package:tomato_focus/mascot/mascot_mood.dart';
import 'package:tomato_focus/mascot/tomato_mascot.dart';

/// Renders every pose to one image so the art can be reviewed against
/// `docs/mascot-style-guide.md` without running the app.
///
///   flutter test --update-goldens test/mascot_gallery_test.dart
///
/// The frames are pinned so each mood is caught at a representative point in
/// its loop rather than wherever the clock happened to be.
void main() {
  testWidgets('mascot pose sheet', (tester) async {
    // Big enough for a 3x3 sheet; the default 800x600 clips the last row.
    tester.view.physicalSize = const Size(1080, 1140);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);

    const poses = <(MascotMood, double, String)>[
      (MascotMood.idle, 0.15, 'idle'),
      (MascotMood.neutral, 0.58, 'neutral / wink'),
      (MascotMood.alert, 0.25, 'alert'),
      (MascotMood.happy, 0.25, 'happy'),
      (MascotMood.celebrating, 0.08, 'celebrating'),
      (MascotMood.angry, 0.06, 'angry'),
      (MascotMood.sad, 0.15, 'sad'),
      (MascotMood.welcoming, 0.20, 'welcoming'),
      (MascotMood.sleepy, 0.25, 'sleepy'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppColors.lightBackground,
          child: Center(
            child: Wrap(
              children: [
                for (final (mood, frame, label) in poses)
                  SizedBox(
                    width: 240,
                    height: 250,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TomatoMascot(
                          mood: mood,
                          size: 190,
                          animate: false,
                          frame: frame,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('goldens/mascot_poses.png'),
    );
  });
}
