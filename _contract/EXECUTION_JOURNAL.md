# Execution Journal Contract

Execution Journal is the runtime-neutral source of truth for launcher
orchestration state. It belongs to one exact SDLC Project and one run; it is not
a Claude/Codex/Gemini/local conversation and not a global launcher checkpoint.

## Storage

The launcher stores each project journal outside the Project write scope:

```text
$XDG_STATE_HOME/sdlc-agents/execution-journal/projects/{PROJECT}-{path-digest}/
├── README.md
└── runs/
    └── {run-id}/
        ├── plan.md
        ├── state.md
        ├── events.jsonl
        ├── change-scope/             # runtime tables and before/after manifests
        └── lease
```

Project-level `violations/` beside `runs/` stores immutable Change Scope violation records and
the exact path table used for verification. A later launcher preflight records resolution only
after a fresh approved scope or a full-tree comparison proves that out-of-scope changes were
removed. Primary agents cannot read or write this state.

The canonical journal directory is launcher-owned state. `{path-digest}` binds the project name
to its canonical absolute path and prevents collisions. Project-scoped agents cannot write this
directory. A run id is unique inside its bound project journal. Writes to plan/state use
temporary file + atomic rename. `lease` is process-local coordination metadata;
an empty/stale lease is not success evidence. A live lease matches both PID and
process start time, so PID reuse cannot keep a stale run locked.

## Immutable plan

`plan.md` is created before execution and is not rewritten after the run starts.
It records at minimum:

- run id, project name and absolute path;
- action type and exact included/excluded scope;
- ordered step/agent/command list;
- effective runtime, host/provider/model status and route source per step;
- subagent policy/max and, for `cross-runtime`, exact worker profile/task kinds. Every worker
  authorization additionally binds request, read-manifest and route SHA-256 inside the run;
- memory profile SHA-256 and each exact per-step snapshot SHA-256 when memory is used;
- preconditions/TDD/Gate status known at preview time.

No raw prompt, vendor conversation, secret or model credential is stored.

Worker Request/authorization/Result and memory snapshots are launcher-owned run files, not
Project artifacts. A worker result or memory snapshot is consumed only by a new isolated
digest-bound launch; neither vendor session resume nor sibling-agent context sharing is valid.

## State

Run status is one of:

`PLANNED|READY|RUNNING|WAITING_USER|BLOCKED|INTERRUPTED|COMPLETED|CANCELLED`.

Step status is one of:

`PENDING|RUNNING|PROCESS_OK|READ_ONLY_VERIFIED|ARTIFACT_VERIFIED|GATE_PASS|DOD_AUTO_PASS|DOD_PASS|UNVERIFIED|`
`GATE_BLOCKED|DOD_BLOCKED|FAILED|SKIPPED|INTERRUPTED|UNKNOWN`.

`state.md` records current run status, current/last confirmed step, totals,
updated timestamp and a concise reason. Runtime exit `0` records only `PROCESS_OK`.
For `mutating-declared-output`, the launcher checks every task output group and requires its
fingerprint to change during the process before recording `ARTIFACT_VERIFIED`. For
`read-only-no-output`, enforced read-only access plus process success records the separate
`READ_ONLY_VERIFIED`. `orchestrated-special` uses only its named dedicated verifier.
For Stage 4 `scoped-write`, declared outputs are necessary but not sufficient: the launcher
also verifies the whole Project tree against the current approved agent/command path table. A
violation remains `UNVERIFIED/BLOCKED` even when process exit and reports look valid.
File existence alone never proves a gate verdict. An unfinished `RUNNING` step
observed without a live launcher is `INTERRUPTED/UNKNOWN`, not verified work.

## Events

`events.jsonl` is append-only. Every line is one JSON object containing timestamp, event type,
strictly increasing `sequence`, run status, step index/status, agent, command, concise
evidence/reason, `prev_hash` and `event_hash`. The first event uses `prev_hash: GENESIS`;
every later event points to the preceding event hash. `event_hash` is SHA-256 of the exact
canonical JSON payload without its own hash field. The launcher validates the complete plan
digest and event chain before every append, resume and completion proof. Reordering, deletion,
insertion or mutation therefore blocks the run. Events never include raw prompts, stdout or
secrets by default.
`PROCESS_OK`, `READ_ONLY_VERIFIED`, `ARTIFACT_VERIFIED`, software `DOD_AUTO_PASS`, full
`DOD_PASS` and `GATE_PASS` are separate
events. Plain Markdown `status: PASS` remains `UNVERIFIED/BLOCKED` for a machine check.
`dod-check.sh` covers only the automated subset and can emit only `DOD_AUTO_PASS`; `DOD_PASS`
is emitted only after `dod-approval-check.sh` independently validates the current
`APPROVAL-DOD-*.yaml`, all `DOD-1`–`DOD-11` scope items and digest-bound current Tech Lead
reviews for the same source and launcher run.
Evidence Contract v1 binds test/security/build/policy results to producer, exact
source/subject, raw digest, profile/policy revision and freshness. Gate events store concise
evidence ids from the deterministic verifier, never copied raw output.
Change Scope preparation and execution use distinct events for intent creation, isolated L1/S3
verification, human approval request, activation, per-step readiness, full-diff success and
violation. Raw model output is not stored as scope evidence.
Resume accepts step progress only from structurally anchored
`step_artifact_verified`/`step_read_only_verified`/optional-skip events; numbers appearing inside evidence text
and `PROCESS_OK` do not advance the resume point.

For active Cycle 1, Gate 1–4 run before entry to the next Stage, software DoD runs
after the completed Stage 4 implementation-unit review, and Gate 5 runs after
Go/No-Go. Any failed, blocked or unverified mandatory verdict stops dispatch.

## Resume and repair

Continue means resume orchestration after the last confirmed event. It never
means vendor session resume. Before retrying an interrupted/unknown mutation the
user must be offered read-only evidence review. Retry uses the immutable run
snapshot; changed goal/routing configuration requires a revised child run. A step is resumable
only after its anchored result and every registered Gate/DoD/completion hook pass. The child
contains the exact remaining parent entries with byte-equivalent frozen profiles and route
sources, and the parent records one hash-chained `retry_child_created` link.

Verified Cycle 1 completion accepts either one full CYCLE run or a linear CYCLE→RESUME chain.
The terminal run owns `cycle1-completion-proof-v2.yaml` and
`cycle1-execution-chain-v1.tsv`; together they bind every immutable plan digest, sealed Journal
prefix, parent link, 28-step contribution and current artifact row. Unrelated runs and branch
chains are rejected.

A scoped Review runs with enforced read-only access and must return a valid
`REVIEW_FINDING` TSV envelope. The launcher stores only the validated rows as an immutable
`review-findings.tsv` plus digest outside Project write scope. The record binds exact Project,
scope and Project snapshot; raw stdout is not retained as evidence.

Repair requires the latest digest-valid Review for the same exact scope and unchanged Project
snapshot. It creates a separate child run whose immutable plan contains `parent_run_id`, passes
the verified findings and digest to the repair process, requires the Project snapshot to change,
then performs an enforced read-only re-review. Only machine `CLEAN` completes Repair. It does not
rewrite the parent plan, state history or events; tampered/stale findings are `BLOCKED`.

## Isolation and locking

- A mutating lock is no broader than exact project + run.
- Runs belonging to other projects remain readable and runnable.
- Switching Project Console never changes another project's journal.
- Read-only review does not require a global launcher lock.
- Runtime choice does not own or lock orchestration state.

## UI requirements

Project Console shows unfinished runs conservatively. Status code is accompanied
by a plain-language reason and safe next action. Detailed/compact view changes
only explanation density and never hides project, scope, status or blocker.
The console always distinguishes supported Cycle 1 from Cycle 2/3 status
`FROZEN / NOT READY`; frozen cycles never appear as resumable/runnable scope.
