# Claude Runtime Adapter

Claude is one supported runtime. The launcher does not select it implicitly. User launch and
profile-selection instructions exist only in `README.md`.

The adapter uses:
- root `CLAUDE.md`
- nearest agent `CLAUDE.md`
- `.claude/commands/*.md`
- `claude --print --no-session-persistence "$PROMPT"` for task mode
- read-only task mode additionally limits tools to `Read,Glob,Grep` and uses `dontAsk`
- one isolated interactive launch; no automatic or public unbound `--continue`

The dispatcher starts from the exact project directory, passes an optional Local Run notes
directory with `--add-dir`, removes vendor session variables and does not resume a previous
conversation. Orchestration retry/resume comes only from the Execution Journal as a new launch.
Before Claude starts, the shared dispatcher applies Runtime Access v1 through Linux Landlock:
public canon is read-only, exact Project/notes rights follow command access, and ambient HOME,
siblings and runtime-denied roots receive no capability. Missing support or enforcement fails
closed.
Bounded workers are task-only and require launcher-owned request/read-manifest/route
authorization. Landlock grants only exact manifest paths; Claude additionally receives only
`Read,Glob,Grep` with `dontAsk` and no session persistence. Direct or mismatched dispatch blocks.

No SDLC logic is stored in this adapter. It only describes how the universal contract is executed by Claude Code.
