# Worker Handoff Contract v1

Supervisor + Worker is an optional execution capability. It does not create another SDLC,
change stage ownership or permit direct agent-to-agent conversation. The primary is the only
Project writer and Gate signer.

## Modes

- `off` is the default;
- `auto` permits requests inside the user-approved frozen worker envelope;
- `cross-runtime` additionally requires an exact worker runtime/host/provider/model profile.

There is no runtime/model fallback. `SDLC_SUBAGENT_MAX` defaults to 2 and is limited to 1..16.

## Worker Request v1

A request is a flat YAML file with exactly:

`schema_version`, `request_id`, `primary_run_id`, `supervisor_agent`, `worker_agent`,
`kind`, `task_b64`, `response_format`.

`kind` is one of `analysis|research|review|test-interpretation` and must be present in the
frozen user-configured allowlist: one bounded advisory subtask assigned by the primary within
its current role/command. The launcher adds a separate digest-bound TSV read manifest and an
authorization envelope. The envelope binds request SHA-256, read-manifest SHA-256 and exact
route SHA-256 (`runtime|host|provider|model|endpoint|credential_ref`) to the immutable execution
plan. The reference is bound, never the secret value. The
primary cannot expand the read manifest, broaden the kind allowlist or select an unapproved route.

The primary can write the request only to `SDLC_WORKER_REQUEST_OUT`, a process-local file.
After the primary exits, the dispatcher validates the flat envelope and publishes it into the
exact execution-run worker directory. It does not start a worker. The user/launcher separately
previews exact paths/route and creates authorization.

## Capability boundary

The worker is a new sanitized task process. Runtime/OS capability enforcement grants read only
to the exact manifest paths and public canon. Connected-memory snapshots and memory-provider
access are not granted in this MVP. Project write, ambient HOME, siblings, secrets,
runtime-denied roots and unspecified paths are denied. Nested delegation, external actions and
approval creation are prohibited.

## Worker Result v1

The dispatcher, not the worker, creates a flat result envelope containing request digest,
worker identity/route, output base64, output digest and UTC timestamp. It is launcher-owned
advisory session data. The MVP shows it to the user and never re-injects it into a primary or
sibling worker. A user may promote an accepted conclusion through a normal Project artifact
and a new isolated run; vendor conversation resume and direct result sharing are forbidden.

Invalid output, worker failure or an unavailable exact route is `BLOCKED`. A retry is explicit
and uses a new worker execution bound to the same frozen envelope.
