abstract final class AppConstants {
  static const appName = 'Tomato Focus';
  static const appTagline = 'Focus. Rest. Repeat.';

  /// The live policy. This exact URL must also be entered in
  /// Play Console > App content > Privacy policy - Play checks that the app
  /// and the listing agree. Source: github.com/Harry-Khit-Htoo/tomato-focus-privacy
  static const privacyPolicyUrl =
      'https://harry-khit-htoo.github.io/tomato-focus-privacy/';
  static const supportEmail = 'aungkhit.pentester@gmail.com';

  /// Notification ids. Kept apart so cancelling one never clears another.
  static const foregroundServiceId = 2001;
  static const alarmNotificationBaseId = 3000;

  /// How many upcoming phase-end alerts get scheduled ahead of time when
  /// auto-start is on. iOS caps pending local notifications at 64.
  static const maxScheduledChainLength = 10;
}
