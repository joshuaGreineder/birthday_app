# Phase 1 release-readiness audit

Audit only. No application code was changed. Fixes below are recommendations for later phases, after review.

Reviewed on 2026-11-07 from branch `release-prep` (cut from `main` at `daec072`, "Initial commit"). Scope: `lib/`, `test/`, `android/`, `ios/`, `web/`, desktop scaffolding, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `README.md`, and the repo-root scripts. There is no `.github/` CI.

Severity counts: **4 Blocker, 9 High, 8 Medium, 5 Low.**

Phase 2 is blocked on the open decisions at the end of this file. Do not invent those values. Do not add a dependency, remove a feature, or change the Hive model without asking.

## Store blockers

### B1. Package and bundle IDs are still the Flutter example IDs

**What.** The Android application id and namespace are `com.example.birthday_app`. iOS and macOS use `com.example.birthdayApp` (camel case, different string). Linux uses `com.example.birthday_app`.

**Where.**

- `android/app/build.gradle.kts` lines 9 and 26–27 (`namespace`, `applicationId`), with the template TODO still in place
- `android/app/src/main/kotlin/com/example/birthday_app/` (every Kotlin file's `package` line)
- Method channels in `lib/services/widget_service.dart` line 45, `lib/services/notification_service.dart` lines 23–24, and `MainActivity.kt` lines 20–21 and 27
- `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER = com.example.birthdayApp`)
- `macos/Runner/Configs/AppInfo.xcconfig` line 11
- `linux/CMakeLists.txt` line 10

**Why it blocks release.** A Play listing needs an application id the publisher owns. `com.example` is the Android sample prefix, and the Gradle file still says to replace it. Shipping it also locks the id: later installs cannot move local Hive data to a new id without a migration. iOS, macOS, and Linux do not even match the Android id.

**Fix (not applied).** Choose `{package_id}` first. Rename the namespace, Kotlin package, method-channel strings, and every platform bundle id in one change. Do not publish under `com.example`.

### B2. The release build is signed with the debug key

**What.** `release` uses `signingConfigs` named `debug`. There is no `key.properties`, and `android/.gitignore` correctly ignores `key.properties` and `*.jks` / `*.keystore`. None of those files are in the repo.

**Where.** `android/app/build.gradle.kts` lines 36–41. `GOOGLE_CALENDAR_SETUP.md` also tells the reader to register the debug keystore SHA-1.

**Why it blocks release.** Play App Signing needs a private upload key that is not the public Android debug key. A release APK or AAB built today is signed with the debug certificate. That key cannot be the long-term upload key, and any Google OAuth Android client registered against the debug SHA-1 will not match a real release certificate.

**Fix (not applied).** Create an upload keystore outside the repo, wire a release `signingConfig` through `key.properties` (still gitignored), and register that SHA-1 in Google Cloud only if calendar sync stays.

### B3. No privacy policy, while the app reads contact data

**What.** Nothing in the app, README, or settings links to a privacy policy. `{privacy_policy_url}` was left unset and is not invented here.

**Where.** Settings "About" is only a title and a hardcoded version (`lib/screens/settings_screen.dart` lines 802–806). No `privacy` string exists under `lib/`, the manifests, or the plists.

**Why it blocks release.** The app reads contact names and birthdays (`READ_CONTACTS`, and the iOS contacts APIs). Play's submission flow requires a privacy-policy URL for apps that handle personal information. The in-app About screen is also the natural place to show it, and it does not. Data-safety answers for the Console are not in the repo either.

**Fix (not applied).** Publish `{privacy_policy_url}`, link it from Settings, and fill the Play Data safety form from the "Data safety" section below. Do not ship the contacts importer without that URL.

### B4. iOS will crash, and App Store review will reject it, if contacts are used

**What.** `ios/Runner/Info.plist` has no `NSContactsUsageDescription`. The contacts importer calls `Permission.contacts` and `FlutterContacts.requestPermission` / `FlutterContacts.getContacts`.

**Where.** `ios/Runner/Info.plist` (full file, 49 lines, no usage-description keys). Call sites: `lib/services/contact_parser_service.dart` lines 23–46. Settings starts that path from `_importFromContacts` (`lib/screens/settings_screen.dart` line 856).

**Why it blocks release.** On iOS, touching contacts without that key throws and terminates the process. App Review also rejects the binary for the missing purpose string. This is a blocker only if `{include_ios}` is yes. Android is unaffected by this plist key. Answer `{include_ios}` before any iOS work; do not "fix" iOS in the Android-only path if the answer is no.

**Fix (not applied).** If iOS ships: add `NSContactsUsageDescription` in the same change as the other iOS gaps in H9. If iOS does not ship: leave the plist, and do not list an iOS binary.

## High

### H1. February 29 is wrong in a non-leap year

**What.** `DateTime(year, month, day)` rolls an invalid day into the next month. `DateTime(2025, 2, 29)` is 1 March 2025, not an exception. The leap-day correction runs after that overflow, and it uses the wrong year boundary.

**Where.** `lib/utils/event_calculator.dart`

- `getNextOccurrence` lines 12–34
- `getAge` lines 120–151
- `getYearsTogether` lines 171–201 (same pattern)
- Calendar match is exact month/day only: `getEventsForDate` lines 237–241 and `lib/widgets/custom_calendar.dart` lines 69–73

**Why it risks a bad release.** Concrete non-leap year, birthday 29 Feb 2000, "today" in 2025:

- On 1 Feb through 27 Feb, `getAge` subtracts twice (once because the overflowed "birthday" is 1 Mar, then again in the `day < 28` branch). The card says the person is a year younger than they are and "Turning" the wrong age.
- On 28 Feb the next-occurrence adjustment lands on today, so the countdown happens to look right.
- On 1 Mar, `getNextOccurrence` first becomes 1 Mar (the overflow), which is not before today, then the leap adjustment rewrites it to 28 Feb of the same year. That date is in the past, so `getUpcomingEvents` (lines 213–220) drops the person for that day. The calendar never has a 29 Feb cell in 2025, so the event is also missing there. `getDaysUntil` would be negative if anything still rendered it (`"$daysUntil days"`).

Anniversaries on 29 Feb use the same helper.

**Fix (not applied).** Build the candidate with an explicit leap check before calling `DateTime`. In non-leap years, observe the birthday on 28 Feb (or 1 Mar — pick one and use it everywhere, including the calendar). Add unit tests around 27 Feb, 28 Feb, 1 Mar, and the next leap day. Do not change the Hive date field.

### H2. Day counts are short by one whenever the span includes a spring-forward

**What.** `getDaysUntil` uses `DateTime.difference(...).inDays`. `inDays` is whole 24-hour chunks. A local midnight-to-midnight span that includes the DST spring-forward is 23 hours short, so the count floors down by one day. Fall-back adds an hour and does not drop a day.

**Where.** `lib/utils/event_calculator.dart` lines 40–50. Every "Today" / "Tomorrow" / "N days" label goes through this, including `EventCard` line 19, home filters line 117, widgets, and notification scheduling.

**Why it risks a bad release.** From 1 Jan until the spring-forward, any event after that transition shows one day too soon. On the morning of the transition, an event the next calendar day reports `0` and is labeled "Today!". US time zones are affected for most events dated March–December, for about two months a year. The bug is in the countdown, not in Hive.

**Fix (not applied).** Count calendar dates (`next.year/month/day` versus `today.year/month/day`) and do not use `Duration.inDays` for a date-only countdown. Cover a spring-forward fixture in `test/`.

### H3. "Turns N" is wrong on the first birthday, and the wording is copied in five places

**What.** `getAge` on the birthday returns completed years, so a first birthday returns `0`. `getBabyAge` treats `age > 0` as "not a baby", so age `0` still takes the baby path and prints "Now 12 months old!" instead of "Now 1 year old!".

Widgets do not use custom-type templates. `EventCalculator.getAgeText` always says "Nth anniversary" for anything that is not `EventType.birthday`. `EventCard` does use `turningTextTemplate` / `nowTextTemplate` / `currentTextTemplate`. The home-screen widget therefore describes a custom event as an anniversary.

For a real infant, `getAgeText` always says "Turning 1 year" even when the birthday is months away (lines 277–279). That part is commented as intentional. The first-birthday line is not.

**Where.**

- `lib/utils/event_calculator.dart` `getAge` lines 129–134, `getBabyAge` lines 64–67, `getAgeText` lines 256–311
- Duplicated formatters: `lib/widgets/event_card.dart` lines 76–158, `lib/screens/timeline_screen.dart` around lines 376–419, `lib/screens/calendar_screen.dart` around lines 313–351, `lib/services/notification_service.dart` `_formatNotificationMessage` lines 445–475
- Widget text: `lib/services/widget_service.dart` lines 48–49

**Why it risks a bad release.** The first birthday is the message users will screenshot. Custom event types are a visible feature whose templates are ignored on the home-screen widget.

**Fix (not applied).** One formatter used by cards, timeline, calendar, notifications, and widgets. On the birthday, decide "under 1 year" from the birth date, not from the pre-increment age. Pass the custom type into that formatter. Keep `{years}` templates; do not change the Hive fields.

### H4. Reminders are scheduled on AlarmManager and then cannot be cancelled or restored

**What.** Dart asks the Android channel to `cancelAllNotificationAlarms`. `MainActivity` never handles that method. The private Kotlin function exists and is unused. Turning notifications off only calls the Flutter plugin's `cancelAll`, which does not cancel `AlarmManager`. Deleting an event reschedules by stacking new alarms on ids 100+, but ids that are no longer used stay armed. "Clear all data" deletes Hive events and does not touch alarms or widgets, while the dialog says settings are deleted too.

After reboot, `AlarmManager` drops these alarms. `BootReceiver.onReceive` only logs. Its manifest filter also includes `<data android:scheme="package" />`, which applies to the whole filter, so `BOOT_COMPLETED` (no data URI) does not match. The receiver would not run even if it did schedule work.

The same-day notification body is built when the alarm is scheduled, not when it fires. If the event is not today at schedule time, `daysBefore == 0` falls through to "in 0 days" (`notification_service.dart` lines 398–404 and 458–461). The title still says "Today:".

If exact-alarm access is missing, `scheduleNotificationAlarm` logs and returns. Dart still gets `result.success(true)` (`MainActivity.kt` lines 77–86 and 156–167). The user sees a successful schedule and gets no notification. The normal permission path only requests `Permission.notification` (`notification_service.dart` lines 160–185). Exact-alarm settings are buried in the debug status dialog (`settings_screen.dart` lines 131–144).

`NotificationReceiver` is `exported="false"` (good) but also listens for `BOOT_COMPLETED` and does not check the action. A delivered boot broadcast would post a placeholder "Event Reminder". The status-bar icon is the color launcher mipmap (`NotificationReceiver.kt` lines 45–52), which the system may blank out.

iOS never gets these alarms: the method channel exists only in `MainActivity.kt`. Scheduling throws `MissingPluginException`, which is swallowed. See H9.

**Where.**

- `lib/services/notification_service.dart` lines 313–323, 346–436, 445–461
- `android/app/src/main/kotlin/com/example/birthday_app/MainActivity.kt` lines 61–95 (handler) and 195–216 (unwired cancel, ids 100–999 only)
- `android/app/src/main/kotlin/com/example/birthday_app/BootReceiver.kt` lines 9–18
- `android/app/src/main/AndroidManifest.xml` lines 54–75
- `lib/screens/settings_screen.dart` lines 94–97 and 226–270
- `lib/screens/add_edit_event_screen.dart` lines 137–144

**Why it risks a bad release.** A reminder app that keeps notifying after delete, stays silent after reboot, and shows "in 0 days" will get the 1-star reviews. This is not a Play form blocker by itself. H5 is the policy half.

**Fix (not applied).** Wire `cancelAllNotificationAlarms` and call it when notifications are disabled, when events are deleted, and when data is cleared. Reschedule from `BootReceiver` without depending on a Flutter engine, or document that the user must open the app and then actually do it. Build the day-of body from `daysBefore`, not from "is the event today right now". If exact alarms are denied, do not report success. Drop the boot filter from `NotificationReceiver`. Use a white status-bar icon.

### H5. Exact-alarm and battery-optimization permissions are a Play policy exposure

**What.** The manifest declares both exact-alarm permissions and the battery-exemption permission. The app is a personal event reminder, not an alarm clock.

**Where.** `android/app/src/main/AndroidManifest.xml` lines 2–9:

- `POST_NOTIFICATIONS` (see the permissions section: this one is requested at runtime)
- `SCHEDULE_EXACT_ALARM`
- `USE_EXACT_ALARM`
- `READ_CONTACTS`
- `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `VIBRATE`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

The battery prompt is `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` in `MainActivity.kt` lines 121–126, reached from the status dialog (`settings_screen.dart` lines 146–159).

**Why it risks a bad release.** Checked against Android's docs on 2026-11-07, not against a Play rejection email:

- [`Schedule alarms`](https://developer.android.com/develop/background-work/services/alarms): `USE_EXACT_ALARM` is granted automatically, cannot be revoked, is limited to specific use cases, and is "subject to an upcoming Google Play policy". `SCHEDULE_EXACT_ALARM` is the user-granted permission for a broader set of apps. This app declares both. `USE_EXACT_ALARM` alone is enough for Play to review the declaration.
- [`Optimize for Doze and App Standby`](https://developer.android.com/training/monitoring-device-state/doze-standby): "Google Play policies prohibit apps from requesting direct exemption from Power Management features … unless the core function of the app is adversely affected." The permission is in the manifest even though the button is buried, and Play reviews the manifest.

`setExactAndAllowWhileIdle` already asks for exact timing. A battery exemption is a second, stricter ask and is not required for the reminder to fire.

**Fix (not applied).** Remove `USE_EXACT_ALARM` unless a Play review confirms this app qualifies. Keep `SCHEDULE_EXACT_ALARM`, and request it on the main notifications toggle, not only in the debug dialog. Remove `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` and the direct exemption intent. Do this before the first upload. The Console declaration forms will ask about whatever is still in the manifest.

### H6. Hive is opened from several widgets at once, and the saved theme is read too early

**What.** `StorageService.init` returns immediately only after `_initialized` is set. That flag is set at the end. `main`, and every tab in the `IndexedStack`, call `init` during startup. Two overlapping `Hive.openBox` calls on `events` can throw. Home turns that into the error string on screen (`home_screen.dart` lines 66–71).

The theme is loaded in a microtask from `initState`, which runs before the background `storage.init()` future completes. `getSetting` on a null box returns the default `'system'` and does not retry. A saved dark or light theme is ignored for the rest of the process.

**Where.**

- `lib/services/storage_service.dart` lines 24–49
- `lib/main.dart` lines 21–28 and 97–120
- `lib/main.dart` `IndexedStack` lines 316–323 (all four screens build immediately)
- `lib/screens/home_screen.dart` lines 51–54, `timeline_screen.dart` line 45, `calendar_screen.dart` line 31, `settings_screen.dart` lines 45–47

**Why it risks a bad release.** Startup is the first session a reviewer runs. An exception dialog, or a theme that does not match the saved setting, looks like a broken build. `addEvent` also no-ops if the box is still null (`storage_service.dart` line 54), so a save during that window drops the event.

**Fix (not applied).** One in-flight `Future` for `init`, awaited by `main` before `runApp`, or awaited by the first screen before the others read. Load the theme after that future. Keep Hive. Do not change box names or field indexes.

### H7. Contact import drops birthdays that have no year, and treats denial as "none found"

**What.** The parser requires `year`, `month`, and `day` to all be non-null (lines 165–172). Many contacts store a birthday with no year. Those people are skipped. A denied permission also returns an empty list (lines 29–32). Settings then says "No birthdays found in contacts" (`settings_screen.dart` lines 874–886). The user cannot tell denial from an empty address book.

The same function accepts any label string containing `"birth"` (lines 92–93), so a custom label such as "birthplace" can match. Invalid dates such as 31 Feb are passed to `DateTime`, which rolls them over (line 173).

**Where.** `lib/services/contact_parser_service.dart` lines 16–38 and 156–180. UI: `lib/screens/settings_screen.dart` lines 856–886.

**Why it risks a bad release.** Import is the main way a birthday app gets its first data. Silent data loss plus a wrong empty-state will look like the feature does not work. On Android the permission itself is wired correctly (see the permissions section). This is a logic bug on top of that, not a missing manifest entry.

**Fix (not applied).** If year is missing, store month and day with an explicit sentinel the age formatter understands, or ask the user for a year before saving. Return a distinct "permission denied" result and show that in the snackbar. Do not add a contacts package; `flutter_contacts` is already the reader. A major upgrade of that package is a separate decision (M4) and would rewrite this parser.

### H8. The product name and the version the user sees do not match the binary

**What.** Confirmed, not just suspected.

| Surface | Name |
| --- | --- |
| Android launcher label, APK rename, in-app title | Event Tracker |
| iOS display name | Birthday App |
| iOS bundle name, pubspec name, web manifest, Windows product name, Linux window title | birthday_app |
| Settings subtitle | Version 1.0.0 |
| `pubspec.yaml` | `2.0.0+3` (Android `versionName` 2.0.0, `versionCode` 3) |

**Where.**

- `android/app/src/main/AndroidManifest.xml` line 11
- `android/app/build.gradle.kts` line 47 (`EventTracker-v…apk`)
- `lib/main.dart` line 139, `lib/screens/home_screen.dart` line 214, `lib/screens/settings_screen.dart` lines 803–806
- `ios/Runner/Info.plist` lines 8 and 16
- `pubspec.yaml` lines 1 and 19
- `web/manifest.json` lines 2–3, `web/index.html` line 35
- `windows/runner/Runner.rc` product name, `linux/runner/my_application.cc` lines 48–52

**Why it risks a bad release.** Play and the App Store will show whatever is typed into the Console, but the binary the reviewer installs will say something else. Settings advertising 1.0.0 while the binary is 2.0.0+3 will fail a "does the version match" check. `{app_name}` is still unset.

**Fix (not applied).** Pick `{app_name}` and use it for the Android label, iOS display name, MaterialApp title, and About line. Read the version from the package info instead of hardcoding `1.0.0`. Web and desktop can follow in the same change if those targets ship; they are not the Play binary.

### H9. The iOS tree cannot be archived as it sits

**What.** Gated on `{include_ios}`. If the answer is no, do not spend the Android release on these. If the answer is yes, these block the App Store beside B4.

- `ios/Podfile` is not in the tree (`Test-Path` is false). `flutter build ios` / CocoaPods has nothing to install. `ios/.gitignore` ignores `Pods/` but not a Podfile.
- No `PrivacyInfo.xcprivacy` anywhere in the repo. Apple requires a privacy manifest for required-reason APIs. This audit did not archive an iOS build, so it does not claim the Flutter tool would inject one later.
- `pubspec.yaml` `flutter_launcher_icons` sets `ios: false` (lines 74–80). The checked-in iOS app icon is the default Flutter logo. Android's launcher art is a different, custom mark (`assets/icon.png` and the mipmap PNGs).
- Notifications and the timezone channel are Android-only (H4). `DarwinInitializationSettings` requests permission (`notification_service.dart` lines 80–84) and then scheduling throws.
- `permission_handler` on iOS compiles permission groups out unless the Podfile sets the preprocessor flags. There is no Podfile to set `PERMISSION_CONTACTS` or `PERMISSION_NOTIFICATIONS`.
- No Google Sign-In URL scheme or client id in `Info.plist`. Irrelevant until `{calendar_sync}` is yes.

**Where.** `ios/` (directory listing: Flutter, Runner, Runner.xcodeproj, Runner.xcworkspace, RunnerTests, `.gitignore`), `ios/Runner/Info.plist`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `pubspec.yaml` lines 74–80.

**Why it blocks an iOS release.** Missing Podfile means no archive. The default Flutter icon and a missing contacts purpose string are review failures. Reminders would not fire.

**Fix (not applied).** Wait for `{include_ios}`. If yes: generate the Podfile with the permission flags, add the usage string and a privacy manifest, run launcher icons for iOS from `assets/icon.png`, and implement scheduling without the Android method channel. If no: do not touch this tree in the Android release PR.

## Medium

### M1. Google Calendar sync is unused, and the implementation would not work

**What.** `GoogleCalendarService` is never imported outside `lib/services/google_calendar_service.dart`. `ContactParserService.parseGoogleCalendar` returns an empty list and says it is unimplemented (`contact_parser_service.dart` lines 253–256). No screen calls sign-in.

If something did call `syncEventToCalendar`, the all-day payload is wrong. Calendar API `start.date` is a `yyyy-mm-dd` string. The code passes a map of year/month/day (`google_calendar_service.dart` lines 83–97). `events.insert` would throw, and the `catch` returns false. Each successful insert would also add another yearly event; nothing stores the Google event id, so there is no update or delete. Scopes are full `calendar` and `calendar.events`, not a single-calendar write. The recurrence is built from `getNextOccurrence`, so a 29 Feb event in a non-leap year would recur on the wrong day (H1).

`web/index.html` line 24 has a `google-signin-client_id` meta tag. That is an OAuth client id, which a web app is expected to expose. It is not a client secret. This audit does not repeat the id. No client secret or API-key file is in the repo.

**Why it matters.** `{calendar_sync}` is unset. Leaving the code in means the binary contains a Google sign-in stack that the UI cannot start, with scopes that would read and write the user's whole calendar if it were hooked up. Turning it on without a fix would fail and, if the date bug were patched carelessly, would duplicate events.

**Fix (not applied).** If `{calendar_sync}` is no: ask, then remove the service and the three packages it alone uses (`google_sign_in`, `googleapis`, `http`). If yes: fix the date payload, store the remote event id, narrow the scopes, and put sign-in behind a settings control that names Google. Do not add a backend.

### M2. The home-screen widget shows a snapshot from the last time the app ran

**What.** `SingleEventWidgetProvider` is registered and `exported="true"`, which a home-screen widget needs. `updatePeriodMillis` is 3600000 (`widget_single_event_info.xml` line 4). `onUpdate` only re-reads `widget_data` SharedPreferences. It does not recompute "days until". After a day, the widget still says "Tomorrow" until the Flutter process runs `WidgetService.updateWidgetData`.

`EventWidgetProvider` is not a manifest receiver. `MainActivity.updateAllWidgets` calls its static helper, so the single widget still updates. The "three events" strings and preference keys are written and never displayed (`strings.xml` has `widget_three_events_description`; there is no second provider).

If the method channel throws, the Dart fallback writes Flutter `SharedPreferences`, not the `widget_data` file the widget reads (`widget_service.dart` lines 92–124).

**Fix (not applied).** Recompute the countdown in the provider, or schedule a midnight update. Point the fallback at `widget_data`, or delete it. Decide whether the three-event widget is in v1 before writing more preference keys.

### M3. "Clear all data" does not clear all data

**What.** The dialog says events and settings are deleted. The code deletes events only. Custom event types, notification settings, and the theme remain. Alarms and the widget are not updated (H4).

**Where.** `lib/screens/settings_screen.dart` lines 238–260.

**Fix (not applied).** Either clear the three Hive boxes and cancel alarms, or change the copy. Keep the Hive model.

### M4. Direct dependencies versus pub.dev latest

`flutter pub outdated` could not be run (see Commands). The table is from `pubspec.lock` and the pub.dev package API (`latest.version`) fetched on 2026-11-07. A major bump is called out as breaking. Changelogs were not fully reviewed, so a same-major bump is not labeled breaking. Do not upgrade in this phase.

| Package | Constraint | Locked | Latest on pub.dev | Breaking? |
| --- | --- | --- | --- | --- |
| cupertino_icons | ^1.0.8 | 1.0.8 | 2.0.0 | Yes, 1 to 2. Also unused (L1). |
| hive | ^2.2.3 | 2.2.3 | 2.2.3 | No. Already latest. Stay on Hive. |
| hive_flutter | ^1.1.0 | 1.1.0 | 1.1.0 | No. Already latest. |
| flutter_local_notifications | ^17.2.3 | 17.2.4 | 23.0.0 | Yes, 17 to 23. Latest pubspec requires `timezone: ^0.11.0`. |
| timezone | ^0.9.4 | 0.9.4 | 0.11.2 | Treat as breaking. 0.10+ is a different API generation, and 23.x of the notifications plugin will not resolve against 0.9. |
| intl | ^0.19.0 | 0.19.0 | 0.20.3 | Treat as breaking. 0.x bumps often conflict with the Flutter SDK pin. |
| permission_handler | ^11.3.1 | 11.4.0 | 13.0.2 | Yes, 11 to 13. |
| shared_preferences | ^2.3.3 | 2.5.4 | 2.5.6 | No. Same major. |
| googleapis | ^13.0.0 | 13.2.0 | 17.0.0 | Yes, 13 to 17. Only used by the unwired calendar client. |
| google_sign_in | ^6.2.1 | 6.3.0 | 7.2.0 | Yes, 6 to 7. Current code calls `GoogleSignIn(scopes: …)` (`google_calendar_service.dart` lines 24–29), which is the v6 constructor. Read the 7.x migration before editing it. |
| http | ^1.2.2 | 1.6.0 | 1.6.0 | No. Already latest. |
| flutter_contacts | ^1.1.7+1 | 1.1.9+2 | 2.6.0 | Yes, 1 to 2. The importer uses dynamic property access against the 1.x event shape (H7). A major bump is a parser rewrite. |
| flutter_lints (dev) | ^6.0.0 | 6.0.0 | 6.0.0 | No. |
| hive_generator (dev) | ^2.0.1 | 2.0.1 | 2.0.1 | No. |
| build_runner (dev) | ^2.4.13 | 2.4.13 | 2.17.1 | Same major. Large minor jump. Not required for the store binary. |
| flutter_launcher_icons (dev) | ^0.14.4 | 0.14.4 | 0.14.4 | No. |

`google_sign_in` 7.2.0, `googleapis` 17.0.0, `flutter_local_notifications` 23.0.0, `flutter_contacts` 2.6.0, and `permission_handler` 13.0.2 are the majors to plan, not to apply here. Hive has no newer pub.dev release. Do not replace it with another database without asking.

### M5. Generated reports and device-debug scripts are in the public tree

**What.** `android/build/reports/problems/problems-report.html` is tracked. Root `.gitignore` ignores `/build/` only, so `android/build/` is not ignored. `android/.gitignore` does not ignore it either.

These PowerShell scripts are tracked at the repo root: `pair_device.ps1`, `setup_wireless.ps1`, `connect_device.ps1`, `troubleshoot_wireless_debug.ps1`, `wireless_debug_setup.ps1`. `pair_device.ps1` hardcodes an adb path under a developer profile and a LAN address. This audit does not repeat either value. They are not packaged into the APK. They do not belong in a public repo.

**Why it matters.** Not a Play binary defect. It is release-repo hygiene, and the script leaks a local network address.

**Fix (not applied).** Stop tracking `android/build/` and the scripts. Add ignore rules. Do not delete them in this phase.

### M6. Tests and docs do not cover the release

**What.** `test/widget_test.dart` is the only test. It pumps `EventTrackerApp` once and expects the text `Event Tracker`. The first frame of `HomeScreen` is the loading state ("Loading events..."), and the title is drawn later, after Hive init (`home_screen.dart` lines 165–179 versus 214). One `pumpWidget` does not wait for that future. This was not executed (Commands). From the code, the smoke test fails, and it never reaches a date, a notification, or a contact.

`README.md` is the Flutter starter ("A new Flutter project."). There is no CI workflow. `analysis_options.yaml` is the default `flutter_lints` include, with no extra rules. `{coverage_target}` for `lib/utils` and `lib/services` is unset.

**Fix (not applied).** After `{coverage_target}` is chosen, add tests for `EventCalculator` (H1, H2, H3) and for notification message text. Replace the README when the name is chosen. CI can wait until a machine with the Flutter SDK exists.

### M7. Backup, notification artwork, and the font

**What.**

- `android:allowBackup` is unset, so the platform default (true) applies. Hive files (names, birth dates, notes) can be included in the device Google backup. That is a data-safety answer, not an app server.
- The notification small icon is the full-color launcher (H4).
- `fontFamily: 'Segoe UI'` is set in both themes (`lib/main.dart` lines 169 and 243). Android and iOS do not ship that font. Flutter falls back. It will not crash. The type will not match what a Windows dev build shows.

**Fix (not applied).** Set an explicit backup rule that matches the Data safety form. Ship a monochrome notification icon. Drop the Segoe family or bundle a font.

### M8. Infant ages and future imported dates can go nonsense

**What.** `getBabyAge` builds `DateTime(year, month - 1, birthDay)` (lines 96–98). A birth day of 31 in a 30-day month, or 29–31 into February, overflows, and the leftover day count is wrong. The date picker refuses future dates (`add_edit_event_screen.dart` lines 59–63, `lastDate: DateTime.now()`), but contact import can still store a future year. `getAge` then goes negative and the card can say "Turning 0" or a negative age.

**Fix (not applied).** Clamp the day to the length of the month. Reject or confirm future contact dates before insert.

## Low

### L1. Dead code and an unused direct dependency

- `cupertino_icons` is in `pubspec.yaml` and is not referenced. No `CupertinoIcons` use under `lib/`.
- `NotificationService.checkAndSendNotifications` (`notification_service.dart` lines 439–443) has no callers.
- `ContactParserService.parseGoogleCalendar` is a stub (M1).
- `Event.copyWith` and `CustomEventType.copyWith` cannot clear a nullable field, because null means "keep". Nothing in the screens uses `Event.copyWith` to save. The editor builds a new `Event` instead, and that path can store a null custom-type id (`add_edit_event_screen.dart` lines 76–83).

**Fix (not applied).** Ask before removing `cupertino_icons` or the calendar stub. Leaving the copyWith footgun is fine until something calls it.

### L2. R8 is off

**What.** `buildTypes.release` does not set `isMinifyEnabled` or `isShrinkResources`. There are no ProGuard keep rules. Flutter's default is minify off, so this is not a crash today. The release APK is larger than it needs to be, and turning minify on later without keep rules for the notification and widget stack would crash.

**Where.** `android/app/build.gradle.kts` lines 36–41.

**Fix (not applied).** Optional for v1. If minify is enabled, add the keep rules in the same change and run a release build.

### L3. `INTERNET` is not in the app manifest

**What.** `INTERNET` is only in `android/app/src/debug/AndroidManifest.xml` and `src/profile/AndroidManifest.xml` (the Flutter tool comments). The main manifest does not declare it, and it does not set `usesCleartextTraffic`. Cleartext is not enabled. A release merge still picks up `INTERNET` from plugins such as `google_sign_in` while those plugins stay in the graph. If M1 removes them, a release build has no `INTERNET` of its own, which is correct for a local-only app.

### L4. Desktop and web still use the template identity

Covered by the names in H8. Extra: macOS bundle id `com.example.birthdayApp` and copyright "Copyright © 2025 com.example" (`macos/Runner/Configs/AppInfo.xcconfig`). macOS Release entitlements enable the sandbox and do not grant network client. Web manifest description is "A new Flutter project." and the theme color is the Flutter blue `#0175C2` (`web/manifest.json`). Not part of the Play AAB. Fix only if those targets ship.

### L5. Version code 3 is fine for a first upload

`pubspec.yaml` `version: 2.0.0+3` becomes Android `versionName` 2.0.0 and `versionCode` 3. Nothing in the repo shows a previous Play upload. Do not reset it. The user-visible "Version 1.0.0" is H8, not this.

## Permissions, checked against the code

Main manifest (`android/app/src/main/AndroidManifest.xml` lines 2–9). Debug and profile add only `INTERNET`.

| Permission | In the manifest? | What the app does | Runtime request? |
| --- | --- | --- | --- |
| `POST_NOTIFICATIONS` | Yes | Reminders | Yes. `Permission.notification.request()` in `notification_service.dart` lines 160–173. Called on startup when notifications are enabled, which defaults to true (`main.dart` lines 52–57, `storage_service.dart` lines 115–116), and again from Settings (`settings_screen.dart` line 73). |
| `SCHEDULE_EXACT_ALARM` | Yes | `setExactAndAllowWhileIdle` | Not on the main path. Checked via `canScheduleExactAlarms`. The settings screen that opens the system page is the debug status dialog. See H4 and H5. |
| `USE_EXACT_ALARM` | Yes | Same alarms | Granted at install if Play allows the declaration. User cannot revoke it. Policy risk: H5. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Yes | Status dialog button | Not at startup. The button sends the direct exemption intent. Policy risk: H5. |
| `READ_CONTACTS` | Yes | Import on demand | Yes, when the user imports (`contact_parser_service.dart` lines 23–38). Not at startup. Denial is reported as "no birthdays" (H7). |
| `RECEIVE_BOOT_COMPLETED` | Yes | `BootReceiver` logs only | n/a. The filter is also wrong (H4). |
| `WAKE_LOCK` | Yes | 10-second partial wake lock in `NotificationReceiver` | n/a |
| `VIBRATE` | Yes | Notification defaults | n/a |

`queries` in the app manifest is only `ACTION_PROCESS_TEXT` (lines 82–87), the Flutter template. Plugin manifests are merged at build time. This audit could not run a Gradle manifest merge because the Flutter SDK is not installed, so it does not claim the merged `queries` set.

Exported components:

- `MainActivity` `exported="true"` with `MAIN` / `LAUNCHER`. Required.
- `SingleEventWidgetProvider` `exported="true"`. Required for an app widget. It has no extra custom action.
- `BootReceiver` `exported="true"`. Broader than it needs to be, and it does no work (H4).
- `NotificationReceiver` `exported="false"`. Good. The boot action on it is not (H4).

`debugShowCheckedModeBanner` is false (`lib/main.dart` line 140). That suspected item is not a problem.

## targetSdk and the Play rule

**App Gradle.** `android/app/build.gradle.kts` lines 10 and 30–31 set `compileSdk = flutter.compileSdkVersion`, `minSdk = flutter.minSdkVersion`, and `targetSdk = flutter.targetSdkVersion`. They are not pinned in the repo. The binary's API level is whatever SDK builds it.

**Local SDK.** Not installed on this machine. `flutter --version` did not run. There is no `android/local.properties` (gitignored, and absent). This audit could not read a local `flutter.gradle`.

**What was checked instead.** `.metadata` records stable revision `f6ff1529fd6d8af5f706051d9251ac9231c83407`. At that revision, `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt` on GitHub sets `compileSdkVersion = 36`, `targetSdkVersion = 36`, `minSdkVersion = 24`, `ndkVersion = 28.2.13676358`. A version *name* (the `3.x.y` string) was not read. Do not treat 36 as "whatever is on this PC"; this PC has no Flutter.

**Play rule, checked 2026-11-07** from [Meet Google Play's target API level requirement](https://developer.android.com/google/play/requirements/target-sdk) and [Play Console Help](https://support.google.com/googleplay/android-developer/answer/11926878):

- New apps and updates must target Android 16 (API 36) or higher to be submitted, starting 31 August 2026.
- An extension to 1 November 2026 is described on that page. The audit date is 7 November 2026, after that extension date.
- Existing apps must target API 35 or higher to stay available to new users on newer Android versions. This app has no existing Play listing in the repo.

If the release is built with the SDK revision recorded in `.metadata`, `targetSdk` 36 meets that rule. If it is built with an older SDK, it may not. Re-check with `flutter build appbundle` on a machine that has Flutter, and read `targetSdk` out of the merged manifest. This is not, by itself, a confirmed failure of the current template.

## Data safety

There is no app backend, no account system, no analytics SDK, and no ad SDK.

What stays on the device:

- Hive boxes `events`, `settings`, and `custom_event_types` (`storage_service.dart` lines 8–10): names, dates, notes, custom-type labels and colors, notification time, theme.
- Widget snapshot in the `widget_data` SharedPreferences file: the next event's name and the age sentence.

What can leave the device:

- **Contacts.** Read on the device when the user imports. The app copies name and birthday into Hive. The importer does not upload them.
- **Google Calendar.** Not on the current user path (M1). The unused client would send the event title, notes, and date to `calendar.events.insert` on the user's Google account, with scopes that can read and write calendar data. Sign-in uses `google_sign_in`. Tokens stay with that plugin. A web OAuth client id is hardcoded in `web/index.html` (public client id, not copied here).
- **Android backup.** Default backup can copy app data to the user's Google account (M7).
- **Notifications.** Shown locally. No push provider.

Play Data safety, once `{calendar_sync}` is decided: if sync is no, declare contacts as collected on-device for app functionality (or "not collected" if you only read and store locally — match Google's current form wording, do not guess the toggle). If sync is yes, declare that names, notes, and dates are sent to Google. Either way the privacy-policy URL is B3.

## Checked and not a release defect

- Debug banner is off.
- Cleartext is not enabled.
- `POST_NOTIFICATIONS` is requested at runtime, not only declared.
- Contacts permission is requested at import time, not at launch.
- Android launcher PNGs exist at the usual densities, and the adaptive icon's foreground PNGs exist. The Android icon is custom. The iOS icon is the Flutter logo (H9).
- No upload keystore, `.env`, or OAuth client secret is committed.
- `hive` and `hive_flutter` are already at the latest pub.dev versions.
- Widget `exported="true"` is required, not a mistake.
- `versionCode` 3 is a valid first upload (L5).

## Commands

Flutter is not installed on this machine. It is not on the user PATH or the machine PATH. A search of the user profile (depth 6) and the usual install locations found no `flutter.bat`. After the user and machine PATH were loaded into the shell, `Get-Command flutter` was still empty.

Each command below failed with `CommandNotFoundException` (`The term 'flutter' is not recognized...`). They were not retried after that.

| Command | Result |
| --- | --- |
| `flutter --version` | Failed. Not recognized. Tried once in the default shell, then again after reloading PATH. |
| `flutter analyze` | Failed. Not recognized. One attempt after PATH reload. |
| `flutter test` | Failed. Not recognized. One attempt after PATH reload. The only test was not executed. Static reading says it fails; that failure was not reproduced by running it. |
| `flutter pub outdated` | Failed. Not recognized. One attempt. Versions in M4 are from the pub.dev API, not from this command. |
| `flutter pub get` | Failed. Not recognized. One attempt, as a fetch-only recovery. It did not run, so `pubspec.lock` was not modified. |

No analyzer issues and no test failures were reproduced, because the SDK is missing. Do not treat "analyze was clean" as a result of this audit.

## Questions that block Phase 2

These were left as placeholders. They are still empty on purpose.

1. App name: `{app_name}`
2. Package / bundle ID: `{package_id}`
3. Privacy policy URL: `{privacy_policy_url}`
4. `include_ios`: yes or no
5. `calendar_sync` in v1: yes or no
6. `coverage_target` percent for `lib/utils` and `lib/services`

Until those are answered, do not rename the application id, do not add or remove packages, do not delete the calendar code or the iOS tree, and do not change Hive fields. Later phases should be separate PRs. Suggested order once the answers exist: signing and application id, privacy policy link, permission-manifest trim (H5), notification correctness (H4), date math with tests (H1–H3), then contacts (H7) and whichever of iOS or calendar the answers keep.
