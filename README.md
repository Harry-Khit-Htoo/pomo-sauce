# Pomo Sauce

A Pomodoro timer and habit tracker for Android and iOS, built with Flutter,
with a tomato mascot that reacts to how your day is actually going.

- **Tomato red throughout.** There is no blue anywhere in the app - the two
  break phases take green and amber, and surfaces are a warm cream rather than
  pure white.
- **A mascot that reacts to what you actually do.** Nine moods driven by real
  habit and session data, not a static idle loop: cheerful on a win, cross
  when something is genuinely missed, sad when a streak lapses.
- **Quiet mode.** Focus sessions can silence the phone automatically and hand
  it straight back afterwards - explained up front, reversible in one tap.
- **Timer that actually survives being backgrounded.** The countdown is defined
  by absolute timestamps, kept alive by an Android foreground service, and
  alerted by exact alarms scheduled with the OS up front — not by a Dart
  `Timer`, which Android suspends the moment you leave the app.
- **Habits with streaks**, a 26-week productivity heatmap, and a calendar you
  can scrub back through.
- **Three themes**: light, dark, or follow the system (the default).
- **Everything stays on the device.** No accounts, no network calls, no
  analytics, no ads.

---

## Table of contents

- [Running it](#running-it)
- [How the timer works](#how-the-timer-works)
- [The Focus Display](#the-focus-display)
- [The mascot](#the-mascot)
- [Do Not Disturb during focus sessions](#do-not-disturb-during-focus-sessions)
- [Permissions, and exactly why each one is here](#permissions-and-exactly-why-each-one-is-here)
- [Project layout](#project-layout)
- [Assets](#assets)
- [Release build](#release-build)
- [Play Store submission checklist](#play-store-submission-checklist)
- [Known deviations from the brief](#known-deviations-from-the-brief)

---

## Running it

```bash
flutter pub get
flutter run
```

Built and verified against **Flutter 3.44.8 / Dart 3.12.2**, AGP 9.0.1,
Gradle 9.1, Kotlin 2.3.20, NDK 28.2.13676358, `compileSdk`/`targetSdk` 36,
`minSdk` 24.

```bash
flutter analyze     # clean
flutter test        # 21 tests: cycle machine, wall-clock timing, mood rules
```

Verified on an Android emulator (API 37) against a **release** build, not just
debug — see [Release build](#release-build) for why that distinction matters
here.

## How the timer works

The hard part of a Pomodoro app is not counting to twenty-five. It is being
correct after Android has frozen your process for forty minutes. Three
mechanisms cover that, and they are deliberately independent:

**1. State is timestamps, never ticks.**
`PomodoroState` stores `endsAt`, an absolute `DateTime`. Remaining time is
always *derived* (`endsAt - now`), so nothing can drift. The 200 ms ticker in
`PomodoroController` exists only to repaint; if it never fired at all, the
numbers would still be right. Every transition is written to
`SharedPreferences` immediately, so a killed process can be reconstructed
exactly on the next launch.

**2. Alerts are scheduled with the OS, up front.**
When a session starts, `NotificationService.scheduleChain()` hands the whole
upcoming run of interval boundaries to `zonedSchedule` — the current one, plus
the next eight if auto-start is on. These fire whether the app is foregrounded,
backgrounded, or dead. `AndroidScheduleMode.alarmClock` is used when the
exact-alarm permission is granted and `exactAllowWhileIdle` when it is not.
This is also the *only* mechanism on iOS, which has no long-running background
timers; the completion alert is scheduled for its exact fire time rather than
counted down live.

**3. A foreground service keeps the process alive.**
`flutter_foreground_task` runs a `specialUse` foreground service for the life
of a session, showing the live countdown in the notification shade. Its task
handler runs in a separate isolate and holds no state of its own: once a
second it re-reads the persisted timer state and re-renders the notification
from it.

**Catching up.** `PomodoroController._catchUp()` runs on every app resume, on
cold start, and on each tick. It replays every boundary that has already
passed, *in order and with its true timestamps* — so a session that ended
forty minutes ago is filed in history at the time it actually ended, its linked
habit is credited for the correct day, and the cycle counter lands where it
should. This is what makes "I started a 50-minute session and put my phone in
my pocket" produce the right result.

**Exact-alarm revocation.** On Android 12+ the user or the system can revoke
"Alarms & reminders" at any time, which silently drops every queued exact
alarm. That broadcast
(`ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`) is only delivered to
a running app and cannot be declared in the manifest, so `MainActivity.kt`
registers for it at runtime and forwards it to Dart over an `EventChannel`.
The controller re-arms the pending chain the moment access comes back.

## The mascot

The tomato's face and colour follow real behaviour. [`MascotMood`](lib/mascot/mascot_mood.dart)
is the state, [`selectMood`](lib/mascot/mood_selector.dart) is the only place
that decides it, and every screen just asks "what mood?".

| Trigger | Mood |
|---|---|
| Habit or session completed on time | `happy` - curved eyes, wide smile, small bounce |
| Milestone, or a live streak of 7+ | `celebrating` - hopping, sparkle dashes, brighter red |
| Habit due today, not yet done | `alert` - brows up, a small double-take toward the reminder |
| Habit missed, or still undone late in the day | `angry` - hard angled brows, 💢 vein, duller red |
| A streak of 3+ just lapsed | `sad` - droopy lids, deflated posture |
| Focus interval running | `neutral` |
| Break running | `sleepy` - eyes closed, snooze bob |
| Onboarding | `welcoming` |
| Nothing due | `idle` - blink and sway |

Two things the brief was explicit about, both enforced in code:

- **The angry face is never punitive.** It only fires for a habit genuinely
  missed - never for one the user simply has not got to yet this morning
  (`overdueAt` requires the evening; `missed` requires an actual missed due
  day). A test asserts that a merely-due habit returns `alert`, not `angry`.
- **The face never stands alone.** Every mood carries a `supportLine`, and the
  angry one is "Let's get back on track!".

Mood also shifts the body colour - riper red when pleased, duller and browner
when disappointed - so the state reads before the expression does. Mood changes
cross-fade over 420 ms rather than snapping.

Nine moods, one `AnimationController`, one interpolated parameter table. Moods
change only brows, eyes, mouth, blush placement and the floating accent mark -
never the body or the render style - which is the same separation a Rive rig
would use.

**The art spec lives in [`docs/mascot-style-guide.md`](docs/mascot-style-guide.md)**:
base model, palette, the four anchor poses from the reference sheet, the poses
that had to be invented, and the handoff notes for an illustrator or Rive
author. Attach the two reference images to any ticket that produces new poses.

To review every pose without launching the app:

```bash
flutter test --update-goldens test/mascot_gallery_test.dart
```

which writes a 3x3 sheet to `test/goldens/mascot_poses.png`.

## Do Not Disturb during focus sessions

Off by default. The sequence is fixed and is enforced by the call sites, not
just documented:

1. **Explainer first.** [`DndExplainerScreen`](lib/features/settings/dnd_explainer_screen.dart)
   states what will change, that the timer alarm still gets through, and how to
   turn it off. Notification policy access is granted on a *system settings
   page*, not a runtime dialog, so sending someone there unannounced is exactly
   the unexplained device-settings change Play prohibits. There is no code path
   to `openPolicyAccessSettings()` that does not pass through this screen.
2. **Then the system screen**, via `ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`.
3. **Then, per session:** `INTERRUPTION_FILTER_PRIORITY` on the start of a
   *work* interval only. Breaks are deliberately left alone.
4. **Always reversible.** A moon badge sits on the focus screen the whole time
   DND is in effect - a filled circle with the icon dominant, not fine print -
   and tapping it opts out of that session without rewriting the user's
   setting.

Details that matter:

- **The alarm stays audible** because its notification channel sets
  `bypassDnd`, not because the filter is weakened. The rest of the phone stays
  properly quiet.
- **The user's own mode is restored**, not "all" - `DndController` records the
  filter it found and puts that back.
- **A killed process cannot strand you in silence.** The previous filter is
  written to disk on enable, and `reconcile` hands it back at next launch. A
  `force-stop` mid-session was found to leave the phone silenced during
  testing; this is the fix.
- **Declining is remembered.** The explainer is shown once; after that the
  toggle lives in Settings and the app never asks again.
- Revoking access from system settings turns the in-app toggle off on next
  resume, so it never claims something that can no longer happen.

## The Focus Display

**Landscape is its own layout**, not a stretched portrait one: mascot on the
left, ring + DND badge + controls on the right, both groups pulled in toward
the centre line so a wide display does not leave a canyon down the middle.

Nothing can clip. Each group is laid out at its natural size inside a
`BoxFit.scaleDown` `FittedBox`, so on a short landscape screen the whole group
shrinks uniformly rather than running off the bottom edge. A hand-computed
height budget was tried first and was still defeated by a 1600x720 display -
the `FittedBox` is what makes it structurally safe. Below 320dp of height a
compact tier also drops the speech bubble and the badge's text, so the shrink
never has to go far enough to make the countdown illegible.

**The Focus Display opens itself.** [`RootShell`](lib/features/shell/root_shell.dart)
is the single owner of presenting it, so every route behaves the same:

- starting a session from anywhere - Home, a preset, a chained break - opens it;
- so does launching or resuming the app while a session is still running;
- it is always a *push*, so back returns to the shell with the timer, the
  foreground service and DND all still running. Entry is automatic; exit is not.

It declines to interrupt when something else is already on top (a settings
page, a sheet), and a re-entrancy guard stops two triggers stacking two copies.

## Permissions, and exactly why each one is here

These eight are the complete set in the shipped manifest — verified against the
merged manifest of a release build, so nothing has crept in from a plugin. The
same list is shown to the user in **Settings → Permissions**
(`lib/features/settings/permissions_screen.dart`); keep the three in sync.

| Permission | Why the app needs it | Runtime prompt? |
|---|---|---|
| `POST_NOTIFICATIONS` | Post the interval-completion alert and the running-timer notification. Without it the app cannot tell you a session ended. | Yes, Android 13+. Asked at the end of onboarding or on first start — never on cold start. |
| `SCHEDULE_EXACT_ALARM` | Fire the completion alert on the exact second. A Pomodoro that rings four minutes late is useless. | Yes, Android 12+, via a special-access screen. Declining degrades to an inexact alarm; the app keeps working. |
| `FOREGROUND_SERVICE` | Run the countdown service. | No. |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Required to start a `specialUse`-typed service on Android 14+. | No. |
| `WAKE_LOCK` | Hold the screen on while the Focus Display is open, if "Keep screen on" is enabled. Released as soon as the screen is left or the session ends. | No. |
| `VIBRATE` | Vibrate on interval completion. Switchable off in Settings. | No. |
| `RECEIVE_BOOT_COMPLETED` | Let a pending completion alert be re-armed after a reboot, so a session started before the restart still alerts you. | No. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Optional and user-initiated only, from Settings → Permissions, for OEMs whose power saving kills timers. | Yes, only if the user taps it. |
| `ACCESS_NOTIFICATION_POLICY` | Silence notifications for the length of a focus session, and nothing else. **Restricted permission** - see [Do Not Disturb](#do-not-disturb-during-focus-sessions). | Yes, on a system settings screen, always after the in-app explainer. |

**Not requested, on purpose:**

- `USE_EXACT_ALARM` — grants exact alarms with no user prompt, but Play
  restricts it to apps whose *primary* function is an alarm clock, timer, or
  calendar. A Pomodoro app with a habit tracker is a weaker claim than it
  looks, and being wrong means rejection. `SCHEDULE_EXACT_ALARM` plus a
  graceful in-app request flow is the policy-safe choice.
- `USE_FULL_SCREEN_INTENT` — same category restriction, and the app does not
  need to take over a locked screen.
- No internet, location, contacts, camera, storage, or account permissions.
  The app makes no network calls of any kind.

### Foreground service type

Declared as `specialUse`, with the Android 14+ subtype property in the
manifest:

```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="specialUse"
    android:exported="false">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="pomodoro_timer: ..." />
</service>
```

`specialUse` is the honest classification — a user-facing countdown is not
media playback, location, or data sync. `dataSync` would be a misuse and is
capped at six hours per day on Android 15+; `shortService` is capped at three
minutes, which is shorter than every preset in the app.

**This must also be declared in Play Console → App content → Foreground service
permissions before release.** Suggested justification, matching the manifest:

> Pomo Sauce is a Pomodoro timer. The foreground service keeps a
> user-started focus timer counting and displays its live countdown while the
> app is not in the foreground, which is the app's core, user-visible
> function. The service is only ever started by an explicit user action
> (starting a session) and is stopped as soon as the session ends or is
> cancelled. It performs no background work beyond timekeeping and updating
> its own notification.

Record a short screen capture of starting a session, leaving the app, and the
countdown continuing in the shade — Play asks for a demo video for this
declaration.

## Project layout

```
lib/
  main.dart                  bootstraps DB, settings, notifications, alarm
  app.dart                   MaterialApp, theming, lifecycle resync
  providers.dart             the whole Riverpod graph
  core/                      palette, ThemeData, tokens, formatting, day keys
  data/
    app_database.dart        sqflite schema (habits, habit_logs, sessions)
    habit_repository.dart    CRUD + streak maths
    session_repository.dart  history, heatmap and chart aggregation
    settings_repository.dart SharedPreferences: settings, presets, timer state
    models/
  timer/
    pomodoro_state.dart      immutable state + JSON round trip
    pomodoro_controller.dart the engine: transitions, catch-up, scheduling
    notification_service.dart channels, permissions, the scheduled chain
    foreground_service.dart  the service wrapper + its isolate task handler
    alarm_player.dart        in-app looping alarm + vibration
    exact_alarm_channel.dart bridge to MainActivity.kt
  mascot/                    moods, the CustomPainter mascot, speech bubbles
  features/
    onboarding/  home/  focus/  habits/  history/  settings/  shell/
tool/
  generate_assets.py         regenerates every sound and image
  check_16kb_alignment.sh    pre-upload native library check
```

**State management** is Riverpod 3 (`Notifier` / `NotifierProvider`), used
consistently — no `setState` for anything that outlives a widget.

**Persistence** is sqflite for habits, habit logs and session history, and
SharedPreferences for settings, presets, and the live timer state. Deliberately
no code generation: nothing here needs `build_runner`, so the project builds
from a clean checkout with `pub get` alone.

## Assets

Everything in `assets/` is produced by `tool/generate_assets.py`. The alarm
tones are synthesised outright; the branding PNGs are composited from one
piece of source art, `assets/branding/source/mascot_render.jpg` — a rendered
mascot and "Pomo Sauce" wordmark on a white ground. `tool/brand_source.py`
cuts both out of it (flooding the white in from the border, so the eye whites
and the specular highlight survive where a plain white key would punch holes
through them) and every image below is a composite of those two pieces.
Nothing here is third-party, so there are no licences to track. Regenerate
with:

```bash
python tool/generate_assets.py        # needs Pillow; audio is pure stdlib
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

**Alarm tones** (`assets/sounds/`, mirrored into `android/app/src/main/res/raw/`
because Android notification channels take their sound from a raw resource):

| File | Sound |
|---|---|
| `analog_bell.wav` | **Default.** A soft analog alarm-clock "cling cling cling" — three inharmonic bell strikes per 1.5 s loop, with a clapper transient and a gentle low-pass so it reads mechanical rather than shrill. |
| `soft_chime.wav` | A warm descending two-note chime. |
| `digital_beep.wav` | A short, dry electronic triple-beep. |

**Images** (`assets/branding/`):

| File | Use |
|---|---|
| `icon_play_512.png` | The Play Store icon: plain 512×512, full bleed, **no text**, per Play's icon guidance. |
| `icon_source_1024.png` | Source for `flutter_launcher_icons` (legacy Android + iOS). |
| `icon_adaptive_foreground.png` | Adaptive icon foreground, also the monochrome layer. Authored near full bleed (0.88): `flutter_launcher_icons` wraps it in a 16% inset of its own, and that is what lands the art in the 66% safe zone. Author it to the safe zone *as well* and the margin doubles up, leaving the mascot marooned in a ring of background. |
| `splash_icon_android12.png` | Android 12+ splash icon. Same art at 0.60, because this one is **not** inset for us — the platform masks it to a circle two thirds of the canvas, so the margin has to be baked in. |
| `brand_lockup_light/dark.png` | The mascot over the **"Pomo Sauce"** wordmark — the in-app lockup. This is where the name lives; baking it into a 48dp launcher icon would make both illegible. |
| `splash_light/dark.png` | Splash art for `flutter_native_splash`. |
| `feature_graphic_1024x500.png` | Play listing feature graphic. |
| `source/mascot_render.jpg` | The source render everything above is cut from. Not shipped in the bundle: `pubspec.yaml` lists `assets/branding/`, and Flutter's directory assets are not recursive. |

**The mascot** is not a static asset. `lib/mascot/tomato_mascot.dart` draws it
with a `CustomPainter` driven by one `AnimationController`, with six moods —
`idle` (breathing + scheduled blinks), `focusing`, `sleepy` (eyes closed,
snooze bob), `cheering` (hopping, sparkles), `concerned` (worried brows,
wobble) and `encouraging`. See [Known deviations](#known-deviations-from-the-brief).

## Release build

Before uploading anything, run the preflight:

```bash
tool/preflight.sh
```

It runs every check that can be automated - analyze, tests, placeholder URLs,
signing identity, 16 KB alignment, that the alarm tones survived resource
shrinking, target API level, store assets - and prints what is left to do by
hand. Exit code 0 only when everything automated passes.

**Release bundles cannot be debug-signed.** `bundleRelease` fails outright
without `android/key.properties`, because a debug-signed AAB is rejected on
upload and the Play Console error for it is far less obvious than a local one.
`flutter build apk --release` still falls back to debug signing (with a loud
warning) so local testing on a fresh clone keeps working. For a throwaway test
bundle: `flutter build appbundle --release --android-project-arg=allowDebugSigning=true`.

1. Create a keystore and `android/key.properties` (git-ignored, template at
   `android/key.properties.example`):

   ```properties
   storeFile=../keystore/pomo-sauce.jks
   storePassword=...
   keyAlias=tomato
   keyPassword=...
   ```

   Without it, release builds fall back to debug signing so a fresh clone
   still builds.

2. Build and verify:

   ```bash
   flutter build appbundle --release
   tool/check_16kb_alignment.sh build/app/outputs/bundle/release/app-release.aab
   ```

   The alignment check is not optional — Play requires 16 KB page alignment for
   apps shipping native code, and Flutter ships four `.so` files per ABI. The
   current toolchain passes all twelve.

3. Sanity-check that the alarm tones survived resource shrinking:

   ```bash
   unzip -l build/app/outputs/flutter-apk/app-release.apk | grep 'res/.*\.wav'
   ```

   Three files must be listed (their names will be obfuscated, which is fine).
   The tones are referenced only by name from Dart, so R8's resource shrinker
   cannot see any reference to them; `android/app/src/main/res/raw/keep.xml`
   is what keeps them. Without it the release build still *looks* fine — the
   notification channel is created with a valid-looking sound URI — but every
   `zonedSchedule` call fails with `invalid_sound` and no alarm ever fires.
   This class of bug does not reproduce in debug builds, so always smoke-test
   a release build before shipping.

4. Confirm the shipped manifest is what you think it is:

   ```bash
   grep -oE 'android:name="android\.permission[^"]*"' \
     build/app/intermediates/packaged_manifests/release/*/AndroidManifest.xml \
     | sort -u
   ```

### iOS: one manual step

The three alarm tones are staged in `ios/Runner/Sounds/` but must be added to
the Runner target in Xcode to play as custom notification sounds — drag the
folder into the Runner group, tick the Runner target, and confirm they land in
**Build Phases → Copy Bundle Resources**. If they are missing, iOS falls back
to the default alert sound rather than failing, so the app works either way.
See `ios/Runner/Sounds/README.txt`.

## Play Store submission checklist

Policy pages change; re-check each of these against the live Play Console
immediately before uploading rather than trusting this file.

- [x] **Privacy policy URL** — published at
      <https://harry-khit-htoo.github.io/pomo-sauce-privacy/> and set in
      `lib/core/constants.dart`, linked from Settings → About. Enter that
      **exact** URL in Play Console → App content → Privacy policy: Play
      cross-checks the listing against what the app links to, and even a
      trailing-slash mismatch can trip it. `PRIVACY_POLICY.md` here is the
      source of truth for the wording; the `pomo-sauce-privacy` repository
      renders it.
- [ ] **Data safety form.** As shipped the honest answers are: no data
      collected, no data shared, no data transmitted off the device, and data
      is deleted on uninstall (plus in-app via Settings → Data → Delete all).
      There is an in-app export. If you ever add analytics or ads, this section
      and the store listing must both change.
- [ ] **Foreground service declaration** under App content, matching the
      manifest's `specialUse` type — wording above, plus a demo video.
- [ ] **Notification Policy Access (DND control) declaration.**
      `ACCESS_NOTIFICATION_POLICY` is restricted, so it needs its own
      justification alongside the exact-alarm and foreground-service ones.
      Suggested wording:

      > Pomo Sauce is a Pomodoro timer. With the user's explicit opt-in, it
      > places the device in Do Not Disturb (priority mode) for the duration of
      > a focus session so notifications do not interrupt the user's work, and
      > restores the user's previous mode as soon as the session ends, is
      > paused, or is cancelled. The feature is off by default. Before access
      > is ever requested, an in-app explainer states exactly what will change
      > and how to reverse it, and the user is then sent to the system
      > notification-policy settings screen to grant it themselves. While a
      > session is running, an always-visible control on the focus screen lets
      > the user turn it off in one tap. The permission is used for no other
      > purpose: the app does not read notifications, does not modify any other
      > device setting, and does not use Do Not Disturb outside a running focus
      > session.

      Record a demo video of the explainer, the system grant, a session start,
      the on-screen "DND is on" chip, and the session ending with the previous
      mode restored. Play reviewers ask for this on restricted permissions.
- [ ] **Data safety** is unchanged by the DND feature: it still collects
      nothing and transmits nothing. Confirm the form says so.
- [ ] **Content rating questionnaire** — general audience, productivity.
- [ ] **Ads declaration** — currently "contains no ads".
- [ ] **Target audience** — not directed at children; the app has no
      restricted content and no Families policy exposure.
- [ ] **Permissions review** — the eight above, all used. Play flags unused or
      overbroad permissions, so do not add `permission_handler` or similar
      "just in case": it was removed from this project for exactly that reason.
      Nine permissions ship; the merged-manifest check below confirms nothing
      crept in.
- [ ] **Store listing title** — `Pomo Sauce - Habit Tracker & Focus Timer`
      (50 characters, inside Play's limit). The on-device launcher label stays
      the short `Pomo Sauce`: the keywords earn their place in the listing,
      where they are searchable, but a home screen truncates anything longer
      than roughly a dozen characters. The two are set independently — the
      label in `AndroidManifest.xml` and `Info.plist`, the title in Play
      Console — so changing one does not change the other.
- [ ] **Store assets** — 512×512 icon (`assets/branding/icon_play_512.png`),
      1024×500 feature graphic, and phone + tablet screenshots. Take the
      screenshots in **both light and dark theme**; the theme switcher is in
      Settings.
- [ ] **Target API level** — `targetSdk` is 36 (Android 16). Confirm the
      current Play threshold at submission time; Google raises it annually.
- [ ] **Final pass** over Play Console → Policy centre and the App content
      checklist before hitting publish.

## Known deviations from the brief

Two, both deliberate, both flagged rather than quietly substituted:

**1. The mascot is a `CustomPainter`, not a Rive or Lottie file.** The brief
asked for a vector character animation exported as `.riv`/`.json`, preferring
it over heavy video. All nine states are here, drawn in Dart from the
reference expression sheet instead of authored in Rive. Producing a genuinely good `.riv`
or hand-written Lottie needs the design tool, and a hand-rolled JSON would have
been worse art than what a painter gives. The painter also beats the asset on
the brief's own criteria: zero asset weight, resolution independent, recolours
itself for the dark theme from theme tokens, and animates from a single
`AnimationController` interpolating eight numbers — cheap enough to leave
running on a focus screen for fifty minutes. If you want to swap in a real
Rive file later, `TomatoMascot` is the only widget to replace; `MascotMood` is
already the state enum you would drive its state machine with, and
`MascotMood.riveInput` is the input name to give each state.

The painter follows the supplied reference sheet: glossy red body, rounded
blob calyx over a thick stem, large oval eyes with a warm brown iris and two
highlights, thin curved brows that thicken into angled wedges when cross,
coral blush, the 💢 vein, and the yellow sparkle dashes. Exact linework and
frame counts should still come from the art if this is ever rebuilt in Rive.

**2. `permission_handler` was dropped.** It is in the brief's suggested stack
but the app never needed it — notification permission comes from
`flutter_foreground_task` and `flutter_local_notifications`, and exact-alarm
access from the native channel in `MainActivity.kt`. It was also demanding
`compileSdk 37`, which is not a stable platform yet. One less dependency and
one less thing for a Play reviewer to ask about.

**3. Habit colours are warm-only.** The brief said no blue anywhere, so the
user-pickable habit palette was re-cut to tomato, leaf, amber, terracotta,
plum, olive and cocoa. A habit chip can no longer reintroduce the colour the
brand dropped.

Everything else in both briefs is implemented as specified.
