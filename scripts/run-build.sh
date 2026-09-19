#!/usr/bin/env bash
set -euo pipefail
test "$(uname -m)" = aarch64
test "$(df --output=avail -B1 . | tail -1)" -ge 4294967296
mkdir -p .ci-work/source .ci-work/home out
remaining=$(( BUILD_DEADLINE - $(date +%s) ))
test "$remaining" -ge 1800
date -u +%FT%TZ > out/started-at.txt
# No host Docker socket, credentials, NAS volumes, or deployment secrets are mounted.
set +e
timeout --signal=TERM --kill-after=60s "${remaining}s" \
  docker run --name mongo-va39-native --platform linux/arm64 \
  --memory=12g --memory-swap=12g \
  --mount "type=bind,src=$PWD/.ci-work/source,dst=/src/mongo" \
  --mount "type=bind,src=$PWD/.ci-work/home,dst=/root" \
  --mount "type=bind,src=$PWD,dst=/build-tools,readonly" \
  --mount "type=bind,src=$PWD/out,dst=/out" \
  mongo-va39-builder 2>&1 | tee out/build.log
pipeline_status=("${PIPESTATUS[@]}")
result=${pipeline_status[0]}
if test "${pipeline_status[1]}" -ne 0; then
  result=${pipeline_status[1]}
fi
set -e
printf '%s\n' "$result" > out/exit-code.txt
date -u +%FT%TZ > out/finished-at.txt
if docker container inspect mongo-va39-native >/dev/null 2>&1; then
  docker stop -t 30 mongo-va39-native >/dev/null
  docker inspect --format '{{json .State}}' mongo-va39-native > out/container-state.json
fi
if test "$result" -eq 124 || test "$result" -eq 137; then
  echo 'Build deadline or resource failure. Preserve evidence; do not automatically retry.' >&2
fi
exit "$result"
