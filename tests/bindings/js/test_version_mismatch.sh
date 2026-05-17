#!/usr/bin/env bash
# Tests _compareVersion() return codes via boot():
#   -1 (major mismatch)  → boot() throws
#   -2 (minor mismatch)  → boot() throws
#    1 (patch drift)     → boot() succeeds (valid, noted)
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

write_gen() {
  local major="$1" minor="$2" patch="$3"
  cat >"${GEN}" <<EOF
/* GENERATED — DO NOT EDIT (test override) */
export const RL_BINDING_BUILT_MAJOR = ${major};
export const RL_BINDING_BUILT_MINOR = ${minor};
export const RL_BINDING_BUILT_PATCH = ${patch};
export const RL_BINDING_BUILT_VERSION_STRING = "${major}.${minor}.${patch}";
EOF
}

expect_throw() {
  local label="$1"
  local err_file
  err_file="$(mktemp)"
  set +e
  "${NODE}" "${SCRIPT_DIR}/test_version_mismatch.mjs" 2>"${err_file}"
  rc=$?
  set -e

  if [ "${rc}" -eq 0 ]; then
    echo "FAIL ${label}: expected boot() to throw" >&2
    cat "${err_file}" >&2
    exit 1
  fi
  if [ "${rc}" -eq 2 ]; then
    echo "FAIL ${label}: wrong error message" >&2
    cat "${err_file}" >&2
    exit 1
  fi
  echo "OK: ${label} — boot() threw as expected"
}

expect_success() {
  local label="$1"
  local librl_js="${ROOT}/lib/librl.js"
  set +e
  "${NODE}" --input-type=module 2>/dev/null <<EOJS
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const { rl: RL } = await import('file://${ROOT}/bindings/js/rl.js?drift=' + Date.now());
await RL.boot({ modulePath: '${librl_js}', env: { locateFile: p => path.join('${ROOT}/lib', p) } });
process.exit(0);
EOJS
  rc=$?
  set -e
  if [ "${rc}" -ne 0 ]; then
    echo "FAIL ${label}: expected boot() to succeed on patch drift" >&2
    exit 1
  fi
  echo "OK: ${label} — boot() succeeded (patch drift is non-fatal)"
}

# -1: major mismatch → throws
write_gen 9 0 1
expect_throw "major mismatch (9.0.1 vs runtime)"

# -2: minor mismatch → throws
write_gen 0 9 1
expect_throw "minor mismatch (0.9.1 vs runtime)"

# +1: patch drift → boot succeeds
write_gen 0 0 9
expect_success "patch drift (0.0.9 vs runtime)"
