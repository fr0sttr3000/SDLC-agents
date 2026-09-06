#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROVIDERS="$ROOT/_runtimes/memory/providers"
fail() { echo "FAIL: $*" >&2; exit 1; }

for provider in files-v1 qdrant-v1 mem0-oss-v1 mem0-platform-v1; do
  file="$PROVIDERS/$provider.sh"
  [[ -x "$file" ]] || fail "$provider adapter is missing or not executable"
  bash -n "$file" || fail "$provider syntax rejected: $provider"
done

grep -Fq 'api-key:' "$PROVIDERS/qdrant-v1.sh" || fail 'Qdrant api-key header missing'
grep -Fq 'vector:{}' "$PROVIDERS/qdrant-v1.sh" || fail 'Qdrant vectorless point contract missing'
grep -Fq "'/memories'" "$PROVIDERS/mem0-oss-v1.sh" || fail 'Mem0 OSS current endpoint missing'
grep -Fq 'infer:false' "$PROVIDERS/mem0-oss-v1.sh" || fail 'Mem0 OSS exact-storage mode missing'
grep -Fq "'/v3/memories/add/'" "$PROVIDERS/mem0-platform-v1.sh" || fail 'Mem0 Platform v3 add endpoint missing'
grep -Fq 'Authorization: Token' "$PROVIDERS/mem0-platform-v1.sh" || fail 'Mem0 Platform auth header missing'
grep -Fq '/v1/event/' "$PROVIDERS/mem0-platform-v1.sh" || fail 'Mem0 Platform async completion check missing'

# Mem0 Platform v3 reports asynchronous success as SUCCEEDED. Missing or unknown status
# must never be interpreted as a successful write.
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/bin"
cat >"$tmp_root/bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
last=''
data=''
for ((i=0; i<${#args[@]}; i++)); do
  last="${args[$i]}"
  if [[ "${args[$i]}" == --data-binary && $((i + 1)) -lt ${#args[@]} ]]; then
    data="${args[$((i + 1))]}"
  fi
done
case "$last" in
  */v3/memories/add/)
    [[ "$(jq -r '.messages[0].content // empty' <<<"$data")" == body ]] || exit 65
    if [[ "${FAKE_MEM0_MODE:-succeeded}" == missing ]]; then
      printf '%s\n' '{}'
    else
      printf '%s\n' '{"status":"PENDING","event_id":"evt-1"}'
    fi
    ;;
  */v1/event/evt-1/)
    printf '%s\n' '{"status":"SUCCEEDED"}'
    ;;
  */memories)
    [[ "$(jq -r '.messages[0].content // empty' <<<"$data")" == body ]] || exit 65
    printf '%s\n' '{}'
    ;;
  *)
    printf '%s\n' '{}'
    ;;
esac
SCRIPT
cat >"$tmp_root/bin/sleep" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
chmod +x "$tmp_root/bin/curl" "$tmp_root/bin/sleep"
printf 'record_id=REC-1\nbody_b64=Ym9keQ==\n' >"$tmp_root/record"

oss_adapter="$PROVIDERS/mem0-oss-v1.sh"
if ! PATH="$tmp_root/bin:$PATH" \
  MEMORY_PROVIDER_ENDPOINT='http://127.0.0.1:8888' \
  MEMORY_PROVIDER_NAMESPACE='project-test' \
  MEMORY_PROVIDER_CREDENTIAL='' \
  "$oss_adapter" apply "$tmp_root/record" >/dev/null 2>&1; then
  fail 'Mem0 OSS adapter does not decode canonical padded base64 fields intact'
fi

adapter="$PROVIDERS/mem0-platform-v1.sh"
if ! PATH="$tmp_root/bin:$PATH" \
  MEMORY_PROVIDER_ENDPOINT='https://api.mem0.ai' \
  MEMORY_PROVIDER_NAMESPACE='project-test' \
  MEMORY_PROVIDER_CREDENTIAL='test-only' \
  "$adapter" apply "$tmp_root/record" >/dev/null 2>&1; then
  fail 'Mem0 Platform adapter rejects the current SUCCEEDED event status'
fi
if PATH="$tmp_root/bin:$PATH" \
  FAKE_MEM0_MODE=missing \
  MEMORY_PROVIDER_ENDPOINT='https://api.mem0.ai' \
  MEMORY_PROVIDER_NAMESPACE='project-test' \
  MEMORY_PROVIDER_CREDENTIAL='test-only' \
  "$adapter" apply "$tmp_root/record" >/dev/null 2>&1; then
  fail 'Mem0 Platform adapter accepts a missing status as success'
fi

for provider in files-v1 qdrant-v1 mem0-oss-v1 mem0-platform-v1; do
  grep -Fq "\`$provider\`" "$ROOT/_contract/MEMORY_USER_GUIDE.md" ||
    fail "user guide omits $provider"
done

echo 'PASS: memory provider adapters smoke'
