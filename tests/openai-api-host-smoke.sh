#!/usr/bin/env bash

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
HOST="$ROOT/_runtimes/local-hosts/openai-api"
RUNNER="$ROOT/_runtimes/agent-run.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$HOST" ]] || fail 'openai-api host missing or not executable'
bash -n "$HOST" "$RUNNER" || fail 'OpenAI host/dispatcher syntax rejected'
grep -Fq 'ACCESS" == read-only' "$HOST" || fail 'OpenAI host is not read-only-only'
grep -Fq 'store:false' "$HOST" || fail 'Responses API storage is not disabled'
grep -Fq 'Authorization: Bearer' "$HOST" || fail 'Responses API bearer header missing'
grep -Fq -- '--connect-timeout 10' "$HOST" || fail 'Responses API connect timeout missing'
grep -Fq -- '--max-time 60' "$HOST" || fail 'Responses API total timeout missing'
grep -Fq -- '--max-filesize 16777216' "$HOST" || fail 'Responses API response-size limit missing'
grep -Fq 'LOCAL_MODEL_CREDENTIAL_REF=pass:<entry>' "$RUNNER" || fail 'dispatcher does not require pass credential reference'
grep -Fq 'LOCAL_MODEL_API_KEY=${LOCAL_MODEL_CREDENTIAL_VALUE}' "$RUNNER" || fail 'credential is not passed only through sanitized process env'
grep -Fq 'LOCAL_MODEL_API_KEY=' "$HOST" && fail 'host contains a credential literal assignment'

echo 'PASS: OpenAI API advisory host smoke'
