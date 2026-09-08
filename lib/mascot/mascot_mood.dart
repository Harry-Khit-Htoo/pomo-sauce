/// What the tomato is feeling.
///
/// Each value maps to one animation clip. If the mascot is ever swapped for a
/// Rive rig, this enum is the state-machine input and [riveInput] is the name
/// design should give the trigger - app logic then never changes again.
enum MascotMood {
  /// App open, nothing due. Blink and a small sway.
  idle,

  /// Calm and attentive. The default while a focus interval runs.
  neutral,

  /// Something is due soon but not yet done - a gentle nudge, not a scold.
  alert,

  /// A habit or session just landed on time.
  happy,

  /// A milestone or long streak. The big one.
  celebrating,

  /// Something is overdue. Disappointed-but-motivating, never punishing.
  angry,

  /// A streak just broke. Deflated, soft - an invitation to restart.
  sad,

  /// Greeting a new user through onboarding.
  welcoming,

  /// Resting during a break: eyes closed, snoozing.
  sleepy;

  /// The Rive state-machine input name for this mood.
  String get riveInput => name;

  bool get eyesClosed => this == MascotMood.sleepy;

  /// Moods that shift the body to a duller, browner red.
  bool get isDown => this == MascotMood.angry || this == MascotMood.sad;

  /// Moods that ripen the body to a brighter red.
  bool get isUp => this == MascotMood.celebrating || this == MascotMood.happy;

  /// A short supportive line to pair with the face. The brief is explicit
  /// that the angry state must never stand on its own.
  String get supportLine => switch (this) {
        MascotMood.idle => 'Nothing due. Want to get one thing done?',
        MascotMood.neutral => 'Deep breath. I have got the clock.',
        MascotMood.alert => 'One thing is still waiting on you today.',
        MascotMood.happy => 'Nice work! That one is in the books.',
        MascotMood.celebrating => 'Look at you go!',
        MascotMood.angry => "Let's get back on track!",
        MascotMood.sad => 'Streaks break. Starting again is the whole skill.',
        MascotMood.welcoming => "Hi! I'm your focus buddy.",
        MascotMood.sleepy => "Rest properly - I'll wake you up.",
      };
}
