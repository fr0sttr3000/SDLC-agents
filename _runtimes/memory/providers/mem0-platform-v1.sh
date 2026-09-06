#!/usr/bin/env bash

set -euo pipefail

fail() { echo "mem0-platform-v1: $*" >&2; exit 2; }
value() { awk -F= -v key="$2" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$1"; }
endpoint="${MEMORY_PROVIDER_ENDPOINT:-}"
namespace="${MEMORY_PROVIDER_NAMESPACE:-}"
credential="${MEMORY_PROVIDER_CREDENTIAL:-}"
command -v curl >/dev/null 2>&1 || fail 'curl is required'
command -v jq >/dev/null 2>&1 || fail 'jq is required'
[[ -n "$credential" ]] || fail 'Mem0 Platform credential is required'
headers=(-H 'Content-Type: application/json' -H "Authorization: Token $credential")

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
    data="$(jq -cn --arg user "$namespace" '{filters:{user_id:$user},page:1,page_size:1}')"
    request POST '/v3/memories/' "$data" >/dev/null
    echo 'mem0-platform-v1 ready'
    ;;
  apply)
    record="${2:-}"
    [[ -f "$record" && ! -L "$record" ]] || fail 'record file required'
    encoded="$(base64 <"$record" | tr -d '\n')"
    record_id="$(value "$record" record_id)"
    body="$(value "$record" body_b64 | base64 -d)" || fail 'invalid body encoding'
    data="$(jq -cn --arg content "$body" --arg user "$namespace" --arg record "$encoded" --arg id "$record_id" '{messages:[{role:"user",content:$content}],user_id:$user,infer:false,metadata:{sdlc_record_b64:$record,sdlc_record_id:$id}}')"
    response="$(request POST '/v3/memories/add/' "$data")"
    status="$(jq -r '.status // empty' <<<"$response")"
    case "$status" in
      PENDING)
        event_id="$(jq -r '.event_id // empty' <<<"$response")"
        [[ -n "$event_id" ]] || fail 'pending memory add has no event id'
        for _ in {1..20}; do
          response="$(request GET "/v1/event/$event_id/")"
          status="$(jq -r '.status // empty' <<<"$response")"
          case "$status" in
            SUCCEEDED|COMPLETED) break ;;
            FAILED) fail 'memory add event failed' ;;
            PENDING) ;;
            *) fail 'memory add event returned an unknown status' ;;
          esac
          sleep 1
        done
        ;;
      SUCCEEDED|COMPLETED) ;;
      FAILED) fail 'memory add failed' ;;
      *) fail 'memory add returned an unknown status' ;;
    esac
    case "$status" in
      SUCCEEDED|COMPLETED) ;;
      *) fail 'memory add did not complete before read-back' ;;
    esac
    ;;
  query)
    output="${3:-}"
    [[ -d "$output" && ! -L "$output" ]] || fail 'query output directory required'
    n=0
    for page in {1..100}; do
      data="$(jq -cn --arg user "$namespace" --argjson page "$page" '{filters:{user_id:$user},page:$page,page_size:100}')"
      response="$(request POST '/v3/memories/' "$data")"
      mapfile -t records < <(jq -r '.results[]? | .metadata.sdlc_record_b64 // empty' <<<"$response")
      page_count="$(jq -r '.results | length' <<<"$response")"
      [[ "$page_count" =~ ^[0-9]+$ && "$page_count" -eq ${#records[@]} ]] || fail 'provider page contains non-canonical memories'
      for encoded in "${records[@]}"; do
        n=$((n + 1)); (( n <= 10000 )) || fail 'provider query exceeds 10000 records'
        printf '%s' "$encoded" | base64 -d >"$output/$(printf '%05d' "$n").record" || fail 'invalid provider record encoding'
      done
      next="$(jq -r '.next // empty' <<<"$response")"
      [[ -n "$next" ]] || break
      (( page < 100 )) || fail 'provider pagination exceeds 100 pages'
    done
    ;;
  *) fail 'expected doctor, apply or query' ;;
esac
