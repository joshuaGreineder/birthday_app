# Happaroo

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Google Calendar sync setup

Sync uses one Google OAuth scope, `calendar.app.created`, so Happaroo can create and manage only its own "Happaroo Birthdays" calendar.

1. In [Google Cloud console](https://console.cloud.google.com/), create a project and enable the **Google Calendar API**.
2. Under **Google Auth Platform**, set up branding (app name Happaroo, support email, privacy policy URL) and add the `.../auth/calendar.app.created` scope under **Data Access**.
3. Under **Clients**, create:
   - an **Android** client for package `com.greinederlabs.happaroo` and the SHA-1 of every key that signs builds you install (local upload key, any sideload or test key, and the Play App Signing key from Play Console > Test and release > App integrity);
   - a **Web application** client. Its client ID is the `serverClientId`.
4. While the app is in **Testing**, add your Google accounts under **Audience > Test users**.
5. Build with the web client ID:

   ```
   flutter build appbundle --release --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
   ```

Without the define, Settings shows Google Calendar sync as unavailable and the app never contacts Google.
