#!/usr/bin/env bash

set -euo pipefail

fail() { echo "mem0-oss-v1: $*" >&2; exit 2; }
value() { awk -F= -v key="$2" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$1"; }
endpoint="${MEMORY_PROVIDER_ENDPOINT:-}"
namespace="${MEMORY_PROVIDER_NAMESPACE:-}"
credential="${MEMORY_PROVIDER_CREDENTIAL:-}"
command -v curl >/dev/null 2>&1 || fail 'curl is required'
command -v jq >/dev/null 2>&1 || fail 'jq is required'
headers=(-H 'Content-Type: application/json')
[[ -z "$credential" ]] || headers+=(-H "X-API-Key: ${credential}")

request() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 60 --max-filesize 16777216 -X "$method" "${headers[@]}" --data-binary "$data" "$endpoint$path" || fail 'provider request failed'
  else
    curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 60 --max-filesize 16777216 -X "$method" "${headers[@]}" "$endpoint$path" || fail 'provider request failed'
  fi
}

case "${1:-}" in
  doctor)
    request GET '/configure/providers' >/dev/null
    echo 'mem0-oss-v1 ready'
    ;;
  apply)
    record="${2:-}"
    [[ -f "$record" && ! -L "$record" ]] || fail 'record file required'
    encoded="$(base64 <"$record" | tr -d '\n')"
    record_id="$(value "$record" record_id)"
    body="$(value "$record" body_b64 | base64 -d)" || fail 'invalid body encoding'
    data="$(jq -cn --arg content "$body" --arg user "$namespace" --arg record "$encoded" --arg id "$record_id" '{messages:[{role:"user",content:$content}],user_id:$user,infer:false,metadata:{sdlc_record_b64:$record,sdlc_record_id:$id}}')"
    request POST '/memories' "$data" >/dev/null
    ;;
  query)
    output="${3:-}"
    [[ -d "$output" && ! -L "$output" ]] || fail 'query output directory required'
    response="$(request GET "/memories?user_id=$namespace&limit=1001")"
    mapfile -t records < <(jq -r '(.results // .)[]? | .metadata.sdlc_record_b64 // empty' <<<"$response")
    (( ${#records[@]} <= 1000 )) || fail 'provider query exceeds 1000 records'
    reported_count="$(jq -r 'if type == "object" then (.count // .total // (.results | length) // 0) else length end' <<<"$response")"
    [[ "$reported_count" =~ ^[0-9]+$ && "$reported_count" -le ${#records[@]} ]] || fail 'provider response is incomplete; this Mem0 OSS distribution cannot prove full read-back'
    n=0
    for encoded in "${records[@]}"; do n=$((n + 1)); printf '%s' "$encoded" | base64 -d >"$output/$(printf '%05d' "$n").record" || fail 'invalid provider record encoding'; done
    ;;
  *) fail 'expected doctor, apply or query' ;;
esac
