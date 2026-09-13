# JotCue

JotCue is a cross-platform Flutter productivity application that keeps the
existing note-taking experience while turning note tasks into structured
planning signals.

## Current capabilities

- Email/password authentication
- Notes with images, tags, colors, pinning, and search
- Tasks embedded inside notes with stable hidden identities
- Offline-first projects and task planning metadata
- Plan workspace for projects, deadlines, priorities, effort, and flexibility
- Pulse workspace for deterministic daily focus and attention cues
- Ask JotCue: an on-device, read-only conversational view of current planning state
- Read-only Android calendar availability and deterministic scheduling proposals
- User-defined planning windows, breaks, daily focus limits, and protected lunch
- User-approved JotCue schedule blocks stored locally on the device
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
       |      +-- cached notes and projects
       |      +-- device-local accepted schedule blocks
       |      +-- pending note/project mutation queues
       |
       +-- Firebase Auth
       +-- Cloud Firestore
       +-- Firebase Storage
       +-- Local Notifications
```

Notes and Projects read from the local database. Remote Firestore snapshots
update local state when available. Offline creates, edits, and deletes are
queued and replayed when connectivity returns. Note-backed task text remains
in the note while planning metadata is stored against stable task identities.
Scheduling preferences sync through the existing user settings document, while
external calendar events stay local/in-memory and accepted JotCue schedule
blocks currently remain device-local. Ask JotCue currently derives answers on device
from this structured state; conversations are ephemeral and no LLM/network call is made.

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
do not, so JotCue uses its own Sembast cache and mutation queue across
every platform. On reconnection, queued note changes are pushed to Firestore
and remote changes are merged back into the local database.

Image uploads and reminder cleanup still require connectivity. Those workflows
are separate hardening milestones.
