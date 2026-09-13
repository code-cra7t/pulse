# JotCue release readiness gate

Patch 25 is the first explicit release-hardening milestone. It does not deploy
Firebase rules or publish a build. It defines the order and checks required
before a public beta/release.

## 1. Compatibility boundary

Visible Note text and completion remain the source of truth. Hidden Task
planning metadata is stored in `taskIdentities` and is protected by two
Note-level fields written by modern clients:

- `taskMetadataSchemaVersion`
- `taskMetadataWriteToken`

Legacy Notes that do not contain these fields remain readable and valid.
Harmless legacy edits to title/pin/tags/color that leave Task-bearing content and `taskIdentities` unchanged remain valid. If a write changes `taskIdentities`, or changes `content` on a Note that already carries stable Task identities, Firestore requires the current schema and a fresh write token. An older build that does not understand the guard therefore
cannot replace modern Task identities with a lossy shape.

A modern client also retains unknown keys inside each Task identity. This makes
Patch 25 forward-compatible with future metadata fields instead of deleting
fields it does not yet understand.

### Queued legacy edits during upgrade

A queued Note mutation produced before Patch 25 is not blindly stamped as
modern. Before upload, the client reads the latest server Note when possible
and reconciles the queued visible Task lines against modern remote identities.
This preserves current project/deadline/priority/effort/dependency metadata
while still applying the user's visible Note edit.

## 2. Firebase rollout order

Do not deploy from a verification/Codex run.

For an actual release:

1. Verify all Firestore emulator suites from the exact release commit.
2. Confirm the release build contains Patch 25 compatibility code.
3. Schedule the client release and Firestore-rule rollout together.
4. Deploy the consolidated `firestore.rules` immediately before/with the
   compatible client rollout.
5. Confirm Patch 23 `users/{uid}/scheduleBlocks/*` access is live.
6. Confirm Note compatibility rules reject lossy legacy Task-identity writes.
7. Monitor sync/permission-denied telemetry during the rollout window.

After the compatibility rules are live, older builds may be unable to edit
Task-bearing Note lines because those writes can change `taskIdentities`
without a fresh token. That is intentional: reject the dangerous write rather
than silently destroy newer planning metadata. Non-content Note edits that leave Task identity state unchanged remain compatible. Content edits on Task-bearing Notes require a Patch 25-compatible client.

## 3. Upgrade/migration matrix

Before public release, manually verify at least these paths:

- legacy Note with no `taskIdentities` -> Patch 25 open/edit/save
- stable-ID Note from Patch 1-era shape -> Patch 25 edit/save
- Patch 20 dependency metadata -> Patch 25 edit visible Note text
- Patch 25 Note -> older build harmless title edit -> Patch 25 still intact
- Patch 25 Note -> older build attempts Task-line edit -> Firestore rejects it
- queued legacy offline edit -> upgrade to Patch 25 -> reconnect -> metadata is
  preserved while visible text applies
- Patch 25 -> future/unknown Task identity field -> known-field edit preserves
  the unknown field

Do not call compatibility verified until the old/new two-client matrix has
been exercised against the local emulator or a dedicated staging project.

## 4. Android smoke matrix

On a physical Android device where possible:

- sign in / cold start / offline start / reconnect
- create, edit, complete, and delete Note Tasks
- project/deadline/priority/effort/dependency metadata survives Note edits
- calendar availability permission deny/grant/revoke
- explicit schedule calendar add/update/remove
- reminder notification, Snooze, Dismiss, tap routing
- Share to JotCue from browser/mail -> review-first Quick Capture
- two-device accepted-block sync and conflict review
- Trusted move -> audit -> Undo -> cooldown
- account deletion and local cleanup

## 5. iOS smoke matrix

On a signed physical device/TestFlight build:

- enable `group.com.tori.pulse.share` for Runner and ShareExtension provisioning
- sign in / cold start / offline start / reconnect
- EventKit Full Access deny/grant/revoke
- explicit reminder/calendar and schedule/calendar add/update/remove
- notification tap + Snooze/Dismiss actions
- Share Extension text and URL handoff, including cold-start queue drain
- two-device accepted-block sync and local calendar-review behavior
- account deletion and App Group/local-state cleanup expectations

The simulator build is necessary but not sufficient for App Group, EventKit,
notification-action, and real calendar behavior.

## 6. Release gate

A release candidate is not ready until:

- Flutter analyzer has no new findings
- full Flutter suite passes
- Android debug/release candidate build succeeds
- iOS simulator build succeeds
- all Firestore rules suites pass locally
- `git diff --check` is clean
- generated Flutter/CocoaPods migration churn is absent from the release diff
- the old/new compatibility matrix passes
- Android and iOS physical-device smoke checks are recorded
- Firebase rule deployment is explicitly approved and performed from the
  release commit, not from an intermediate working tree
