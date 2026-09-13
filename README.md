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
- Ask JotCue: a local-first conversational planning view with optional Hybrid AI fallback and preview-first Task completion, Task priority, and local schedule-move actions
- Read-only Android/iOS calendar availability and deterministic scheduling proposals
- Derived on-device Personal Graph across Notes, Tasks, Projects, deadlines, and accepted schedule blocks
- User-defined planning windows, breaks, daily focus limits, and protected lunch
- User-approved JotCue schedule blocks stored locally on the device
- Trusted foreground-only local schedule moves in Plan, gated by assistant permissions and recorded in a device-local audit trail
- Smart reminder phrase parsing
- Local notifications, managed Android/iOS calendar links, and review-first text sharing
- Profile and application settings
- Offline-first note reads and writes
- Automatic synchronization when connectivity returns

## Architecture

```text
Flutter + Riverpod
       |
       +-- Sembast local database (all platforms)
       |      +-- cached notes and projects
       |      +-- offline-cached, account-synced accepted schedule blocks
       |      +-- device-local trusted automation audit entries
       |      +-- pending note/project mutation queues
       |
       +-- Firebase Auth
       +-- Cloud Firestore
       +-- Firebase Storage
       +-- Local Notifications
       +-- Optional HTTPS AI gateway (Hybrid Ask JotCue only)
```

Notes and Projects read from the local database. Remote Firestore snapshots
update local state when available. Offline creates, edits, and deletes are
queued and replayed when connectivity returns. Note-backed task text remains
in the note while planning metadata is stored against stable task identities.
Scheduling preferences sync through the existing user settings document, while
external calendar events stay local/in-memory while accepted JotCue schedule
blocks synchronize through the signed-in account with revision-checked offline-first conflict handling. Trusted automation activity also remains device-local. The Personal Graph is derived in memory from this structured state and is not persisted as a separate dataset. Ask JotCue runs deterministic local reasoning first. If Hybrid assistance is explicitly enabled on the device and the build has an HTTPS JotCue AI gateway configured, only unsupported local queries may send the typed request plus a minimized structured planning snapshot to that gateway. Remote answers are ephemeral. Any remote tool suggestion is converted back into the same local typed action preview and must pass the existing permission and executor checks before an explicit Apply tap can mutate anything.

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

### Trusted automation safety (Patch 17)
Trusted local schedule moves now have device-local pause controls, task/project exclusions, a 30-minute per-block cooldown, visible "Moved by JotCue" provenance, guarded undo, and safe cleanup of older audit activity. Undo only restores a block when the current block still matches the trusted move, the original slot is still in the future and conflict-free, and no external calendar link exists. These controls do not broaden Trusted permissions or add background automation.

### Proactive Attention Engine (Patch 18)
JotCue can schedule device-local Morning Pulse and Daily Closing cues, resurface imminent/overdue tasks, and notify when deterministic replanning detects material schedule issues. Attention delivery respects device-local quiet hours, deduplicates stable planning issues, routes notification taps to Pulse or Plan, and remains separate from reminder alarms.

### Personal Graph Foundation (Patch 19)
JotCue now derives an on-device Personal Graph from existing Notes, stable Tasks, Projects, task/project deadlines, and accepted schedule blocks. The graph is a read model only: those existing objects remain the sources of truth, and no separate graph dataset is uploaded or synchronized. Task planning can surface graph-derived related context, while dangling references are exposed as integrity issues rather than silently fabricated.

### Dependencies and action cues (Patch 20)
Tasks can explicitly depend on other stable JotCue Tasks or carry a human-authored "Waiting for" blocker. JotCue derives blocked/ready state, Project next actions, Personal Graph dependency edges, and scheduling eligibility from that metadata. Dependencies are never inferred from note prose, cycles/self-dependencies are rejected before save, and blocked Tasks are excluded from Pulse focus, new schedule proposals, and Trusted schedule moves until their blockers clear.


### Ask JotCue Actions (Patch 21)
Ask JotCue can deterministically interpret three explicit user commands: mark a stable Task complete/incomplete, change a Task priority, or move one future accepted JotCue schedule block to a specific future time. The assistant always shows a structured preview first. Observe exposes no executable action, Suggest remains preview-only, and Approval/Trusted require the user to tap Apply. Completion still rewrites only the source Note's task completion marker, priority remains hidden Task metadata, and schedule moves are revalidated against the current local block state. Calendar-linked blocks are refused in chat and must be handled from Plan so external calendar changes stay separately approved.


### Hybrid AI / tool-calling foundation (Patch 22)
Ask JotCue can optionally use a build-configured HTTPS gateway after deterministic local reasoning declines a query. Hybrid mode is off by default per device. The gateway receives a bounded structured planning snapshot rather than raw Notes or calendar events, and it can only return prose or one of the allow-listed Task completion, Task priority, or local schedule-move tool suggestions. Tool output never executes directly: JotCue resolves current local IDs, rebuilds a local action preview, applies the existing automation policy, and keeps the explicit Apply step. No provider secret is stored in the Flutter client and no chat history is persisted.


### Cross-device schedule sync (Patch 23)
Accepted JotCue schedule blocks now synchronize across signed-in devices while retaining a local Sembast cache for offline use. Every cloud-backed block has a monotonic revision. Offline changes queue with the revision they were based on and are applied transactionally only if the server is still at that revision. If another device changed or deleted the same block first, JotCue keeps the newer synced state and records a local Schedule sync review item instead of silently overwriting it. If independently-created synced blocks overlap, JotCue also surfaces that overlap for explicit review rather than treating the double-booking as healthy. Existing revision-0 device-local blocks are queued for first upload on the next successful sync. Device calendar events remain external/local and are never silently updated by cross-device block sync.

### iOS native parity (Patch 24)
JotCue now uses the same bounded calendar-read, managed reminder-calendar, managed schedule-calendar, Share-to-JotCue, and notification-action contracts on iOS as on Android. EventKit access stays device-local; external calendar contents are used only as busy-time inputs and are never uploaded by this path. Calendar writes remain explicit and ownership-scoped. The iOS Share Extension queues only user-selected text/links through an App Group for the existing review-first Quick Capture flow; receiving a share never creates application data by itself.
