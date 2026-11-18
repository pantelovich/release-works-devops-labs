#!/usr/bin/env bash
set -euo pipefail

lab_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
project="release-works-rehearsal-$(date +%s)-$$"
image="$project"
export LAB_PORT="${LAB_PORT:-18080}"
base_url="http://127.0.0.1:$LAB_PORT"

compose() {
  docker compose --project-name "$project" --file "$lab_root/compose.yaml" "$@"
}

cleanup() {
  local status=$?
  if ! compose down --remove-orphans >/dev/null; then
    printf 'Cleanup failed. Run docker compose -p %s -f "%s/compose.yaml" down\n' "$project" "$lab_root" >&2
    status=1
  fi
  docker image rm "$image:v1" "$image:v2" >/dev/null 2>&1 || true
  return "$status"
}

assert_version() {
  curl --fail --silent --show-error --max-time 5 "$base_url/version" |
    python3 -c '
import json
import sys

version = json.load(sys.stdin)["version"]
if version != sys.argv[1]:
    sys.exit(f"Expected {sys.argv[1]}, got {version}")
print(f"Serving {version}")
' "$1"
}

docker info >/dev/null
trap cleanup EXIT

docker build --build-arg RELEASE_VERSION=v1 --tag "$image:v1" "$lab_root"
docker build --build-arg RELEASE_VERSION=v2 --tag "$image:v2" "$lab_root"

printf '\nDeploying baseline v1\n'
LAB_IMAGE="$image:v1" RELEASE_HEALTH=healthy compose up --wait --wait-timeout 35
assert_version v1

printf '\nTrying unhealthy candidate v2\n'
if LAB_IMAGE="$image:v2" RELEASE_HEALTH=unhealthy compose up --wait --wait-timeout 35; then
  printf 'The unhealthy candidate unexpectedly passed health checks.\n' >&2
  exit 1
fi
assert_version v2
status="$(curl --silent --show-error --max-time 5 -o /dev/null -w '%{http_code}' "$base_url/healthz")"
if [[ "$status" != 503 ]]; then
  printf 'Expected HTTP 503 from the running candidate, got %s\n' "$status" >&2
  exit 1
fi
printf 'Candidate is running and returned HTTP 503. Restoring v1.\n'

LAB_IMAGE="$image:v1" RELEASE_HEALTH=healthy compose up --wait --wait-timeout 35
assert_version v1
curl --fail --silent --show-error --max-time 5 "$base_url/healthz"
printf '\nRollback verified. Cleaning up this rehearsal.\n'
