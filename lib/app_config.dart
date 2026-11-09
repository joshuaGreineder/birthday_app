/// User-visible product name. The Play listing title is longer and is not used here.
const String kAppDisplayName = 'Happaroo';

/// Keep this aligned with `version` in pubspec.yaml (2.0.0+3).
/// package_info_plus is not a dependency, so the About screen reads this constant.
const String kAppVersionLabel = '2.0.0+3';

/// Canonical privacy policy. GitHub Pages can serve a draft from /docs until DNS is live.
const String kPrivacyPolicyUrl = 'https://happaroo.com/privacy';

/// Google Calendar sync: Settings > Google Calendar keeps a "Happaroo Birthdays"
/// calendar in the user's Google account in step with the app.
const bool kCalendarSyncEnabled = true;

/// OAuth *web* client ID from Google Cloud, passed at build time:
///   flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-abc.apps.googleusercontent.com
/// Empty means the build has no Google setup, and Settings says calendar sync is unavailable.
const String kGoogleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

const String kWidgetChannel = 'com.greinederlabs.happaroo/widget';
const String kTimezoneChannel = 'com.greinederlabs.happaroo/timezone';
const String kPlatformChannel = 'com.greinederlabs.happaroo/platform';
