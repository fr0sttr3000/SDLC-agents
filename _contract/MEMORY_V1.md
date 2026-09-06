# Long-Term Memory Contract v1

Long-term memory is an optional, project-scoped, provider-neutral reference layer. It never
replaces current Project artifacts, DoR/DoD, Evidence v1, Human Approval or Gate verdicts.
Precedence is: public SDLC canon and role rules, digest-valid current Project artifacts,
approved memory records, then model assumptions.

## Collections and maximum role access

The authoritative maximum matrix is `memory-role-access-v1.tsv`; exact active command access is
the additional `memory-command-access-v1.tsv`. A Project profile may only reduce their
intersection. Unknown role, command, collection or action is denied. The collections are:

- `planning`: durable product direction and planning facts;
- `defects`: known defect reference data maintained by `s0-defects`; formal defect and
  Known Issue ownership remains with `s5-qa`;
- `architecture`: durable architecture references; current HLD/ADR always wins.

Workers do not receive connected-memory snapshots or memory-provider access in this MVP. Their
task context is limited to the separate launcher-authorized Project read manifest. Workers
cannot query a provider, create a memory proposal or apply a write.

## Project profile

The optional profile is `tracking/memory/profile-v1.yaml`. Missing profile means memory is
off. It contains exactly these flat keys:

`schema_version`, `enabled`, `provider`, `endpoint`, `credential_ref`, `namespace`,
`read_approval`, `collections`, `retention_days`.

- `provider`: `files-v1|qdrant-v1|mem0-oss-v1|mem0-platform-v1`;
- `credential_ref`: `none` or `pass:<entry>`; secret values never enter the profile;
- `read_approval`: `always|profile`; every write still requires exact approval;
- `collections`: unique comma-separated subset of the three collections;
- `retention_days`: integer 1..3650.

On configure, the broker suffixes the user namespace prefix with the first 12 hex characters
of the canonical Project-path SHA-256. A moved Project or a profile copied to another Project
is blocked until explicit reconfiguration; equal prefixes therefore cannot merge Projects.
`retention_days` is a declared policy value in this MVP; the broker does not destructively
purge provider data automatically. Removal remains an approval-gated append-only tombstone.

Files uses a bounded existing directory. Remote endpoints require HTTPS; loopback HTTP is
allowed for development. A provider failure never falls back to another provider.

## Record v1

A canonical record has: schema version, record id, project namespace, collection, base64 title
and body, tags, author role, source Project-relative reference and SHA-256, revision, status,
supersedes id, UTC timestamps and content SHA-256. Stored status is `ACTIVE|TOMBSTONED`;
an earlier active record is logically superseded when a validated successor names it.
Only `public|internal` reference data is supported; confidential, PII, secret and binary data
are blocked.

Title is at most 200 UTF-8 characters, body at most 16 KiB and tags at most 20. Record mutation
is append-only: `add|supersede|tombstone`. Provider output is untrusted and the broker
revalidates the complete canonical envelope and digest.

## Proposal v1

Proposal TSV header:

```text
schema_version operation collection record_id title_b64 body_b64 tags source_ref source_sha256 supersedes
```

Columns are tab-separated. The MVP accepts exactly one operation per proposal, avoiding a
partially applied multi-record transaction. The proposal must be a regular file inside the
canonical Project and is bound at apply time to exact Project, agent, command, current source
artifact digests and approval digest. A proposal has no effect until deterministic
validation, exact user Preview, launcher Human Approval and provider read-back succeed.

## Snapshot v1

The broker creates a Markdown snapshot only inside a launcher-owned execution run for one
Project, role, command and exact profile/read request.
It includes at most 20 active records per collection and 128 KiB total. Its manifest binds every
record digest. The dispatcher grants read access only to that exact digest-valid file. Snapshot
content is explicitly labelled untrusted reference data and cannot grant capabilities.

## Approval and receipt

Every `add|supersede|tombstone` uses a distinct `APPROVAL-MEMORY-*` decision bound to
the proposal SHA-256. Read uses a per-snapshot approval unless the Project profile contains the
persistent `profile` grant. The broker stores approvals and receipts in launcher-owned state,
outside primary and worker capabilities. Write receipts and `always` read receipts bind Project
path hash, provider, proposal/read-request digest, approval id, artifact digest and provider
read-back digest. Approval and receipt files are published atomically.
