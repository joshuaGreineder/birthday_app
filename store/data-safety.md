# Play Data safety worksheet

This is a form worksheet for the Play Console. It is not the public privacy policy. Facts below are taken from the current code. Do not claim a control the app does not implement.

Package: `com.greinederlabs.happaroo`  
Privacy policy URL: https://happaroo.com/privacy  
Calendar sync in v1: off (`kCalendarSyncEnabled` is false). The calendar code and `google_sign_in` / `googleapis` stay in the project and are not called at startup.

## What the app stores on the device

- Hive box `events`: names, dates, notes, and event type that the user enters or imports.
- Hive box `settings`: reminder on/off, reminder days, reminder time, theme, and list filters.
- Hive box `custom_event_types`: labels and colors the user creates.
- SharedPreferences `widget_data`: the next event's name, date text, and countdown for the home-screen widget.

There is no app backend, no account system, no analytics SDK, and no ad SDK. A search of `lib/` shows network use only inside `GoogleCalendarService`, and that service returns before creating `GoogleSignIn` or calling the Calendar API while the flag is false.

## Data collected

Play's "collected" question is about data transmitted off the device. From this code:

- The app does not transmit contacts, names, dates, or notes to a Happaroo server. There is no such server.
- Contacts are read only after the user chooses Import from contacts and allows `READ_CONTACTS`. Names and birthdays the user keeps are copied into the local Hive box. They are not uploaded by the app.
- User-entered event names and dates are stored locally the same way.
- Notifications are shown by the device. There is no push provider.

Answer **no** for analytics, advertising ID, crash logs collected by the developer, precise or coarse location, financial info, messages, photos, audio, files, calendar (v1 does not sync), app interactions / search history sent off device, and device or other identifiers sent to the developer.

If the form asks whether contact names or user-entered event details are **collected**, answer from the "transmitted off the device" definition: this app does not send them. Say they are stored on device for app functionality. Do not invent a different toggle if the form's wording changes; match the form to the facts above.

## Data shared with third parties

**None in v1.** The app does not sell data and does not transfer it to a third party.

`google_sign_in` is still a dependency, so its Android library merges `INTERNET`. v1 does not call sign-in and does not send event data to Google. Do not declare calendar data as shared while the flag stays false. If the flag is turned on later, this worksheet has to be redone before that build ships: the current client would send an event title, notes, and date to the user's Google Calendar.

## Security practices you can state

- Data is stored in the app's private local storage (Hive and the widget preferences file).
- The app does **not** implement its own encryption at rest. Do not check "data is encrypted in transit" or "data is encrypted at rest" as something Happaroo does. There is no network payload in v1 to encrypt.
- Users can delete individual events in the app.
- Settings says Clear all data deletes events. The code deletes events only. It does not wipe settings or custom event types. Do not claim a full account-deletion or "delete all app data" feature.
- Uninstalling the app removes its sandbox data from the device. There is no remote copy to request deletion of.
- `android:allowBackup` is unset, so Android's default (backup allowed) applies. The device's own Android backup may include the local database in the user's device backup. That is not a Happaroo server. Do not describe it as data the developer collects. Mention it if the form asks about backup.

## Questions to answer no

- Analytics collected
- Advertising or ads
- Data sold
- Data shared with third parties
- Account creation, or credentials / user IDs for an account
- Crash reporting or diagnostics sent to the developer
- Calendar sync (v1)

## Permissions that relate to the form

- `POST_NOTIFICATIONS`: reminders, requested when the user turns reminders on.
- `READ_CONTACTS`: import, requested when the user chooses import.
- `RECEIVE_BOOT_COMPLETED`: restores on-device reminders after reboot.
- `VIBRATE`: reminder vibration.
- `INTERNET`: merged by `google_sign_in` because that dependency stays. Not used for v1 product traffic.
- Exact-alarm and ignore-battery-optimization permissions are removed and stripped if a plugin merges them.
