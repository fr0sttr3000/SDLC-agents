# Runtime Access Contract v1

Every supported primary cycle/tool process uses the same capability-enforced filesystem
matrix from `runtime-access-v1.tsv`. Vendor prompts and vendor sandboxes are defense in depth;
they do not replace this boundary.

The dispatcher canonicalizes every scope before launch. Public agent canon is readable but not
writable. The exact Project and optional notes directory are readable in primary task access modes.
They are wholly writable only for `access=write`; for `access=scoped-write`, notes remain
read-only and only digest-bound, existing Project paths selected by the launcher are writable.
Creation is authorized by selecting an existing parent directory and remains subject to the
post-run full-tree diff verifier. A per-process isolated runtime directory is the only
non-Project scratch capability. Ambient `HOME`, sibling Projects and every unspecified local
path receive no capability. The runtime executable must be outside ambient `HOME`, unless it
is itself part of the read-only public agent system.

`scoped-write` is task-only. It requires a strict runtime path table and its exact SHA-256 on
every launch. A missing, stale, oversized, traversing, symlinked or otherwise invalid table
blocks before the model runtime starts. The table may grant `write` or subtract `deny`; it
cannot make the Project, notes or public canon broadly writable.

A bounded worker also uses `access=read-only`, but supplies a strict `schema_version/path`
read manifest and digest. The dispatcher then does not grant the whole Project or notes tree:
it grants only canonical manifest paths. An optional launcher-owned memory snapshot is a
separate exact regular file with its own SHA-256. Missing, stale, traversing or symlinked
inputs, snapshots outside the execution run, and manifests above 64 paths block before start.

Checkout VCS metadata and every configured runtime-denied root are subtracted from otherwise
readable canon. Canonical path, symlink target and directory inode aliases are checked before
capabilities are issued. A symlink inside an allowed scope does not grant access to a target
outside that scope.

The Landlock helper accepts only explicit `--read`, `--write` and `--deny` paths. It never
starts from a writable filesystem root. Missing helper source, compiler, kernel support,
canonicalization or enforcement returns `BLOCKED` before the model runtime starts.

The isolated runtime directory supplies process-local `HOME` and `TMPDIR` and is removed
after the process. Opening `/dev/null` is the only device write needed by the dispatcher.
It is not Project output and cannot widen another path capability.
