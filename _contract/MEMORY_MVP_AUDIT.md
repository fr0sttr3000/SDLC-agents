# Connected Memory MVP — implementation audit

Audit date: 2026-08-27. Verdict: **CONDITIONAL PASS**.

The MVP is suitable for public/internal reference data with the fail-closed boundaries below.
External provider deployments require their own live compatibility evidence before production
use. Memory never authorizes a gate, approval, external action or role capability.

## Implemented boundary review

| Control | Verdict | Evidence in implementation |
|---|---|---|
| Memory default-off and Project isolation | PASS | Missing/disabled profile is off; canonical Project path is hashed into namespace; copied/moved profiles, cross-namespace records and Projects inside the agent system are blocked. |
| Role and command isolation | PASS | Effective access is the intersection of role ACL, exact command ACL and Project collection subset; unknown values deny. |
| User permission | PASS | `always` reads bind approval to profile, role, command, collections and query digest; writes freeze one proposal, show exact operation metadata and require a separate digest-bound approval. |
| File handoff | PASS | Proposal must be a regular file inside canonical Project; snapshot is created only in launcher-owned execution state and passed as exact path + SHA-256. |
| Provider and secret boundary | PASS | Model processes never receive endpoint or credential; only `none|pass:` references are stored; HTTPS/loopback rules, response/time limits and no fallback are enforced. |
| Provider tamper/lifecycle validation | PASS | Complete flat record shape, digest, namespace, author/collection ACL, sizes, tags, timestamps, unique ids, sequential append-only lifecycle, no fork and provider read-back are checked. |
| Memory prompt-injection containment | PASS WITH RESIDUAL RISK | Snapshot is explicitly untrusted and lower precedence than canon/current artifacts; it cannot expand OS/runtime capabilities. Free-form semantic content still requires normal artifact review. |
| Worker role isolation | PASS | Primary can publish only one process-local request per step; user selects exact read paths and confirms; request/scope/route/credential reference are digest-bound. |
| Worker capability isolation | PASS | Only active Cycle 1 roles are valid; Project/memory writes, provider access, nested delegation, gates, approvals, external actions, fallback and ambient context are denied. |
| Worker context exchange | PASS | Result is launcher-owned advisory data shown to the user; it is not injected into primary/siblings. Promotion requires a normal Project artifact and a new run. |
| Multi-provider routing | PASS | Primary route can be single/per-stage/per-agent/ask; worker route can be same or exact cross-runtime profile. Claude, Codex and local bounded hosts are supported; Gemini remains primary-only until read-only capability is proven. |

## Verification completed

- Bash syntax validation for launcher, CLI, memory broker, four provider adapters, runtime
  dispatchers and new smoke tests;
- PASS: memory ACL and provider-adapter smokes;
- PASS: OpenAI API advisory-host smoke;
- PASS: launcher first-run and navigation smokes;
- PASS: command-capability, active-scope, runtime-constraint, principles, Markdown,
  documentation/link and public-root inventory regressions.

Current `memory-v1`, Worker Request channel and supervisor-worker OS-bound integration smokes
require an external test Project. They were added to the system suite but were not executed in
this audit environment after final hardening. Live Qdrant/Mem0 endpoints and credentials were
also unavailable; protocol/static adapter tests are not live certification.

## Residual risks and release conditions

1. **External compatibility (release condition):** run live add/read-back/snapshot/denial tests
   for each advertised Qdrant or Mem0 deployment. No result may be generalized to another
   version/distribution.
2. **Mem0 OSS inference (release condition):** use only a distribution independently proven to
   honor `infer=false`. `doctor` cannot prove absence of server-side LLM extraction; otherwise
   use Files or Qdrant.
3. **Semantic data provenance (medium):** provider records are structurally validated and
   user-authorized but not cryptographically signed by their original approver. Treat all body
   text as untrusted; a future signed attestation/import ledger is recommended.
4. **Sensitive-data classification (medium):** common secret patterns and controls are blocked,
   but deterministic PII/confidential-content classification is outside this MVP. Only
   public/internal data explicitly selected by the user is allowed.
5. **External mutation crash window (low):** a process crash after append and before local
   receipt can leave an orphan record; automatic destructive rollback is intentionally absent.
6. **Local store concurrency (low):** Files paths are containment/symlink checked, but a hostile
   same-user process racing directory replacement is outside the current shell-adapter guarantee.

Production enablement is blocked until the relevant external live matrix passes. Files remains
the local baseline; all failures stay fail-closed without provider/model fallback.
