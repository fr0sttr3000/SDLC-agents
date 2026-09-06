#!/usr/bin/env bash

set -euo pipefail

fail() { echo "qdrant-v1: $*" >&2; exit 2; }
endpoint="${MEMORY_PROVIDER_ENDPOINT:-}"
namespace="${MEMORY_PROVIDER_NAMESPACE:-}"
credential="${MEMORY_PROVIDER_CREDENTIAL:-}"
command -v curl >/dev/null 2>&1 || fail 'curl is required'
command -v jq >/dev/null 2>&1 || fail 'jq is required'
[[ "$namespace" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] || fail 'invalid collection namespace'
headers=(-H 'Content-Type: application/json')
[[ -z "$credential" ]] || headers+=(-H "api-key: ${credential}")

request() {
  local method="$1" url="$2" data="${3:-}" output
  if [[ -n "$data" ]]; then
    output="$(curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 60 --max-filesize 16777216 -X "$method" "${headers[@]}" --data-binary "$data" "$url")" || fail 'provider request failed'
  else
    output="$(curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 60 --max-filesize 16777216 -X "$method" "${headers[@]}" "$url")" || fail 'provider request failed'
  fi
  printf '%s' "$output"
}

case "${1:-}" in
  doctor)
    response="$(request GET "$endpoint/collections/$namespace")"
    [[ "$(jq -r '.status // empty' <<<"$response")" == ok ]] || fail 'collection is unavailable or incompatible'
    echo 'qdrant-v1 ready'
    ;;
  apply)
    record="${2:-}"
    [[ -f "$record" && ! -L "$record" ]] || fail 'record file required'
    digest="$(awk -F= '$1 == "content_sha256" {print $2}' "$record")"
    point_hex="${digest:0:32}"
    point_id="${point_hex:0:8}-${point_hex:8:4}-${point_hex:12:4}-${point_hex:16:4}-${point_hex:20:12}"
    record_b64="$(base64 <"$record" | tr -d '\n')"
    collection="$(awk -F= '$1 == "collection" {print $2}' "$record")"
    status="$(awk -F= '$1 == "status" {print $2}' "$record")"
    payload="$(jq -cn --arg id "$point_id" --arg record "$record_b64" --arg project "$namespace" --arg collection "$collection" --arg status "$status" '{points:[{id:$id,vector:{},payload:{sdlc_record_b64:$record,project_namespace:$project,collection:$collection,status:$status}}]}')"
    response="$(request PUT "$endpoint/collections/$namespace/points?wait=true" "$payload")"
    [[ "$(jq -r '.status // empty' <<<"$response")" == ok ]] || fail 'upsert was not acknowledged'
    ;;
  query)
    collections="${2:-}"
    output="${3:-}"
    [[ -d "$output" && ! -L "$output" ]] || fail 'query output directory required'
    IFS=',' read -r -a requested <<<"$collections"
    collection_json="$(printf '%s\n' "${requested[@]}" | jq -R . | jq -s .)"
    n=0; page=0; offset_json=null
    while true; do
      page=$((page + 1)); (( page <= 100 )) || fail 'provider pagination exceeds 100 pages'
      data="$(jq -cn --arg project "$namespace" --argjson collections "$collection_json" --argjson offset "$offset_json" '{limit:100,with_payload:true,with_vector:false,filter:{must:[{key:"project_namespace",match:{value:$project}},{key:"collection",match:{any:$collections}}]}} + (if $offset == null then {} else {offset:$offset} end)')"
      response="$(request POST "$endpoint/collections/$namespace/points/scroll" "$data")"
      [[ "$(jq -r '.status // empty' <<<"$response")" == ok ]] || fail 'scroll query was not acknowledged'
      mapfile -t records < <(jq -r '.result.points[]?.payload.sdlc_record_b64 // empty' <<<"$response")
      page_count="$(jq -r '.result.points | length' <<<"$response")"
      [[ "$page_count" =~ ^[0-9]+$ && "$page_count" -eq ${#records[@]} ]] || fail 'provider page contains non-canonical points'
      for encoded in "${records[@]}"; do
        n=$((n + 1)); (( n <= 10000 )) || fail 'provider query exceeds 10000 records'
        printf '%s' "$encoded" | base64 -d >"$output/$(printf '%05d' "$n").record" || fail 'invalid provider record encoding'
      done
      offset_json="$(jq -c '.result.next_page_offset // null' <<<"$response")"
      [[ "$offset_json" != null ]] || break
    done
    ;;
  *) fail 'expected doctor, apply or query' ;;
esac
