#!/usr/bin/env bash

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROLE="$ROOT/_contract/memory-role-access-v1.tsv"
COMMAND="$ROOT/_contract/memory-command-access-v1.tsv"
CAP="$ROOT/_contract/command-capabilities-v1.tsv"
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ "$(sed -n '1p' "$ROLE")" == $'schema_version\tagent\tcollection\tread\tpropose_add\tpropose_supersede\tpropose_tombstone' ]] || fail 'role ACL header mismatch'
[[ "$(sed -n '1p' "$COMMAND")" == $'schema_version\tagent\tcommand\tcollection\tread\tpropose_add\tpropose_supersede\tpropose_tombstone' ]] || fail 'command ACL header mismatch'

awk -F'\t' '
  NR == 1 {next}
  NF != 7 || $1 != 1 || $3 !~ /^(planning|defects|architecture)$/ {exit 1}
  {key=$2 FS $3; if (seen[key]++) exit 1; for (i=4; i<=7; i++) if ($i !~ /^(allow|deny)$/) exit 1}
' "$ROLE" || fail 'role ACL is malformed or duplicated'

while IFS=$'\t' read -r schema agent command collection read add supersede tombstone extra; do
  [[ -z "$extra" && "$schema" == 1 && "$command" == /* ]] || fail 'command ACL row is malformed'
  role_row="$(awk -F'\t' -v a="$agent" -v c="$collection" 'NR > 1 && $2 == a && $3 == c {print $4 FS $5 FS $6 FS $7; n++} END {if (n != 1) exit 1}' "$ROLE")" || fail "$agent/$collection has no unique role ACL"
  IFS=$'\t' read -r role_read role_add role_supersede role_tombstone <<<"$role_row"
  for pair in "$read:$role_read" "$add:$role_add" "$supersede:$role_supersede" "$tombstone:$role_tombstone"; do
    [[ "$pair" != allow:deny ]] || fail "$agent $command widens role ACL"
  done
  [[ "$(awk -F'\t' -v a="$agent" -v m="$command" 'NR > 1 && $2 == a && $3 == m {n++} END {print n+0}' "$CAP")" == 1 ]] || fail "$agent $command is not an active unique command"
done < <(tail -n +2 "$COMMAND")

[[ "$(awk -F'\t' 'NR > 1 && $4 == "defects" && ($6 == "allow" || $7 == "allow" || $8 == "allow") && $2 != "s0-defects" {n++} END {print n+0}' "$COMMAND")" == 0 ]] || fail 'non-defects role can write defects memory'
[[ "$(awk -F'\t' 'NR > 1 && $4 == "architecture" && ($6 == "allow" || $7 == "allow" || $8 == "allow") && $2 != "s3-arch" {n++} END {print n+0}' "$COMMAND")" == 0 ]] || fail 'non-architect role can write architecture memory'

echo 'PASS: memory ACL smoke'
