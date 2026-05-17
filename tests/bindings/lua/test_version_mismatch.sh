#!/usr/bin/env bash
# Rebuild rl.so with a mismatched binding version stamp and expect require("rl") to fail.
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HDR="${ROOT}/bindings/lua/gen/rl_lua_version.h"
RL_SO="${ROOT}/lib/rl.so"
LIBRL_SO="${ROOT}/lib/librl.so"
LIBLUA_INC="${LIBLUA_INC:-${ROOT}/deps/liblua/include}"
LUA="${LUA:-$(command -v lua5.1 2>/dev/null || command -v lua 2>/dev/null || true)}"
CC="${CC:-gcc}"

if [ -z "${LUA}" ]; then
  echo "test_version_mismatch: no lua interpreter found" >&2
  exit 1
fi

if [ ! -f "${HDR}" ]; then
  echo "test_version_mismatch: missing ${HDR} (run make binding-version)" >&2
  exit 1
fi

if [ ! -f "${LIBRL_SO}" ]; then
  make -C "${ROOT}" shared LIBLUA_INC="${LIBLUA_INC}" >/dev/null
fi

backup="$(mktemp)"
restore() {
  cp "${backup}" "${HDR}"
  make -C "${ROOT}" rl_lua LIBLUA_INC="${LIBLUA_INC}" >/dev/null
}
trap restore EXIT

cp "${HDR}" "${backup}"

cat >"${HDR}" <<'EOF'
/* GENERATED — DO NOT EDIT (test override) */
#ifndef RL_LUA_VERSION_H
#define RL_LUA_VERSION_H
#define RL_BINDING_BUILT_MAJOR 9
#define RL_BINDING_BUILT_MINOR 8
#define RL_BINDING_BUILT_PATCH 7
#define RL_BINDING_BUILT_VERSION_STRING "9.8.7"
#endif /* RL_LUA_VERSION_H */
EOF

# Rebuild rl.so only — avoid `make rl_lua` which runs binding-version and overwrites the stamp.
shopt -s nullglob
lua_src=("${ROOT}"/bindings/lua/*.c)
shopt -u nullglob
"${CC}" -shared -fPIC -o "${RL_SO}" \
  "${lua_src[@]}" \
  -I"${ROOT}" -I"${ROOT}/include" \
  -I"${ROOT}/deps/libraylib/include" \
  -I"${ROOT}/deps/wgutils/include" \
  -I"${ROOT}/src" \
  -I"${ROOT}/bindings/lua" \
  -I"${LIBLUA_INC}" \
  -L"${ROOT}/lib" -lrl \
  -Wl,-rpath,'$ORIGIN' \
  -lm -lpthread -ldl

set +e
err_file="$(mktemp)"
LD_LIBRARY_PATH="${ROOT}/lib:${LD_LIBRARY_PATH:-}" \
  "${LUA}" -e "
package.cpath = '${ROOT}/lib/?.so;' .. package.cpath
require('rl')
" 2>"${err_file}"
rc=$?
set -e

if [ "${rc}" -eq 0 ]; then
  echo "test_version_mismatch: expected require('rl') to fail" >&2
  cat "${err_file}" >&2
  exit 1
fi

if ! grep -qiE 'major|mismatch|differs' "${err_file}"; then
  echo "test_version_mismatch: expected version mismatch message" >&2
  cat "${err_file}" >&2
  exit 1
fi

echo "OK: require('rl') failed on major version mismatch as expected"
