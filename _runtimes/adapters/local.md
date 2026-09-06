# Local Model Runtime Adapter

Local inference is selected explicitly with `AGENT_RUNTIME=local`. A local
model endpoint alone is not an SDLC agent: an **agent host** must provide file
reading, tool execution, instruction loading and the write boundary required by
the Universal Runtime Contract.

## Required explicit profile fields

The launcher profile must resolve exact `LOCAL_AGENT_HOST`, `LOCAL_MODEL_PROVIDER` and
`LOCAL_MODEL` values. User selection examples exist only in `README.md`.

There is no default provider, model, agent host or silent fallback. An
unavailable host/model stops the step.

## Built-in host

`codex-oss` is the bundled agent host. It invokes Codex with `--oss`, exact
`--local-provider ollama|lmstudio`, and exact `--model`. Ollama and LM Studio
are inference providers, not a closed list of model families.

## Registered custom hosts

Administrators may add an executable adapter to the registered host directory
`_runtimes/local-hosts/` (or an explicitly supplied test/admin registry).
Configuration stores only its validated host id, never an arbitrary shell
command. Adapters may integrate vLLM, llama.cpp or another OpenAI-compatible
server, but they must implement the agent-host contract and accept:

```
--agent-dir <absolute path> --project-dir <absolute path> [--notes-dir <absolute path>] \
--mode <task|interactive|session-start> --access <write|read-only> --prompt <text>
```

The dispatcher passes only an environment allowlist with exact profile/path values required by
the adapter. It does not forward arbitrary secret-like variables or vendor session state.
Adapter files must not contain credentials; secrets remain in `pass`.

Before a registered local host starts, the shared dispatcher applies Runtime Access v1 through
Linux Landlock. Public canon is read-only, exact Project/notes rights follow command access, and
ambient HOME, siblings and runtime-denied roots receive no capability. Missing support or
enforcement fails closed.

## Supervisor + Local Worker

Bounded local workers use `codex-oss` or read-only `openai-api` only through
`_contract/WORKER_HANDOFF_V1.md`. Runtime/OS enforcement grants exact manifest reads instead of
the whole Project. Direct or digest/route-mismatched execution returns non-zero; fallback is off.

## Hybrid routing

The launcher supports four explicit policies:

- `single` — one profile for all steps;
- `per-stage` — an exact profile for each overridden stage;
- `per-agent` — an exact profile for each overridden agent;
- `ask` — explicit selection before each step.

Each resolved step has one exact runtime/profile. Missing mapping is an error in
`per-stage` and `per-agent`; it never falls back to the global/cloud runtime.
Routing changes orchestration only and does not change canonical agent rules.
