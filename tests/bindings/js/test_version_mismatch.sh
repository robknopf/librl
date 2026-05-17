#!/usr/bin/env bash
# Patch binding stamp to 9.8.7 and expect rl.boot() to fail on major mismatch.
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/../../.." && pwd)}"
GEN="${ROOT}/bindings/js/gen/rl_version.js"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="${NODE:-$(command -v node 2>/dev/null || command -v nodejs 2>/dev/null || true)}"

if [ -z "${NODE}" ]; then
  echo "test_version_mismatch: no node interpreter found" >&2
  exit 1
fi

if [ ! -f "${GEN}" ]; then
  echo "test_version_mismatch: missing ${GEN} (run make binding-version)" >&2
  exit 1
fi

if [ ! -f "${ROOT}/lib/librl.js" ]; then
  make -C "${ROOT}" wasm >/dev/null
fi

backup="$(mktemp)"
restore() {
  cp "${backup}" "${GEN}"
}
trap restore EXIT

cp "${GEN}" "${backup}"

cat >"${GEN}" <<'EOF'
/* GENERATED — DO NOT EDIT (test override) */
export const RL_BINDING_BUILT_MAJOR = 9;
export const RL_BINDING_BUILT_MINOR = 8;
export const RL_BINDING_BUILT_PATCH = 7;
export const RL_BINDING_BUILT_VERSION_STRING = "9.8.7";
EOF

set +e
err_file="$(mktemp)"
"${NODE}" "${SCRIPT_DIR}/test_version_mismatch.mjs" 2>"${err_file}"
rc=$?
set -e

# test_version_mismatch.mjs exits 1 on expected failure, 0 if boot succeeded, 2 if wrong message
if [ "${rc}" -eq 0 ]; then
  echo "test_version_mismatch: expected rl.boot() to fail" >&2
  cat "${err_file}" >&2
  exit 1
fi

if [ "${rc}" -eq 2 ]; then
  cat "${err_file}" >&2
  exit 1
fi

if ! grep -qi 'major' "${err_file}"; then
  echo "test_version_mismatch: expected major mismatch message" >&2
  cat "${err_file}" >&2
  exit 1
fi

echo "OK: rl.boot() failed on major version mismatch as expected"
