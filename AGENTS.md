# JotCue AI Context

You are a senior Flutter engineer working on JotCue.

Stack:
- Flutter (multi-platform)
- Firebase Auth / Firestore / Storage
- Riverpod
- Sembast offline-first local persistence

Current product surfaces:
- Notes (existing visual layout is protected)
- Embedded note tasks with stable identities
- Reminders (manual + smart)
- Plan (projects + task planning metadata)
- Pulse (deterministic daily focus and attention cues)
- Ask JotCue (deterministic on-device planning assistant with narrowly typed, preview-first actions, including Task planning metadata and review-first Task/Project/Note capture)
- Personal Graph (derived local relationships across notes, tasks, projects, deadlines, and accepted schedule blocks)
- External text sharing into the review-first Quick Capture flow (Android and iOS)
- Suggested scheduling (explicit availability + local calendar busy time + user-approved accepted JotCue blocks with an offline local cache)
- Adaptive replanning (reviewable drift/conflict/deadline-capacity suggestions)
- Settings / profile

Rules:
- Keep code simple and scoped.
- Do not block the UI.
- Match the existing architecture and visual language.
- The current Notes cards, editor layout, color tags, and reminder access must not be redesigned unless a task explicitly requires it.
- Visible note content remains the source of truth for note-backed task text and completion.
- Planning metadata must not rewrite visible note text.
- Prefer deterministic planning logic before introducing AI-generated decisions.
- Ask JotCue is local-first and ephemeral. Deterministic parsing/answers always run before optional Hybrid AI. Hybrid is device-local opt-in, may contact only the build-configured JotCue AI gateway, and must never persist chat history. Remote output may propose only the current allow-listed typed actions; Patch 27 extends the review-first Task planning surface to deadlines, Project assignment, effort estimates, prerequisites, and Waiting for alongside completion, priority, accepted-block moves, and Patch 26 capture actions. Typing a request never executes it.
- Do not introduce a fixed bot-face avatar for Ask JotCue; use JotCue brand language until a later personalized assistant-identity system is explicitly designed.
- Preserve offline-first behavior.
- Do not deploy Firebase rules unless explicitly instructed.

Always:
- Explain the intended change before coding.
- Only modify necessary files.
- Run formatter, analyzer, Flutter tests, relevant Firebase rule tests, and a debug Android build before declaring a patch verified.

Calendar / availability rules:
- External calendar reads are opt-in and local-only by default; do not upload or persist third-party event contents unless a later task explicitly introduces a privacy-reviewed sync design.
- Treat external calendar events as fixed busy-time inputs, not JotCue-owned events.
- Keep calendar reading separate from existing reminder calendar export/linking behavior.
- Availability calculation must stay deterministic and accept explicit planning windows; do not assume a user's waking or working hours.
- Device calendar reads must stay bounded to near-term ranges (currently at most 31 days).
- Scheduling proposals are suggestions only. External calendar writes require explicit user confirmation and calendar-write permission; never write or update schedule entries silently.
- Schedule-block calendar links must remain separate from reminder calendar links and may only own events created for that exact JotCue block.
- Rescheduling a linked block must not silently update the external calendar; offer an explicit update choice.
- Accepted JotCue schedule blocks sync through the signed-in account using revision-checked conflict semantics; the local cache, device calendar links, trusted-automation safety state, and automation audit remain device-local.
- Adaptive replanning is advisory by default. Never silently mark a block completed/missed. Trusted execution may move only one future flexible JotCue proposal block at a time while Plan is open, only after the stored automation policy returns trustedEligible, only when the block is not linked to an external calendar, and only from a fresh deterministic suggestion. Recompute before any next move.
- Non-flexible tasks may be flagged when their accepted block conflicts, but JotCue must not offer an automatic move suggestion for them.
- Scheduling preferences may sync through the existing user settings document, but calendar event contents must remain local/in-memory.


External-context rules:
- Android/iOS text shares are review inputs only. Receiving shared content must not create or persist a note, task, project, reminder, or calendar entry without explicit user confirmation.
- Keep share ingestion local and transient until the user confirms a save/create action. Do not upload shared content merely because another app sent it to JotCue.
- Reuse the existing Quick Capture parser/service rather than creating a second task/project source of truth.
- External API integrations (Gmail, Google Calendar cloud APIs, etc.) require separate privacy/scoping work and must not be smuggled into share-intent patches.

Trusted automation rules:
- Trusted execution is foreground-only in this version; do not add background workers or timers.
- Only AutomationActionKind.localScheduleMove is trusted-eligible. External calendar writes, work review decisions, structured capture creation, and Task planning updates always require approval.
- Trusted moves must fail closed when calendar-link state cannot be verified, when the source block is stale, when the task is missing/non-flexible/completed, or when the block was user-created.
- Execute at most one move per replanning snapshot, then recompute availability/replanning before considering another.
- Every successful trusted move must be appended to the device-local automation audit store. Do not upload the audit trail unless a later privacy-reviewed design explicitly introduces sync.

## Patch 17 trusted-automation safety guardrails
- Keep the account-wide automation level separate from device-local trusted-execution safety controls.
- Trusted execution must fail closed when local safety state, audit history, or calendar-link state cannot be verified.
- Respect device-local pause, task exclusions, project exclusions, and the per-block cooldown before any trusted move.
- Never auto-move a calendar-linked block, past block, non-flexible task, user-created block, or stale schedule snapshot.
- Undo is user-initiated only. It must reject stale/currently changed blocks, linked calendar copies, past original slots, and conflicting original slots.
- Audit cleanup must preserve pending/undo-pending entries and any applied move/undo still inside the cooldown window.
- Do not broaden Trusted to calendar writes, capture creation, completion/missed decisions, or background execution without a separately reviewed patch.

## Patch 18 proactive-attention guardrails
- Keep attention notifications separate from reminder alarms and their IDs/channels.
- Attention decisions remain deterministic/local; do not add LLM or engagement-style notifications.
- Respect the account notification master switch plus device-local attention preferences and quiet hours.
- Notification taps may navigate to Pulse or Plan only; they must not mutate tasks, schedule blocks, reminders, or calendars.
- Throttle unchanged schedule-attention signatures and cap imminent deadline cues.
- Do not introduce a background task executor as part of proactive attention.

## Patch 19 personal-graph guardrails
- The Personal Graph is a derived local read model, never a second source of truth.
- Build graph nodes/edges only from existing Notes, stable Tasks, Projects, deadlines, and accepted schedule blocks.
- Do not persist or sync the graph as a separate dataset in this patch.
- Broken references must fail visibly as integrity issues; never invent missing Notes, Projects, Tasks, or schedule relationships.
- Reserved graph node types such as person, decision, and event are schema placeholders only until a later reviewed extraction/design patch populates them.
- Relationship UI must remain secondary to the existing Notes/Plan experience and must not redesign Notes.

## Patch 20 dependency and action-cue guardrails
- Task dependencies must be explicit stable Task IDs stored in Note task identity metadata; never infer or silently create them from Note prose.
- Reject self-dependencies, missing prerequisites on new saves, and dependency cycles before mutating the source Note.
- `waitingFor` is human-authored external-blocker text. JotCue must never mark it resolved automatically; only the user clears or edits it.
- Completed prerequisites satisfy a dependency. Missing or cyclic prerequisites fail closed as blocked/integrity problems.
- Blocked Tasks must not enter Pulse focus, new deterministic scheduling proposals, or Trusted local schedule moves. Existing accepted schedule blocks remain user-visible and are not silently deleted.
- Personal Graph dependency edges are derived read-only relationships; Notes/Task identity metadata remain authoritative.
- Keep dependency metadata backward-compatible: absent fields deserialize to no dependencies/no waiting blocker. Do not change visible Note text.


## Patch 21 Ask JotCue action guardrails
- Parsing and execution are separate. Patch 21 introduced only Task completion/incompletion, Task priority, and moving one accepted JotCue block to a specific future time; later reviewed patches may extend the typed action surface without weakening preview/approval requirements.
- Every conversational mutation must be previewed before execution. Ask JotCue never mutates merely because the user pressed Send.
- Observe mode must not expose an executable proposal. Suggest mode may show a non-executable preview. Approval and Trusted may expose Apply, but Ask JotCue still requires that explicit tap.
- Completion/incompletion uses the source Note checkbox/task line as the source of truth. Task priority uses hidden Task identity metadata. Schedule moves revalidate the exact block snapshot before mutation.
- Calendar-linked schedule blocks must fail closed in Ask JotCue and route the user to Plan; Patch 21 does not add calendar writes from conversation.
- Ambiguous Task names, multiple future blocks for one Task, stale block state, past target times, occupied target times, or calendar-link verification failures must never be guessed through.
- Ask JotCue actions are user-initiated and do not broaden foreground Trusted automation, background execution, or the device-local trusted audit contract.


## Patch 22 hybrid-AI/tool-calling guardrails
- Hybrid AI is OFF by default on every device. Local deterministic Ask JotCue remains fully functional without a gateway.
- Never embed provider API secrets in the Flutter client. The optional gateway URL is build-configured with `JOTCUE_AI_GATEWAY_URL`; production URLs must use HTTPS.
- Local deterministic reasoning always gets first refusal. Only queries classified as unsupported/unknown may be sent remotely.
- Remote context must be minimized and structured. Do not send Note bodies, source Note IDs/line indexes, account identity, reminder text, external calendar contents, audit history, notification history, or a raw Personal Graph payload.
- Remote tool output is untrusted input. Accept only allow-listed tool names/argument shapes, resolve IDs against current local state, rebuild a local `AskJotCueActionProposal`, then pass through the existing automation policy and executor revalidation. Capture tools must be reparsed/validated locally and remain approval-gated.
- Hybrid mode never bypasses explicit Apply in Ask JotCue, even at Trusted permission level.
- Unknown/malformed tools, oversized responses, unavailable gateways, stale IDs, and invalid endpoints fail closed to a local answer with no mutation.
- Remote answers/tool suggestions are ephemeral; do not persist chats, prompts, gateway responses, or model traces in this patch.


## Patch 23 cross-device schedule-sync guardrails
- Accepted JotCue schedule blocks may sync only inside the signed-in user's `users/{uid}/scheduleBlocks` subcollection. External calendar event contents never sync through this path.
- Preserve offline-first local reads/writes. Queue mutations locally and replay them when connectivity returns.
- Every synced block uses a monotonic integer revision. Updates/deletes must be based on the revision the local edit observed; never use silent last-write-wins for conflicting device edits.
- If the server revision changed first, keep the newer synced state and record a local review item containing the losing local snapshot when available. Never automatically reapply a losing edit.
- Existing revision-0 local blocks are migration candidates for first upload, not disposable legacy data.
- Cross-device block sync must never silently update, delete, or create a device-calendar event. Calendar writes remain an explicit local approval flow.
- Do not deploy Firestore rules unless explicitly instructed.
- Detect newly introduced overlaps among synced canonical blocks and surface them for review; never silently treat a cross-device double-booking as healthy.


## Patch 24 iOS parity guardrails
- iOS calendar reads use EventKit full access only after explicit permission and remain bounded to the same 31-day near-term window. Never upload third-party calendar event contents.
- Managed reminder and schedule calendar links on iOS may update/delete only EventKit events whose stored event identifier and JotCue ownership marker both still match. If ownership cannot be verified, fail closed.
- iOS Share-to-JotCue uses the `group.com.tori.pulse.share` App Group only as a capped transient handoff queue. The extension must never read or write the app database.
- Share Extension activation stays text/URL scoped. Shared input always opens the existing review-first capture flow and never persists merely because it was shared.
- Cross-device schedule sync never grants permission to modify a local iOS calendar copy. Calendar writes remain explicit local actions.
- Keep iOS reminder notification actions on the existing Flutter notification response path; notification actions may snooze/dismiss/navigate but must not broaden automation authority.
- Changes to the Share Extension require an iOS simulator build in addition to the normal analyzer/test/Android verification gate. Device distribution also requires the App Group capability to be provisioned for both Runner and ShareExtension.

## Patch 25 release-hardening and metadata-compatibility guardrails
- Visible Note text/completion remain authoritative; compatibility protection must not rewrite visible Note content merely to preserve hidden metadata.
- Modern Notes protect hidden Task identity writes with `taskMetadataSchemaVersion` plus a fresh `taskMetadataWriteToken`. Any write that changes `taskIdentities` must prove it came from a compatible client.
- Legacy Notes without the guard remain readable/creatable, and harmless legacy title/pin/tag/color edits may continue. Content edits on Task-bearing Notes and any `taskIdentities` change require a fresh modern token. Prefer rejecting a risky legacy write over accepting silent metadata corruption or visible/hidden Task drift.
- Modern clients must retain unknown fields inside each Task identity so future metadata survives read/edit/reconcile/write cycles.
- A queued legacy Note mutation must be reconciled against the latest modern remote identities before it is upgraded to the current schema/token; never stamp a lossy legacy payload as modern without preservation.
- Firestore rule deployment is a separately authorized release action. Verification may run emulator suites only.
- Release readiness requires old-version/new-version compatibility testing plus Android and iOS physical-device smoke checks; simulator/unit tests alone are insufficient for native calendar/share/notification provisioning behavior.

## Patch 26 assistant-capture guardrails
- Reuse `NaturalLanguageCaptureParser` plus `CaptureService`; Ask JotCue must not create a second Task/Project/Note persistence path.
- Local deterministic capture parsing recognizes only explicit assistant capture commands. Ordinary prose must not silently become a creation proposal.
- Every Task, Project, task-list, or Note capture from Ask JotCue is preview-first. Observe exposes no action, Suggest is non-executable, and Approval/Trusted still require the explicit Apply tap.
- `AutomationActionKind.structuredCaptureCreate` remains always-approval-required; Patch 26 does not make any capture action trusted-eligible or background-capable.
- Hybrid capture output is untrusted. `capture.create` supplies text that the local parser must accept before a proposal exists; `note.save` may only preview non-empty bounded text. Neither tool executes remotely.
- The signed-in user ID is supplied locally to the assistant context only for execution ownership and must not be added to minimized remote AI context.
- Successful capture execution goes through the existing offline-first capture service. Do not mutate visible Notes, project/task stores, or Firestore directly from the assistant executor.

## Patch 27 assistant-planning guardrails
- Reuse `TaskMetadataUpdate` plus `TaskService.updateMetadata`; Ask JotCue must not create a second Task-planning persistence path.
- Planning commands are preview-first. Typing or sending a command never changes Task metadata; Observe exposes no action, Suggest remains non-executable, and Approval/Trusted require the explicit Apply tap.
- Patch 27 may update only deadline, Project assignment, estimated minutes, prerequisite Task IDs, and `waitingFor`. It does not broaden Trusted execution; `AutomationActionKind.taskPlanningUpdate` remains always approval-required.
- Resolve Task and Project names conservatively. Ambiguous or missing names must fail closed instead of guessing. Prerequisite IDs must resolve to current Tasks, self-dependencies are forbidden, and the existing Task service remains responsible for missing-dependency/cycle validation at execution time.
- Hybrid planning output is untrusted. Accept only allow-listed planning tools, resolve all IDs against current local state, rebuild a local `AskJotCueActionProposal`, and pass execution through the same automation policy and Task service.
- Keep `waitingFor` text bounded and explicit. Do not infer or persist people/entities beyond the text the user supplied; Personal Graph entity extraction belongs to a later patch.

## Patch 28 Personal Graph 2.0 guardrails
- The Personal Graph remains a derived, in-memory read model. Do not persist or sync graph nodes or edges as a separate source of truth.
- Person, Decision, and Event nodes may be created only from explicit structured facts in existing user-owned source data. Patch 28 must not infer entities from ordinary Note prose.
- Supported explicit Note markers are reviewable/editable at their source, including `Person:` / `People:`, `Decision:`, and `Event:` forms.
- Ordinary prose must never create Person, Decision, or Event graph nodes merely because it appears to mention an entity or occurrence.
- Derived relationship edges may connect explicit facts to their source Note and, where unambiguous, to existing Tasks and Projects.
- Never guess a Project relationship. If a source Note resolves through Tasks to zero or multiple Projects, omit the Project-specific relationship rather than choosing one.
- Person identity normalization must remain deterministic and conservative. Do not silently merge distinct people based on fuzzy similarity.
- Event dates must come from explicit user-authored structured input. Do not manufacture dates from surrounding prose.
- Existing Notes, Tasks, Projects, deadlines, dependencies, and schedule blocks remain authoritative. Removing or editing the source fact must naturally change the next derived graph build.
- Patch 28 does not broaden Hybrid AI, Trusted automation, background execution, or Ask JotCue mutation permissions.

## Patch 29 Contextual Reasoning 2.0 guardrails
- Contextual reasoning is deterministic and read-only. It must never mutate Tasks, Projects, Notes, schedules, calendars, automation state, or Personal Graph source data.
- Reuse existing authoritative read models instead of duplicating planning logic. Task readiness/blocking comes from `TaskDependencyAnalyzer`; scheduling capacity comes from existing availability/scheduling state; recovery issues come from replanning; Personal Graph remains derived.
- Blocked Tasks must never be recommended as the best next action. Missing dependencies and dependency cycles fail closed.
- Completed Tasks and inactive Projects must not be promoted as current work.
- Recommendations may consider Task/Project deadlines, priorities, effort estimates, accepted schedule blocks, scheduling proposals, current free capacity, replanning signals, downstream dependency impact, Personal Graph relationships, and current local time.
- Personal Graph People, Decisions, and Events may enrich explanations only when those relationships already exist in the derived graph. Contextual reasoning must not perform a second entity-extraction pass or infer new graph facts.
- Prefer deterministic facts over inferred importance. Do not invent deadlines, effort, blockers, availability, people, decisions, events, or schedule windows when data is absent.
- Execution-window suggestions must come from accepted future schedule blocks, current deterministic scheduling proposals/free slots, or explicit replanning suggestions. Do not fabricate calendar availability.
- When evidence is incomplete, expose a limitation or lower confidence instead of pretending certainty.
- Alternatives must also be currently actionable; do not recommend blocked work merely to provide a second option.
- Patch 29 adds reasoning only. It does not broaden Ask JotCue action types, Trusted automation eligibility, Hybrid AI authority, background execution, or multi-step agency.
