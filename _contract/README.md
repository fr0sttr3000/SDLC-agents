# Universal Runtime Contract

The SDLC Agent System can be executed through multiple AI runtimes while keeping one set of rules.

## Canonical Sources

- `_standards/*.md` — TDD, quality, security, data formats, templates
- `_standards/artifact-metadata.md` — shared metadata and Obsidian links for new/materially
  changed Cycle 1 governance, handoff, report and gate Markdown artifacts
- `_contract/PRODUCT_CI_PROFILE.md` — versioned pre-S1 product/build/test/CI facts
- `_contract/APPLICABILITY_V1.md` — one profile-bound applicability resolver and structured N/A
- `_contract/EVIDENCE_V1.md` — exact-source machine evidence, trust/freshness/digest contract
- `_contract/SG3_POLICY_V1.md` — independent CVSS/secrets/dependency policy
- `_contract/SG1_VALIDATION_V1.md` and `SG2_VALIDATION_V1.md` — early digest-bound
  security requirements/design semantics for Gates 2 and 3
- `_contract/RISK_EXCEPTION_V3.md` — typed, exact-finding exception and Tech Debt lifecycle
- `_contract/EXECUTOR_CONTROLS_V1.md` — selected executor minimum control evidence
- `_contract/QUALITY_POLICY_V1.md` — versioned deterministic only-up project thresholds
- `_contract/quality-policy-v1.tsv` — authoritative quality metric/operator/global/unit registry
- `_contract/QUALITY_METRIC_EVIDENCE_V1.md` — digest-bound metric/threshold/observed evidence
- `_contract/QUALITY_CHARACTERISTICS_V1.md` — profile-bound applicability, existing owners,
  evidence contracts and active Cycle 1 gates for 11 project quality controls
- `_contract/TRACEABILITY_V1.md` — requirement→specification→test→source evidence binding
- `_contract/HUMAN_APPROVAL_V1.md` — separate exact-subject human decision record
- `_contract/GATE1_PLANNING_V1.md` — pre-Finance candidate, effective decision and
  digest-bound PMO semantics
- `_contract/PRODUCT_ACCEPTANCE_V1.md` — profile-bound UX applicability and Must-FR→UAT trace
- `_contract/ARCHITECTURE_DECISION_TRACE_V1.md` — NFR→QA→Tactic→Pattern→ADR binding
- `_contract/RUNTIME_CONSTRAINTS_V1.md` — canonical kickoff→PMO→NFR→HLD execution
  constraint trace with legacy-field migration and no deployment authorization
- `_contract/TDD_STATUS_V1.md` — exact-source Red/full-affected regression handoff
- `_contract/S5_VALIDATION_V1.md` — five-stream exact-source S5 evidence, UAT approval,
  single defect register and Gate 5 decision
- `_contract/CYCLE1_COMPLETION_V1.md` — legacy completion schema; historical interpretation only
- `_contract/CYCLE1_COMPLETION_V2.md` — current full-plan/Journal/Gates/DoD/evidence handoff
- `_contract/CURRENT_ARTIFACTS_V1.md` — logical artifact registry, current refs and history protocol
  without release, push, deploy or frozen Cycle 2/3 prerequisites
- `_contract/PR_SET_V1.md` — exact complete multi-PR summary/update/review set required by Gate 4
- `_contract/RELEASE_NOTES_V1.md` — optional post-completion Project Markdown handoff with
  exact version/source, idempotency/conflict rules and no external publication/build/deploy actions
- `_contract/COMMAND_CAPABILITIES_V1.md` and `command-capabilities-v1.tsv` — authoritative
  classification, access and result verifier for every active command template
- `_contract/RUNTIME_ACCESS_V1.md` and `runtime-access-v1.tsv` — shared capability-enforced
  read/write matrix for every primary runtime
- `_contract/SUBAGENTS.md`, `_contract/WORKER_HANDOFF_V1.md` and
  `worker-task-kinds-v1.tsv` — bounded read-only worker policy and digest-bound file handoff
- `_contract/MEMORY_V1.md`, `memory-role-access-v1.tsv`, `memory-command-access-v1.tsv` and
  `MEMORY_USER_GUIDE.md` — optional Project memory schema, role/command ACL, supported providers
  and user connection instructions
- `_contract/MEMORY_MVP_AUDIT.md` — implementation audit, verification evidence, residual risks
  and live external-provider release conditions
- `_contract/CHANGE_SCOPE_V1.md` — Change Intent, L1/S3 isolated discovery, human-approved
  Stage 4 path ownership, scoped runtime writes and full-tree diff verification
- root `CLAUDE.md` — global SDLC context and behavioral rules
- `cycle*/{agent}/CLAUDE.md` — role-specific agent contracts
- `.claude/commands/*.md` — shared command prompt templates

`sdlc.sh`, `localrun.sh`, Windows wrappers `sdlc.ps1`/`localrun.ps1`, `_runtimes/*` and validators are executable implementation which must
conform to the canonical Markdown contracts; they are evidence, not documentation sources.
Documentation synchronization scope, current implementation status and active product work are
described in `plans/roadmap.md`. Stable principles remain in `plans/principles.md`.

## Runtime Adapters

Supported orchestration covers the common platform and Cycle 1. Cycle 2/3 are
`FROZEN / NOT READY`: adapters must show that status and must not expose an execution route.

- Claude: `CLAUDE.md`, `.claude/commands/*.md`, `_runtimes/adapters/claude.md`
- Codex: `AGENTS.md`, `.codex/config.toml`, `_runtimes/adapters/codex.md`
- Gemini: `GEMINI.md`, `_runtimes/adapters/gemini.md`
- Local: `_runtimes/adapters/local.md`; exact registered agent host, provider and model id
- Windows shell entry: `sdlc.ps1` / `localrun.ps1` delegate to the same canonical Bash
  launchers through `_runtimes/windows-launcher.ps1`; they do not duplicate SDLC logic.
  Status is `EXPERIMENTAL / NOT TESTED ON WINDOWS`; Windows is outside the supported platform
  scope. A real Windows CI matrix must prove parser/mutation, Git Bash auto/explicit routing,
  space/non-ASCII paths, UNC rejection, argv and exit propagation on an exact revision before
  any status change; workflow presence alone is not evidence.

Built-in `codex-oss` supports Ollama and LM Studio. vLLM, llama.cpp and OpenAI-compatible
endpoints require a registered executable agent-host adapter. A raw endpoint alone is not an
SDLC agent runtime. Routing is explicitly `single|per-stage|per-agent|ask`; missing profiles
fail instead of falling back to another model/provider/runtime.

Codex launcher tasks use a new `codex exec --ignore-user-config --ephemeral` process for every
step. Nested interactive Codex is fail-closed. The Codex App
route and its verified/unverified compatibility claims are recorded in
`_runtimes/adapters/codex.md`; the App does not define separate SDLC behavior.

Before any primary cycle/tool runtime starts on supported Linux, the shared dispatcher applies
the Runtime Access v1 Landlock matrix. Public canon is read-only; exact Project/notes access is
selected by the command; an isolated per-process scratch is writable; ambient HOME, sibling
Projects, source-checkout VCS metadata, runtime-denied roots and unspecified paths receive no
capability. Missing helper, compiler, kernel support or successful enforcement blocks dispatch.

Stage 4 uses the narrower `scoped-write` profile. A current approved Change Scope selects the
write paths for one exact agent/command; all other Project paths and notes remain read-only.
Launcher-owned before/after manifests and the declared-output verifier must both pass before
`ARTIFACT_VERIFIED`.

Secret-like prompt values are rejected by the shared runtime boundary before Preview/dispatch;
the rejected value is not printed. Project secrets remain pass references, never prompt content.

Legacy Project inventory is additive and read-only through
`cycle1-dev/s0-validate/legacy-migration-report.sh`; it cannot promote self-attested PASS.

## TDD and Subagents

`_standards/tdd.md` defines Specify → Red → Green → Run → Repair → Refactor for every
applicable change. `_contract/SUBAGENTS.md` and `_contract/WORKER_HANDOFF_V1.md` define the
optional bounded read-only Supervisor + Worker route. `_contract/MEMORY_V1.md` and
`memory-role-access-v1.tsv` define the optional provider-neutral long-term memory boundary.

## Project Directory Modes

`sdlc.sh` supports two explicit modes:
- collection mode: `SDLC_PROJECTS_DIR` points to a directory containing multiple project folders;
- single-project mode: the user selects one project folder, `SDLC_PROJECTS_DIR` stores its parent directory, and `SDLC_SINGLE_PROJECT` stores the selected project name.

Agents must continue using the canonical path contract `$SDLC_PROJECTS_DIR/{PROJECT}/...`.

## Execution Journal

`_contract/EXECUTION_JOURNAL.md` defines the per-project, per-run orchestration
state, immutable plan snapshot, statuses, append-only events, safe resume and
isolation. It does not use vendor conversation resume or a global checkpoint.

## Rule

Vendor-specific adapter files may explain how to run the system, but they must not define unique SDLC behavior. New behavior belongs in the canonical sources above.
