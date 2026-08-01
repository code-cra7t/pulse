# PulseNotes

PulseNotes is a cross-platform Flutter note-taking application that turns
notes and task phrases into reminders.

## Current capabilities

- Email/password authentication
- Notes with images, tags, colors, pinning, and search
- Tasks embedded inside notes
- Smart reminder phrase parsing
- Local notifications and calendar export
- Profile and application settings
- Offline-first note reads and writes
- Automatic synchronization when connectivity returns

## Architecture

```text
Flutter + Riverpod
       |
       +-- Sembast local database (all platforms)
       |      +-- cached notes
       |      +-- pending mutation queue
       |
       +-- Firebase Auth
       +-- Cloud Firestore
       +-- Firebase Storage
       +-- Local Notifications
```

The UI reads notes from the local database. Remote Firestore snapshots update
the local database when available. Offline creates, edits, and deletes are
queued and replayed when connectivity returns.

## Local setup

```bash
flutter pub get
flutter run
```

Firebase client configuration is generated with FlutterFire. Do not commit
server credentials, signing keys, `.env` files, or Terraform variable files.

## Validation

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
```

## Firebase security

Security rules are version-controlled in:

- `firestore.rules`
- `storage.rules`
- `firestore.indexes.json`

Run the Firebase Emulator Suite before deploying rule changes.

## Offline behavior

Android and Apple Firestore SDKs support native persistence. Windows and Linux
do not, so PulseNotes uses its own Sembast cache and mutation queue across
every platform. On reconnection, queued note changes are pushed to Firestore
and remote changes are merged back into the local database.

Image uploads and reminder cleanup still require connectivity. Those workflows
are separate hardening milestones.
