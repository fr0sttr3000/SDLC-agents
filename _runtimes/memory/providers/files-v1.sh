#!/usr/bin/env bash

set -euo pipefail

fail() { echo "files-v1: $*" >&2; exit 2; }
endpoint="${MEMORY_PROVIDER_ENDPOINT:-}"
namespace="${MEMORY_PROVIDER_NAMESPACE:-}"
[[ -d "$endpoint" && ! -L "$endpoint" ]] || fail 'endpoint must be an existing directory'
[[ "$namespace" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] || fail 'invalid namespace'

value() { awk -F= -v key="$2" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$1"; }

safe_store_dir() {
  local dir="$1" canonical_endpoint canonical
  [[ ! -L "$dir" ]] || fail 'store path contains a symlink'
  mkdir -p "$dir"
  [[ -d "$dir" && ! -L "$dir" ]] || fail 'store directory is invalid'
  canonical_endpoint="$(cd "$endpoint" && pwd -P)"
  canonical="$(cd "$dir" && pwd -P)"
  [[ "$canonical" == "$canonical_endpoint/"* ]] || fail 'store path escapes endpoint'
}

case "${1:-}" in
  doctor)
    [[ -r "$endpoint" && -w "$endpoint" ]] || fail 'endpoint must be readable and writable by the broker'
    echo 'files-v1 ready'
    ;;
  apply)
    record="${2:-}"
    [[ -f "$record" && ! -L "$record" ]] || fail 'record file required'
    collection="$(value "$record" collection)"
    record_id="$(value "$record" record_id)"
    digest="$(value "$record" content_sha256)"
    [[ "$collection" =~ ^(planning|defects|architecture)$ ]] || fail 'invalid collection'
    [[ "$record_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ && "$digest" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid record identity'
    namespace_dir="$endpoint/$namespace"
    collection_dir="$namespace_dir/$collection"
    target_dir="$collection_dir/$record_id"
    safe_store_dir "$namespace_dir"
    safe_store_dir "$collection_dir"
    safe_store_dir "$target_dir"
    target="$target_dir/$digest.record"
    if [[ -f "$target" ]]; then
      cmp -s "$record" "$target" || fail 'record id/digest collision'
      exit 0
    fi
    tmp="$(mktemp "$target_dir/.record.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    cp "$record" "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$target"
    ;;
  query)
    collections="${2:-}"
    output="${3:-}"
    [[ -d "$output" && ! -L "$output" ]] || fail 'query output directory required'
    IFS=',' read -r -a requested <<<"$collections"
    n=0
    for collection in "${requested[@]}"; do
      [[ "$collection" =~ ^(planning|defects|architecture)$ ]] || fail 'invalid collection'
      source="$endpoint/$namespace/$collection"
      [[ -d "$source" ]] || continue
      [[ ! -L "$endpoint/$namespace" && ! -L "$source" ]] || fail 'store query path contains a symlink'
      [[ "$(cd "$source" && pwd -P)" == "$(cd "$endpoint" && pwd -P)/"* ]] || fail 'store query path escapes endpoint'
      while IFS= read -r record; do
        n=$((n + 1))
        (( n <= 10000 )) || fail 'provider query exceeds 10000 records'
        cp "$record" "$output/$(printf '%04d' "$n")-$(basename "$record")"
      done < <(find "$source" -type f -name '*.record' -print | sort)
    done
    ;;
  *) fail 'expected doctor, apply or query' ;;
esac
