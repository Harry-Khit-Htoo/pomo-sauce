abstract final class AppConstants {
  static const appName = 'Tomato Focus';
  static const appTagline = 'Focus. Rest. Repeat.';

  /// Replace with the real hosted policy before submitting to Play. The same
  /// URL must be entered in Play Console > App content > Privacy policy.
  static const privacyPolicyUrl = 'https://tomatofocus.app/privacy';
  static const supportEmail = 'support@tomatofocus.app';

  /// Notification ids. Kept apart so cancelling one never clears another.
  static const foregroundServiceId = 2001;
  static const alarmNotificationBaseId = 3000;

  /// How many upcoming phase-end alerts get scheduled ahead of time when
  /// auto-start is on. iOS caps pending local notifications at 64.
  static const maxScheduledChainLength = 10;
}
