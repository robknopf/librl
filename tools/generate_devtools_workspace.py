#!/usr/bin/env python3

import json
import os
import uuid
from pathlib import Path


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    target = repo_root / "examples" / "www" / "public" / ".well-known" / "appspecific" / "com.chrome.devtools.json"

    existing_uuid = None
    if target.exists():
        try:
            parsed = json.loads(target.read_text(encoding="utf-8"))
            existing_uuid = parsed.get("workspace", {}).get("uuid")
        except (json.JSONDecodeError, OSError):
            existing_uuid = None

    payload = {
        "workspace": {
            "root": os.fspath(repo_root) + os.sep,
            "uuid": existing_uuid if isinstance(existing_uuid, str) else str(uuid.uuid4()),
        }
    }

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload), encoding="utf-8")
    print(f"Wrote {target}")


if __name__ == "__main__":
    main()
