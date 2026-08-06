# PulseNotes Google Play Release

## Release identity

- App name: `PulseNotes`
- Package name: `com.tori.pulse`
- Version: `1.0.0 (1)`
- Target SDK: Android 16 / API 36 (provided by Flutter 3.41.6)
- Minimum SDK: API 24 (provided by Flutter 3.41.6)

The package name is registered with the current Firebase Android app. Confirm it before the first Play Console upload; it cannot be changed for that listing afterward.

## Create the upload key

Run this once from the project root, replacing the two password placeholders with strong, unique values:

```powershell
keytool -genkeypair -v -storetype JKS -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass YOUR_UPLOAD_KEYSTORE_PASSWORD -keypass YOUR_UPLOAD_KEY_PASSWORD -dname "CN=PulseNotes Upload, OU=Mobile, O=YOUR_DEVELOPER_NAME, L=YOUR_CITY, ST=YOUR_STATE, C=YOUR_COUNTRY_CODE"
Copy-Item android/key.properties.example android/key.properties
```

Then replace the placeholders in `android/key.properties`. Both the keystore and properties file are ignored by Git. Back them up in a password manager or other secure storage. Enroll in Play App Signing and upload the resulting app bundle as an upload-key-signed artifact.

## Build and verify

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to an internal testing track first.

## Deploy policy pages and Firebase rules

After reviewing the privacy text and adding the real support contact, rebuild the web app and deploy the hosted pages and rules:

```powershell
flutter build web --release
firebase deploy --only firestore:rules,storage,hosting
```

Verify both public URLs in a signed-out browser before entering them in Play Console.

## Store listing draft

**App name**

PulseNotes

**Short description**

Turn notes into tasks and reminders, with smart scheduling and offline access.

**Full description**

PulseNotes keeps notes, tasks, and reminders together in one focused workspace.

- Write and organize notes with tags, colors, images, and pinned items.
- Turn lines in a note into trackable tasks.
- Create one-time or repeating reminders from your notes.
- Add reminders to your calendar when you choose.
- Keep working when your connection drops and sync changes when you reconnect.
- Personalize the app theme and default note tag.

Your content is tied to your account so it stays available across supported devices. PulseNotes includes an in-app privacy policy and permanent account-deletion controls.

## Play Console declarations

- App access: provide reviewer credentials if any area requires login.
- Ads: no ads are present.
- Content rating: complete the questionnaire based on a productivity/notes app.
- Target audience: select only the age groups the product is intentionally designed for.
- Privacy policy: `https://pulsenotes-c8d82.web.app/privacy.html`
- Account deletion: `https://pulsenotes-c8d82.web.app/account-deletion.html`
- Exact alarm access: reminders are core, user-created functionality; the app requests `SCHEDULE_EXACT_ALARM`, not the restricted `USE_EXACT_ALARM` permission.
- Notifications: requested in context when reminder functionality is used.

## Data safety working draft

Review this against the final production behavior before submitting:

- Account information: email address and user ID, for account management and app functionality.
- Personal information: optional display name and profile image, for app functionality and personalization.
- User content: notes, tasks, reminders, and user-selected images, for app functionality.
- Data is encrypted in transit.
- Users can request deletion in the app and from the public deletion page.
- Data is processed by Firebase as a service provider and is not sold or used for advertising.

## Assets and final checks

- Use `web/icons/Icon-512.png` as the 512 x 512 store icon after visually checking it in Play Console.
- Create a 1024 x 500 feature graphic and at least two phone screenshots.
- Add the real support email and developer identity to Play Console and the public privacy policy before production submission.
- Build the Flutter web app and deploy Firebase Hosting so the privacy and deletion URLs are live.
- Deploy the updated Firestore and Storage rules before testing account deletion.
- Test sign-up, login, offline edits, notification permission denial/retry, exact-alarm access, reminder delivery after reboot, image upload, and account deletion on a physical Android device.
- Use Play Console pre-launch reports and resolve crashes, ANRs, accessibility warnings, and policy issues before promoting beyond testing.
