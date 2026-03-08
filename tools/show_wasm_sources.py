import json
import argparse
import subprocess
from pathlib import Path

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Show wasm source map source entries.")
    parser.add_argument(
        "--wasm",
        default="../examples/c/out/main.debug.smap.wasm",
        help="Path to wasm file, relative to this script directory unless absolute.",
    )
    parser.add_argument(
        "--filter",
        dest="pattern",
        default=None,
        help="Only print source entries containing this substring.",
    )
    parser.add_argument(
        "--short",
        action="store_true",
        help="Print only a summary count (and count after --filter).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    wasm_source = Path(args.wasm)
    if not wasm_source.is_absolute():
        wasm_source = script_dir / wasm_source
    wasm_sourcemap = Path(str(wasm_source) + ".map")

    with open(wasm_sourcemap, "r", encoding="utf-8") as f:
        d = json.load(f)

    sources = d.get("sources", [])
    filtered = sources
    if args.pattern:
        filtered = [s for s in sources if args.pattern in s]

    if args.short:
        print(f">> Total source entries: {len(sources)}")
        if args.pattern:
            print(f">> Matched '{args.pattern}': {len(filtered)}")
    else:
        print(">> Listing source entries...")
        for s in filtered:
            print(s)

    print()
    print(">> Checking for source-map path mapping...")
    subprocess.run(
        f"wasm-objdump -h {wasm_source} | rg sourceMappingURL",
        shell=True,
        check=False,
    )
    print()


if __name__ == "__main__":
    main()
