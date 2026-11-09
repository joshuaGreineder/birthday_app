# Happaroo

Happaroo is a birthday and anniversary reminder. The name in the app is Happaroo. The Play store title is "Happaroo: Birthday Reminder". The Android package is `com.greinederlabs.happaroo`.

Names, dates, notes, groups, custom event types, and settings stay on the device in Hive. There is no account, no backend, no analytics, and no ads. Android is the shipping target. iOS is not a v1 store target.

`pubspec.yaml` is `2.0.0+3` (versionName 2.0.0, versionCode 3).

## Features

- Birthdays, anniversaries, and custom event types. Group is optional. A blank group is shown as Ungrouped.
- Home, Timeline, and Calendar, with search and filters by type and group.
- A date can be a month and day with no year. It is stored with sentinel year 4. The age is hidden, and year 4 is not shown.
- A birthday under 2 with a known year shows the age in months and days.
- On-device reminders, from the same day through one month before. They are local notifications, not push.
- Optional import of birthdays from contacts, after the contacts permission is granted.
- System, light, and dark theme. Surfaces are navy, the accent is coral, birthdays are orange, and anniversaries are pink. The choice is remembered.
- Android home-screen widgets: Next up, Upcoming, and Calendar. They follow the app theme.
- Android launcher icons: Calendar, Cake, Balloons, and Roo.
- Optional Google Calendar sync. It stays off unless the build sets `GOOGLE_SERVER_CLIENT_ID`.

## Prerequisites

- Flutter stable. The Dart SDK constraint in `pubspec.yaml` is `^3.10.4`.
- The Android command-line SDK, to build an APK or an app bundle.
- Android Studio is not required.

## Run, test, and build

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
flutter build appbundle --release
```

`flutter build apk --debug` is a sideload build. It is not the file you upload to Play. The Play upload is the release app bundle.

`flutter build appbundle --release` fails if `android/key.properties` is missing, incomplete, or points at a keystore that is not there. Release builds do not fall back to the debug keystore.

## Signing

Create the upload key on your own machine. Do not commit the keystore, and do not commit `android/key.properties`. `android/.gitignore` ignores `key.properties`, `*.jks`, and `*.keystore`.

```bat
keytool -genkeypair -v -keystore %USERPROFILE%\happaroo-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep `happaroo-upload.jks` outside the repo. For a local release build, create `android/key.properties` with `storePassword`, `keyPassword`, `keyAlias` (`upload` if you used the command above), and `storeFile` set to the path of that keystore. `android/app/build.gradle.kts` stops the release build when that file or the keystore is missing.

## Backup and import

Export and import are in Settings. Import shows a preview, then adds events that are not already stored. It does not replace the events already on the device. A JSON import also writes the settings contained in the file.

JSON is a full backup: events, custom event types, settings, and `schemaVersion` (currently 1). A different `schemaVersion` is rejected.

CSV is events only. The columns are Name, Date, Type, Group, and Notes. The file is UTF-8. Fields that contain a comma, a quote, or a line break are quoted, and a quote inside a field is doubled. The header row can be in any order. Name, Date, and Type are required. A month and day with no year is `MM/DD`. A known year is `YYYY-MM-DD`.

## Google Calendar sync

Sync stays off unless `GOOGLE_SERVER_CLIENT_ID` is set at build time. Without that define, Settings shows Google Calendar sync as unavailable and the app does not contact Google.

When the define is set, sync uses one OAuth scope, `https://www.googleapis.com/auth/calendar.app.created`. Happaroo can create and manage only its own calendar, named "Happaroo Birthdays".

1. In [Google Cloud console](https://console.cloud.google.com/), create a project and enable the Google Calendar API.
2. Under Google Auth Platform, set branding (app name Happaroo, support email, privacy policy URL) and add the `.../auth/calendar.app.created` scope under Data Access.
3. Under Clients, create an Android client for package `com.greinederlabs.happaroo` and the SHA-1 of every key that signs builds you install (local upload key, any sideload or test key, and the Play App Signing key). Also create a Web application client. Its client ID is the `serverClientId`.
4. While the app is in Testing, add your Google accounts under Audience, Test users.
5. Pass the web client ID at build time:

```sh
flutter build appbundle --release --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

## Privacy

The privacy policy URL is [https://happaroo.com/privacy](https://happaroo.com/privacy). The draft is [docs/privacy.md](docs/privacy.md). Serving that draft with GitHub Pages from `/docs` is a DNS task for the owner of happaroo.com.

## Continuous integration

`main` has no GitHub Actions workflow. Run `flutter analyze` and `flutter test` locally. A signed bundle is built on a machine that has `android/key.properties`, with `flutter build appbundle --release`.
