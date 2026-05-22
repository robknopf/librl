#!/usr/bin/env bash
# Print the path to a Node.js binary with JSPI (WebAssembly.Suspending).
# Used by wasm test Makefiles when NODE is not set explicitly.

set -euo pipefail

has_jspi() {
	"$1" -e 'process.exit(typeof WebAssembly.Suspending === "function" ? 0 : 1)' 2>/dev/null
}

try_node() {
	local candidate="$1"
	if [ -x "$candidate" ] && has_jspi "$candidate"; then
		printf '%s\n' "$candidate"
		exit 0
	fi
}

if candidate="$(command -v node 2>/dev/null)" && [ -n "$candidate" ]; then
	try_node "$candidate"
fi

nvm_root=""
if [ -n "${NVM_DIR:-}" ] && [ -d "${NVM_DIR}/versions/node" ]; then
	nvm_root="${NVM_DIR}/versions/node"
elif [ -d "${HOME}/.nvm/versions/node" ]; then
	nvm_root="${HOME}/.nvm/versions/node"
fi

if [ -n "$nvm_root" ]; then
	while IFS= read -r ver_dir; do
		try_node "${nvm_root}/${ver_dir}/bin/node"
	done < <(ls -1 "$nvm_root" 2>/dev/null | sort -V -r)
fi

exit 1
