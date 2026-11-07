# Release checklist

First Play upload: versionName **2.0.0**, versionCode **3** (`2.0.0+3`). Do not bump that version for the first upload.

Policy check date: **2026-11-07**. Source: [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

## Signing

- [ ] Upload key created with the `keytool` command in the README. The keystore stays outside the repo.
- [ ] GitHub Actions secrets set: `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`.
- [ ] Tag `v2.0.0` only after those secrets exist. Until they do, the tagged workflow fails and there is no signed app bundle.
- [ ] Confirm the artifact is signed with the upload key. Do not ship a debug-signed bundle. Do not commit the AAB.

## Play Console

- [ ] App name Happaroo. Store title `Happaroo: Birthday Reminder`. Package `com.greinederlabs.happaroo`.
- [ ] Privacy policy URL `https://happaroo.com/privacy`.
- [ ] Short description, full description, screenshots, and 1024 × 500 feature graphic from `store/listing.md`.
- [ ] Data safety answers match `store/data-safety.md`. Data stays on the device. Do not claim encryption the app does not implement. Calendar sync is off.
- [ ] Target API matches the current Play requirement for new apps and updates (the app uses Flutter's target SDK, which this project tracks at API 36).

## Closed testing (personal accounts)

Google's help page, read on 2026-11-07, says personal developer accounts **created after November 13, 2023** must run a closed test before production is available. Production and pre-registration stay disabled until the requirement is met.

The documented bar:

- A closed test with at least **12 testers**.
- Those testers must be **opted in continuously for at least 14 days**.
- When you apply for production access, at least 12 testers must still be opted in, and they must have been opted in for the preceding 14 days.
- A tester who opts out before 14 days does not count. If they opt out and opt back in, the 14 days have to be consecutive.

Then apply for production access from the Play Console Dashboard and answer the questions about the test, the app, and production readiness. Open testing is available only after production access.

Internal testing is optional and does not replace the closed test.

This page does not add a tester count or a day count for organization accounts, or for personal accounts created on or before November 13, 2023. If this account is one of those, follow the Play Console for that account instead of assuming the 12-tester rule applies.

## Before asking for production

- [ ] Closed test installed the signed 2.0.0 (versionCode 3) bundle, not a debug build.
- [ ] At least 12 testers stayed opted in for 14 consecutive days, if this is a personal account created after November 13, 2023.
- [ ] The Dashboard shows the testing requirement as met before you apply.
- [ ] Reminders, import preview, and a yearless date were tried on a real device during the test.
