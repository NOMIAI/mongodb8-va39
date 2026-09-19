#!/usr/bin/env bash
set -euo pipefail
readonly commit=8f1f561d203201f9f19e832374813f46cfe0dc29
readonly version=8.0.32
readonly config=src/third_party/tcmalloc/dist/tcmalloc/internal/config.h
test "$(uname -m)" = aarch64
test -f /usr/include/openssl/hmac.h
mkdir -p /out
cd /src/mongo
git config --global --add safe.directory /src/mongo
if ! test -d .git; then
  git init .
  git remote add origin https://github.com/mongodb/mongo.git
fi
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=120 fetch --depth=1 origin refs/tags/r8.0.32
  test "$(git rev-parse 'FETCH_HEAD^{commit}')" = "$commit"
  git checkout --detach "$commit"
fi
test "$(git rev-parse HEAD)" = "$commit"
git fsck --full --no-reflogs
# A restored source tree is accepted only when both patched file hashes match.
if ! printf '%s  %s\n' \
  64a1565a2d22e0ca16e518ef166680124ab639294cc72ec8e38d83e9cb6b69b0 "$config" \
  | sha256sum --check --status; then
  python3 /build-tools/scripts/patch-address-bits.py "$config" 39
fi
python3 /build-tools/scripts/patch-community-headers.py src/BUILD.bazel
printf '%s  %s\n' \
  64a1565a2d22e0ca16e518ef166680124ab639294cc72ec8e38d83e9cb6b69b0 "$config" \
  1d7e3c8058992f8bba3032c99a2c127c0d4191caf82f747352039ee43a09f913 src/BUILD.bazel \
  | sha256sum -c -
git diff --check
git diff --name-only | sort > /out/modified-source-files.txt
printf '%s\n' src/BUILD.bazel "$config" | sort | diff - /out/modified-source-files.txt
git diff -- "$config" > /out/va39.patch
git diff -- src/BUILD.bazel > /out/community-build.patch
sha256sum "$config" src/BUILD.bazel > /out/patched-source-sha256.txt
printf '%s\n' "$commit" > /out/SOURCE_COMMIT
cat > .bazelrc.local <<EOF
common --config=local
common --jobs=2
common:local --jobs=2
common --define=MONGO_VERSION=$version
common --define=GIT_COMMIT_HASH=$commit
startup --host_jvm_args=-Xmx1536m
EOF
cp .bazelrc.local /out/bazelrc-local.txt
python3 buildscripts/install_bazel.py
args=(--host_jvm_args=-Xmx1536m build install-mongod --config=local --config=opt
  --allocator=tcmalloc-google --define=MONGO_VERSION="$version"
  --define=GIT_COMMIT_HASH="$commit" --build_enterprise=False
  --debug_symbols=False --fission=no --jobs=2 --verbose_failures)
{ printf 'bazel'; printf ' %q' "${args[@]}"; printf '\n'; } > /out/build-options.txt
bazel "${args[@]}"
cp -L bazel-bin/install/bin/mongod /out/mongod
test -s /out/mongod
chmod 755 /out/mongod
