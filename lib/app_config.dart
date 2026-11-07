/// User-visible product name. The Play listing title is longer and is not used here.
const String kAppDisplayName = 'Happaroo';

/// Keep this aligned with `version` in pubspec.yaml (2.0.0+3).
/// package_info_plus is not a dependency, so the About screen reads this constant.
const String kAppVersionLabel = '2.0.0+3';

/// Canonical privacy policy. GitHub Pages can serve a draft from /docs until DNS is live.
const String kPrivacyPolicyUrl = 'https://happaroo.com/privacy';

/// Google Calendar sync is off for v1.
/// The service and its packages stay in the project. Do not call Google sign-in while this is false.
const bool kCalendarSyncEnabled = false;

const String kWidgetChannel = 'com.greinederlabs.happaroo/widget';
const String kTimezoneChannel = 'com.greinederlabs.happaroo/timezone';
const String kPlatformChannel = 'com.greinederlabs.happaroo/platform';
