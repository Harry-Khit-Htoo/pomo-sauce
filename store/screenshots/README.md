# Play Store screenshots

Drop phone screenshots here as PNGs; `tool/preflight.sh` checks for at least
two. Play wants a minimum of 2 and allows up to 8.

Take them in **both light and dark theme** (Settings > Appearance) - the
listing looks thin with only one, and the dark theme is a selling point.

Worth capturing: the Focus Display mid-session, the Home screen with a preset
selected, the Habits list with a streak, and the History heatmap.

From a connected device or emulator:

```bash
adb exec-out screencap -p > store/screenshots/01-focus-light.png
```
