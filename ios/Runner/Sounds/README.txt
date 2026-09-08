These three alarm tones must be members of the Runner target for iOS to play
them as custom notification sounds.

One-time step in Xcode:
  1. Open ios/Runner.xcworkspace
  2. Drag this Sounds folder onto the Runner group in the project navigator
  3. Tick "Copy items if needed" and check the Runner target
  4. Confirm they appear under Build Phases > Copy Bundle Resources

The Dart side references them by bare filename (analog_bell.wav and friends).
If they are missing from the bundle, iOS falls back to the default alert sound
rather than failing, so the app still works before this step is done.
