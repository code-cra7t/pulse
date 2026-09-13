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
- Ask JotCue (deterministic on-device planning assistant with narrowly typed, preview-first actions)
- Personal Graph (derived local relationships across notes, tasks, projects, deadlines, and accepted schedule blocks)
- External text sharing into the review-first Quick Capture flow (Android)
- Suggested scheduling (explicit availability + local calendar busy time + user-approved device-local blocks)
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
- Ask JotCue is local-first and ephemeral. Deterministic parsing/answers always run before optional Hybrid AI. Hybrid is device-local opt-in, may contact only the build-configured JotCue AI gateway, and must never persist chat history. Remote output may propose only the existing allow-listed Task completion, Task priority, or local accepted-block move actions; typing a request never executes it.
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
- Accepted JotCue schedule blocks are device-local until cross-device scheduling conflict semantics are designed.
- Adaptive replanning is advisory by default. Never silently mark a block completed/missed. Trusted execution may move only one future flexible device-local proposal block at a time while Plan is open, only after the stored automation policy returns trustedEligible, only when the block is not linked to an external calendar, and only from a fresh deterministic suggestion. Recompute before any next move.
- Non-flexible tasks may be flagged when their accepted block conflicts, but JotCue must not offer an automatic move suggestion for them.
- Scheduling preferences may sync through the existing user settings document, but calendar event contents must remain local/in-memory.


External-context rules:
- Android text shares are review inputs only. Receiving shared content must not create or persist a note, task, project, reminder, or calendar entry without explicit user confirmation.
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
- Parsing and execution are separate. The deterministic parser may prepare only Task completion/incompletion, Task priority, and moving one accepted JotCue block to a specific future time.
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
- Remote tool output is untrusted input. Accept only allow-listed tool names/argument shapes, resolve IDs against current local state, rebuild a local `AskJotCueActionProposal`, then pass through the existing automation policy and executor revalidation.
- Hybrid mode never bypasses explicit Apply in Ask JotCue, even at Trusted permission level.
- Unknown/malformed tools, oversized responses, unavailable gateways, stale IDs, and invalid endpoints fail closed to a local answer with no mutation.
- Remote answers/tool suggestions are ephemeral; do not persist chats, prompts, gateway responses, or model traces in this patch.
