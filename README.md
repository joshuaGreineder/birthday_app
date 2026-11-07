# Happaroo

Happaroo is a birthday and anniversary reminder. Names, dates, notes, and groups stay on the device. There is no account, no backend, and no ads.

A date can be a month and day with no year. Happaroo stores that month and day and hides the age and the anniversary count. It does not invent a year. Reminders, a home list, a timeline, and a calendar are included. You can filter by the groups you define, make custom event types, and import or export JSON and CSV. Calendar sync stays off in this version. iOS is out of v1.

## Build

This repo was checked with Flutter 3.47.9.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter analyze` and `flutter test` also run on every pull request (`.github/workflows/ci.yml`).

A signed Android App Bundle is produced only by that workflow, when a `v*` tag is pushed and the signing secrets below are set. Release builds do not fall back to the debug keystore. Do not commit an AAB, a keystore, or `android/key.properties`.

## Create the upload key

Run this on your own machine. Do not commit the file it creates.

```bat
keytool -genkeypair -v -keystore %USERPROFILE%\happaroo-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep `happaroo-upload.jks` outside the repo. For a local release build, create `android/key.properties` (gitignored) with `storePassword`, `keyPassword`, `keyAlias`, and `storeFile` pointing at that keystore. `android/app/build.gradle.kts` fails the release build when that file or the keystore is missing.

## GitHub secrets

In the repository: Settings, Secrets and variables, Actions. Add these repository secrets. The tagged workflow fails if any one is missing. It never reads a keystore from the repo.

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | Base64 of the upload keystore |
| `STORE_PASSWORD` | Keystore store password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | Key alias (`upload` if you used the command above) |

PowerShell, to produce the base64 value without printing it into the repo:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\happaroo-upload.jks"))
```

Paste that into `KEYSTORE_BASE64` only. Do not commit it.

## Tag a release

`pubspec.yaml` is `2.0.0+3`. The first Play upload uses versionName **2.0.0** and versionCode **3**. Do not change that version for the first upload.

The signed bundle job is blocked until `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, and `KEY_ALIAS` exist on the repository. After they do:

```sh
git tag v2.0.0
git push origin v2.0.0
```

The workflow builds `flutter build appbundle --release`, signs it with the upload key from those secrets, and uploads the AAB as a workflow artifact. It does not commit the AAB.

Store copy and the Play closed-testing checklist are in `store/`.
