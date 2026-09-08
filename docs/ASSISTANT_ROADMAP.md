# JotCue: on-device-first assistant plan

Approved direction, 8 September 2026. The current release prioritizes reminder
reliability, clear Clock/calendar choices, readable themes and visible note tags.
The capabilities below are planned additions, not shipped features.

## 1. Accountability without a model

Use the existing `TaskParser`, `SmartReminderParser`, Riverpod providers and
Sembast offline store. Evaluate local notes after initial load and when resuming
the app; debounce updates and do not scan on every keystroke. No network request
is required to generate a cue. Existing note synchronization remains unchanged.

Start with explicit unfinished task bullets at least seven days old that have
no active scheduled reminder. Show at most three suggestions in a small
"Worth revisiting" section, with a link to the exact source note/task:

> You wrote "Send the portfolio" a week ago. Still something you want to do?

Actions: **Done**, **Schedule**, **Later** (choose a delay), **Ignore**. Scheduling
opens the existing editor for confirmation. Ignore suppresses that candidate;
it does not delete the note. Later persists its next eligible date. Start with
one resurfacing per candidate per week and a global daily cap; allow disabling
these suggestions. Do not turn app-opening cues into push notifications by default.

For ordinary prose, first ask "Is this something you want to do?" Only clear
action language should become a candidate. Reference material, journals, quotes,
completed work and ignored suggestions must not be repeatedly treated as tasks.
Never infer that an old task is important simply because it is old.

Store cue decisions per user locally: candidate ID, first-seen date,
last-presented date, snoozed-until and ignored state. Current tasks/reminders use
line indexes: introduce stable task identity before persisting long-lived cue
decisions. Preserve identity across edits and moves; avoid transferring an Ignore
decision to a different task that happens to occupy the same line. Do not use
the note's last-edited timestamp as the task's age. Existing tasks can receive a
conservative first-seen timestamp when the feature is enabled.

Acceptance: offline operation; no repeat after Ignore or completion; persisted
Later behavior across restart; no leaking decisions between accounts; unchanged
typing responsiveness; clock/timezone changes handled; editing unrelated note
text does not reset task age. Test pure candidate selection and cooldown rules
with a fixed clock, then test the actions against actual note/reminder state.

## 2. Useful local search

Existing search matches title/content substrings and supports tag/color filters.
Extend it with token normalization, prefix matches, result snippets and task
status/date filters. Start with explicit chips (unfinished, tag, date range),
then map a small supported query grammar such as "unfinished work notes" to
those visible filters. Unsupported language remains a normal text search.

Search local cached notes and tasks; debounce and move heavier indexing off the
UI thread. Keep pinned ordering secondary to relevance in search results. Include
the source note on every task result. Rebuild/update the index incrementally on
edits and deletion, scoped to the signed-in account. Test accent/case handling,
empty searches, large local collections, offline results and account switching.

## 3. Voice capture

Add a microphone action that records only while explicitly active, shows a
recording indicator and produces an editable draft. Ask for microphone permission
in context and recover cleanly from denial/interruption. The user confirms any
task conversion, reminder time or alarm handoff after reviewing transcription.

First assess platform speech recognition capabilities on the supported Android
and iOS versions. Prefer offline recognition where available; display its status.
Do not assume OS speech recognition is offline or silently fall back to an online
service. Offer online transcription separately with explicit consent if needed.
Discard raw audio after transcription by default. Test noisy speech, corrections,
multiple languages, cancellation, denied permission and unavailable offline models.

## 4. Semantic assistance, only after measurement

Build an anonymized, consented evaluation set covering task recognition, vague
intent, dates, search relevance and false positives. Compare deterministic rules
and keyword search against local embeddings, then a small local model only where
it adds measurable value. Measure warm/cold latency, memory, battery, model size
and quality on mid-range hardware including Samsung A54. No model choice is final
until measured. Model downloads require an explicit action and clear storage cost.

Keep note content on-device for this path. If cloud assistance is added, make it
opt-in, show what will be sent and provide a functional local fallback. Suggested
actions always link to their source; uncertain output asks for confirmation.
Do not autonomously send messages, create calendar entries, set alarms or change
task priorities. Avoid a general chat interface until concrete workflows benefit.

## Follow-up: a true JotCue alarm

Clock handoff is not an app-owned alarm engine. A later Android alarm feature
needs persisted schedules, native ringing/dismiss/snooze behavior, OS permission
and distribution-policy review, reboot recovery and physical-device tests. Design
explicit opt-in "Ring as an alarm" and optional escalation independently from
normal reminders. Do not promise arbitrary future dates/custom recurrence via
the Clock time-of-day intent, or that force-stop/DND can be bypassed.

## Efficient implementation sequence

1. A `gpt-5.6-sol` worker at medium effort: stable task identity and accountability
   selection/persistence; bounded tests and no unrelated refactors.
2. Reuse that worker for search; a `gpt-5.6-luna` worker at medium effort can own
   isolated UI polish after data contracts settle.
3. A `gpt-5.6-sol` worker at medium effort evaluates voice support; use high effort
   only for a specific native lifecycle issue.
4. Primary agent reviews integration, runs the agreed checks once, and reports
   measured limitations. Semantic-model experiments and app-owned alarms are
   separate milestones, rather than dependencies of the lightweight assistant.
