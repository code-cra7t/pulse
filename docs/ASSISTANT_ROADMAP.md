# JotCue Assistant Expansion Roadmap

Updated 14 September 2026.

JotCue's assistant foundation is now implemented through Patch 25. The earlier
assistant plan in this file predated stable Task identity, the Attention Engine,
the Personal Graph, dependencies, Ask JotCue actions, Hybrid AI/tool calling,
cross-device schedule sync, iOS parity, and release hardening. Those capabilities
are no longer future work.

Patch 25 is the foundation baseline for the next phase. The uploaded release
snapshot corresponds to commit:

`49db236702ed314a9287da3a43123b5d1f2a3b2a`

Release verification remains governed by `docs/RELEASE_READINESS.md` and should
run on an RC branch without blocking Assistant Expansion development.

## Current assistant foundation

The following are already part of JotCue and should be extended rather than
reimplemented:

- stable Task identity and hidden planning metadata
- deterministic task/project planning and local scheduling
- permission ladder: Observe, Suggest, Act with approval, Trusted
- trusted local schedule-move safety, audit, cooldowns, exclusions, and Undo
- proactive Attention Engine with Morning Pulse and Daily Closing
- derived on-device Personal Graph
- explicit Task dependencies, Waiting for blockers, ready/blocked state, and
  deterministic Project next actions
- Ask JotCue deterministic reasoning and preview-first actions for Task
  completion/reopening, Task priority changes, and future local schedule moves
- optional Hybrid AI fallback with minimized structured context and allow-listed
  remote tool suggestions that must return through the local preview/policy path
- cross-device schedule synchronization and conflict handling
- Android/iOS calendar, reminder, share, and notification parity
- Patch 25 compatibility guards and forward-compatible Task metadata handling

## Phase A: release candidate validation

Create and preserve an RC branch from the exact Patch 25 baseline. Do not build
new assistant features on the RC branch.

Run the existing release gate in `docs/RELEASE_READINESS.md`, including:

1. Flutter analyzer and full Flutter test suite.
2. Firestore emulator suites.
3. Android candidate build and iOS simulator build.
4. Old/new client compatibility matrix.
5. Physical Android and iOS smoke tests.
6. Two-device schedule sync/conflict verification.
7. Explicitly approved Firebase rules rollout from the release commit.
8. Internal beta/TestFlight/Play testing.

Release fixes should be merged/cherry-picked forward into the active Assistant
Expansion branch.

## Phase B: Assistant Expansion

### Patch 26 — Assistant Capture Actions

Connect Ask JotCue to the existing capture pipeline instead of creating a second
capture architecture. Reuse `NaturalLanguageCaptureParser`, `CaptureDraft`, and
`CaptureService` where applicable.

Initial supported assistant actions:

- create a Task
- create a Task list when the existing capture model supports it
- create a Project
- save a Note
- carry explicit deadline/project metadata already supported by capture

All assistant-created data is preview-first. Hybrid AI may propose an allow-listed
capture action, but remote output never mutates local state directly. The local
client resolves and validates the proposal, applies the existing permission
policy, and requires an explicit Apply tap. Trusted mode must not bypass approval
for structured capture in this patch.

Acceptance examples:

- "Add buy groceries to my tasks."
- "Create a project called STG App due October 30."
- "Remember that Sarah said the meeting moved to Friday."

No mutation occurs until Apply. Revalidation must reject stale or malformed
proposals, and local-only operation must remain functional when Hybrid AI is off.

### Patch 27 — Planning Actions

Expand Ask JotCue from creation into organization of existing work.

Add preview-first actions for:

- set/change/clear Task deadline
- assign/remove Task Project
- set/change effort estimate
- add/remove prerequisite
- set/clear Waiting for
- reuse the existing Task priority action rather than duplicating it

Every action must resolve stable local IDs, show the exact proposed change,
revalidate current state at Apply time, and preserve the existing policy/audit
boundaries.

### Patch 28 — Personal Graph 2.0

Populate the graph node types that are currently reserved but not fully built:

- Person
- Decision
- Event

Add explicit, reviewable relationships such as:

- Task/Project involves Person
- Decision belongs to Project
- Event relates to Project
- Event involves Person
- Note records or references Decision/Event

Do not silently persist speculative LLM extraction. New graph facts should come
from explicit structured data or a review/confirmation flow. Existing Notes,
Tasks, Projects, schedules, and other source objects remain the source of truth;
the graph remains derived unless a later design explicitly changes that contract.

### Patch 29 — Contextual Reasoning 2.0

Add a deterministic/contextual reasoning layer that combines the Personal Graph
with current planning state instead of answering from isolated collections.

Inputs should include, where relevant:

- Tasks and Projects
- dependencies and Waiting for blockers
- task/project deadlines
- priorities and effort estimates
- accepted/proposed schedule blocks
- free capacity and schedule problems
- current Attention Engine state
- graph relationships
- current local time

Reasoning output should be structured enough to explain:

- best next action
- why it matters
- blocker/downstream impact
- suitable execution window
- reasonable alternative
- confidence/limitations

The engine must prefer deterministic facts over model inference and remain useful
without Hybrid AI.

### Patch 30 — Proactive Pulse 2.0

Feed contextual reasoning into Morning Pulse, Daily Closing, and in-app attention
surfaces.

Move from count-based summaries toward concise interventions such as:

- what matters most now
- why it matters
- what is blocked and can be ignored for now
- the best available time window
- what slipped and how it can be recovered

Actions from proactive surfaces should route through the same typed action and
permission system used by Ask JotCue.

### Patch 31 — Multi-step Agency

Allow one user request to produce a bounded, reviewable plan containing multiple
typed actions.

Required flow:

1. interpret request
2. produce bounded action plan
3. resolve and validate every target
4. show the complete plan
5. require approval according to policy
6. execute sequentially
7. stop safely on failure/conflict
8. record auditable results

Do not introduce open-ended autonomous tool use. Every action type retains an
explicit safety classification, and external side effects remain separately
controlled.

### Patch 32 — Voice

Add explicit push-to-talk voice input after the action vocabulary is mature.

Initial flow:

1. user taps microphone
2. visible recording state
3. speech recognition produces an editable transcript
4. transcript enters the same Ask/Capture parser
5. JotCue shows the normal preview
6. user applies the action

Prefer platform/offline recognition where available and clearly disclose when an
online recognizer would be required. Do not add always-listening behavior.

### Patch 33 — Assistant Evaluation and Hardening

Create a repeatable assistant evaluation suite using realistic requests and
failure cases before broadening autonomy further.

Cover at least:

- ambiguous and similarly named Tasks/Projects
- stale/deleted targets
- deadlines, dependencies, blockers, and impossible schedules
- account switching and offline mode
- timezone/clock changes
- Hybrid AI unavailable/malformed/malicious tool proposals
- calendar-linked schedule blocks
- multi-action requests and partial failures

Track at least:

- intent/action accuracy
- target-resolution accuracy
- wrong-action rate
- false-positive mutation rate
- best-next-action quality
- local and Hybrid latency/fallback behavior

The release target for silent incorrect mutation is zero.

## Later expansion

After Patch 33 is measured and stable, consider broadening the graph and action
surface to Documents, Conversations, Opportunities, external messaging/email,
and selected trusted automations. These are not prerequisites for the current
Assistant Expansion sequence.

A true app-owned alarm engine also remains a separate milestone: Clock handoff is
not equivalent to an owned alarm implementation and would require native
ringing/dismiss/snooze behavior, persisted schedules, reboot recovery, permission
and distribution-policy review, and physical-device testing.

## Working rule

Do not add a new parallel assistant subsystem when an existing JotCue service,
model, parser, policy, or executor can be extended. Keep assistant mutations
typed, previewable, locally revalidated, and auditable. Hybrid AI may help
interpret intent; it does not become the source of truth or bypass local safety.
