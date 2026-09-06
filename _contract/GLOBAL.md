# Universal SDLC Agent Contract

This directory is the vendor-neutral contract for SDLC agents.

The contract is canonical for cross-runtime behavior:
- SDLC stages, gates, DoR/DoD, standards, and artifact paths do not depend on a specific AI runtime.
- Runtime-specific files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/`, `.codex/`, `.gemini/`) are adapters.
- New SDLC rules must be added to `_standards/`, root `CLAUDE.md`, agent `CLAUDE.md`, or command templates before they are exposed through a runtime adapter.

## Compatibility Rule

Claude-compatible files remain the canonical authoring format for agents:
- root `CLAUDE.md` = global SDLC context
- `cycle*/{agent}/CLAUDE.md` = role-specific context
- `.claude/commands/*.md` = shared command templates
- `_standards/*.md` = mandatory standards

Codex and Gemini adapters must read or reference the same files instead of maintaining independent copies of SDLC logic.

## Product Documentation Governance

Product principles and development plans are kept separately from the runtime contract:
- `plans/principles.md` — canonical stable product principles: what the system guarantees and why;
- `plans/roadmap.md` — ordered `Now`/`Next`/`Later` product outcomes with dependencies and exit evidence;
- delivered scope and history are referenced from the roadmap rather than copied into a second inventory.

Executable launcher and dispatcher scripts are implementation, not documentation. `CHANGELOG.md`
and release notes are updated during release preparation rather than used as the active backlog.

## Runtime Invariants

Every runtime must preserve:
- the supported execution scope is the common platform plus Cycle 1; Cycle 2/3 are
  `FROZEN / NOT READY`, are not launcher routes and do not block Cycle 1;
- Markdown-first governance through `$SDLC_PROJECTS_DIR/{PROJECT}/...`; executable tests,
  code, API/schema, SQL/IaC and other native artifacts retain their native formats
- `SDLC_PROJECTS_DIR` as the parent directory of projects; in single-project launcher mode the active project is tracked separately through `SDLC_SINGLE_PROJECT`
- isolated agents; no direct agent-to-agent memory transfer
- explicit file contracts in `inputs/`, `outputs/`, and `tracking/`
- validated Product & CI Profile from `_contract/PRODUCT_CI_PROFILE.md` before Stage 1;
  unknown mandatory facts block instead of receiving silent defaults
- new/updated profiles use schema v5 to select repository CI, connected runner or live
  local/offline evidence source, confirm UX applicability and record representative S5
  environment/PERF/SG4 plus compatibility/accessibility/flexibility/safety applicability;
  core consumes confirmed capabilities, never invents a pipeline/test platform and never
  infers UI or validation scope from product type
- `_contract/QUALITY_CHARACTERISTICS_V1.md` binds each characteristic to an existing owner,
  evidence contract and active Gate; optional N/A comes only from the current profile and no
  project fact can weaken the global only-up minimum
- test/security/build/policy machine checks follow `_contract/EVIDENCE_V1.md`; Markdown views,
  offline proposals and process exit 0 are not verified evidence
- Gate 4 requires exact-source PR evidence, profile-bound compatibility, complete
  maintainability review, independent SG3 policy, selected-executor controls and an only-up
  quality policy revision
- Gate 5 requires five owner-bound S5 streams on the same source/build, separate environment
  and UAT approvals, one defect register and a machine-verified Go/No-Go
- Quality Gate + Security Gate enforcement
- secrets only through `pass`
- no hardcoded local user paths
- explicit runtime/model selection; local profiles require an exact agent host,
  provider and model id
- hybrid routing policy is exactly `single|per-stage|per-agent|ask`; every
  resolved step has one explicit profile
- no default model and no silent fallback between models, providers or runtimes
- primary agent runtimes do not mutate repository history or remotes and do not create
  commits, pushes, pull requests or tags; these control-plane actions stay outside agent dispatch
- Codex task processes must ignore ambient user configuration; nested Codex and built-in
  `codex-oss` therefore use `--ignore-user-config`, while unsupported interactive/session
  dispatch fails closed before the runtime starts
- every primary cycle/tool process on supported Linux follows
  `_contract/RUNTIME_ACCESS_V1.md`: public canon is read-only, exact Project/notes rights
  follow command access, isolated scratch is process-local, and ambient HOME, siblings,
  unspecified paths, VCS metadata and runtime-denied roots receive no capability
- optional Supervisor + Worker design follows `_contract/SUBAGENTS.md`; the primary stage agent
  remains the sole writer and gate signer
- `auto|cross-runtime` workers require launcher-owned request/scope/route authorization and
  runtime/OS-enforced exact bounded read-only access; direct or mismatched dispatch is `BLOCKED`
- optional long-term memory follows `_contract/MEMORY_V1.md`: exact role ACL, immutable
  launcher snapshot, proposal-only agent writes and user-approved broker read-back
- launcher orchestration state follows `_contract/EXECUTION_JOURNAL.md`; it is
  isolated by project+run and never owned by a vendor session
