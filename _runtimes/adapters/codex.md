# Codex Runtime Adapter

Codex is available as an explicitly selected launcher profile. Launcher/argv/sandbox routing is
verified by synthetic compatibility tests; full live Project E2E remains experimental until an
explicit user-authorized run succeeds. User launch and setup instructions exist only in
`README.md`.

The adapter uses:
- `AGENTS.md` as a bridge to the canonical `CLAUDE.md` files
- `.codex/config.toml` to include `CLAUDE.md` as a fallback instruction file
- the same `.claude/commands/*.md` templates as Claude
- `codex exec --ignore-user-config --sandbox workspace-write --ephemeral --cd "$PROJECT_DIR" "$PROMPT"` for write task mode
- optional `--add-dir "$NOTES_DIR"` only for the separate Local Run notes directory
- `codex exec --ignore-user-config --sandbox read-only --ephemeral --cd "$PROJECT_DIR"` for primary Review

The selected product project, not `_agents`, is the Codex workspace root. `--add-dir` adds only
the explicitly selected notes scope; `danger-full-access` is not used. The dispatcher validates
the canonical role path separately and passes its instruction locations in the prompt.
Every task is a new ephemeral Codex process. The `--ignore-user-config` flag prevents ambient
user configuration from becoming product-agent instructions. Nested
interactive Codex is not supported because the current interactive CLI cannot apply that
boundary; `interactive|session-start` fail closed before runtime invocation. Select a registered
command so the launcher uses task mode. The outer Codex App chat id and arbitrary vendor/session
environment are not inherited; the Project Execution Journal, not a Codex conversation, is the
resume source.

Before `codex exec`, the shared dispatcher applies Runtime Access v1 through Linux Landlock.
Public canon is read-only; exact Project/notes rights follow command access; isolated scratch
is process-local; ambient HOME, siblings, unspecified paths and runtime-denied roots receive no
capability. Missing kernel support, helper source, compiler or enforcement fails closed; this
boundary does not make Codex a supported worker.

## Codex App compatibility

| Capability | Evidence | Status |
|---|---|---|
| Open `_agents` as a folder/project and create a Codex chat | Official [desktop app guide](https://learn.chatgpt.com/docs/app) | DOCUMENTED |
| Run `sdlc.sh`/`localrun.sh` in the chat terminal | Official [integrated terminal guide](https://learn.chatgpt.com/docs/integrated-terminal) says the terminal is scoped to the current project/worktree and runs scripts | DOCUMENTED |
| Choose `Local` vs `Worktree` intentionally | Official [environment modes](https://learn.chatgpt.com/docs/environments/modes) and [worktree behavior](https://learn.chatgpt.com/docs/environments/git-worktrees) | DOCUMENTED |
| Nested non-interactive `codex exec` from a terminal | `tests/codex-app-launcher-compat-smoke.sh` validates argument routing and fail-closed behavior | VERIFIED |
| Exact `--cd`, optional `--add-dir`, sandbox, ephemeral session and paths with spaces | Deterministic dispatcher compatibility smoke with a fake runtime | VERIFIED |
| Full live canonical role prompt plus real Project content | Validated only by an explicit user-authorized project run, not by the synthetic compatibility smoke | LIVE EXECUTION REQUIRED |

The supported App route is the canonical launcher in the integrated terminal, with explicit
workflow start and Preview. The compatibility smoke verifies the nested CLI mechanism without
sending real Project content. Sandbox troubleshooting and alternative terminal guidance remain
in `README.md`.

Managed Worktrees start from a Git checkout; untracked files are not copied, and ignored files
require an explicit `.worktreeinclude`. This can omit Project/Vault material outside the
repository. The supported user choice for this Vault layout is documented in `README.md`.

On Windows, `sdlc.ps1` and `localrun.ps1` are experimental thin entrypoints, not tested on
Windows and outside the supported platform scope. The PowerShell wrappers preserve quoted paths
and delegate to the same Bash implementation; no Windows-only SDLC rules exist. Current user
status and setup guidance remain in `README.md`.

Bounded workers are task-only and require launcher-owned request/read-manifest/route
authorization. Landlock grants only exact manifest paths; Codex additionally uses
`--sandbox read-only --ephemeral --ignore-user-config`. Direct or mismatched dispatch blocks.
Codex-specific skills or hooks do not become the source of SDLC rules.
