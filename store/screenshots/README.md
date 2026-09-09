# Play Store screenshots

Captured from the `Medium_Phone` AVD (Android 17, 1080x2400, 420dpi) running a
fresh install of the debug build, walked through from first launch. Both themes
are covered - the dark theme is a selling point and the listing looks thin with
only one.

Play wants a minimum of 2 phone screenshots and allows up to 8, so pick the
strongest handful from below for the listing itself; the rest are here as a
full visual record of the app.

## Suggested listing picks

`08-focus-running`, `07-home-timer`, `15-habits-list`, `17-history`,
`34-focus-dark`, `29-home-dark`, `04-onboarding-presets`, `26-presets`.

## Full walkthrough

### First run
| File | Screen |
| --- | --- |
| `01-onboarding-welcome` | Beat 1 - "Nice to meet you" |
| `02-onboarding-focus-rest` | Beat 2 - "Focus, then rest" |
| `03-onboarding-streaks` | Beat 3 - "Streaks build themselves" |
| `04-onboarding-presets` | Preset picker - "Pick your first rhythm" |
| `05-onboarding-permissions` | Permission primer - "One thing before we start" |
| `06-onboarding-quiet-mode` | Do Not Disturb explainer |

The system notification dialog sits between `05` and `06`; it is an OS surface,
so it is not captured here.

### Timer
| File | Screen |
| --- | --- |
| `07-home-timer` | Home, top - greeting, preset card, today's stats |
| `07b-home-credit-habit` | Home, scrolled - rhythm carousel and "Credit a habit" |
| `08-focus-running` | Focus Display, focus interval running |
| `09-focus-paused` | Focus Display, paused |
| `10-focus-zen` | Desk mode - dimmed, immersive, status bar hidden |
| `11-focus-break` | Short break, ready to start |

### Habits
| File | Screen |
| --- | --- |
| `12-habits-empty` | Empty state |
| `13-habit-editor` | New habit sheet, daily |
| `14-habit-editor-weekly` | New habit sheet, weekly target slider |
| `15-habits-list` | Populated list with streaks and progress |
| `16-habit-edit` | Edit habit sheet, with Delete |

### History
| File | Screen |
| --- | --- |
| `17-history` | Weekly bar chart and 26-week heatmap |
| `18-history-calendar` | Month calendar and per-day breakdown |

### Settings
| File | Screen |
| --- | --- |
| `19-settings-top` | Appearance and Timer |
| `20-settings-mid` | Focus mode and Alarm tones |
| `21-settings-bottom` | Alarm sound/vibrate and Permissions |
| `22-settings-end` | Permissions and Data & about |
| `23-permissions` | Permissions explainer |
| `24-data` | Export and reset |
| `25-about` | About and privacy policy |
| `26-presets` | Preset list |
| `27-preset-editor` | Edit preset sheet |

### Dark theme
| File | Screen |
| --- | --- |
| `28-settings-dark` | Settings |
| `29-home-dark` | Home, top |
| `33-home-dark-lower` | Home, scrolled |
| `30-habits-dark` | Habits |
| `31-history-dark` | History, top |
| `32-history-dark-calendar` | History, calendar |
| `34-focus-dark` | Focus Display, break interval running |

## Retaking them

Launch the emulator and install a fresh build, then drive it with `adb`:

```bash
flutter emulators --launch Medium_Phone
flutter build apk --debug
adb uninstall com.pomosauce.app          # so onboarding runs again
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.pomosauce.app/.MainActivity
adb exec-out screencap -p > store/screenshots/01-onboarding-welcome.png
```

Turning the system animation scales to 0 first keeps transitions from smearing
a capture:

```bash
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```
