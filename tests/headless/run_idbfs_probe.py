#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import websocket


REPO_ROOT = Path(__file__).resolve().parents[2]
PROBE_URL_PATH = "/tests/headless/idbfs_probe_fileio.html"


def pick_free_port() -> int:
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    sock.close()
    return port


def cdp_send(ws, msg_id, method, params=None):
    msg_id += 1
    payload = {"id": msg_id, "method": method}
    if params is not None:
        payload["params"] = params
    ws.send(json.dumps(payload))

    while True:
        response = json.loads(ws.recv())
        if response.get("id") == msg_id:
            return msg_id, response


def main() -> int:
    chrome_bin = os.environ.get("CHROME_BIN")
    if not chrome_bin:
        print("Missing CHROME_BIN", file=sys.stderr)
        return 2

    http_port = pick_free_port()
    cdp_port = pick_free_port()

    server = subprocess.Popen(
        [sys.executable, "-m", "http.server", str(http_port)],
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    user_data_dir = Path(f"/tmp/librl_chrome_profile_{os.getpid()}_{int(time.time())}")
    chrome = subprocess.Popen(
        [
            chrome_bin,
            "--headless",
            "--no-sandbox",
            "--disable-gpu",
            "--remote-allow-origins=*",
            f"--remote-debugging-port={cdp_port}",
            f"--user-data-dir={user_data_dir}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    try:
        deadline = time.time() + 10
        targets = None
        while time.time() < deadline:
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{cdp_port}/json/list", timeout=1.0) as resp:
                    targets = json.loads(resp.read().decode("utf-8"))
                if targets:
                    break
            except Exception:
                time.sleep(0.2)

        if not targets:
            print("Failed to connect to Chrome DevTools", file=sys.stderr)
            return 2

        page = next((t for t in targets if t.get("type") == "page" and t.get("webSocketDebuggerUrl")), None)
        if page is None:
            print("No debuggable page target found", file=sys.stderr)
            return 2

        ws = websocket.create_connection(
            page["webSocketDebuggerUrl"],
            timeout=30,
            origin=f"http://127.0.0.1:{cdp_port}",
        )

        msg_id = 0
        msg_id, _ = cdp_send(ws, msg_id, "Runtime.enable")
        msg_id, _ = cdp_send(ws, msg_id, "Page.enable")
        msg_id, _ = cdp_send(
            ws,
            msg_id,
            "Page.navigate",
            {"url": f"http://127.0.0.1:{http_port}{PROBE_URL_PATH}"},
        )

        result_payload = None
        deadline = time.time() + 60
        while time.time() < deadline:
            msg_id, response = cdp_send(
                ws,
                msg_id,
                "Runtime.evaluate",
                {
                    "expression": "(() => { const el = document.getElementById('out'); return { text: el ? el.textContent : null }; })()",
                    "returnByValue": True,
                },
            )
            value = response.get("result", {}).get("result", {}).get("value", {})
            text = (value.get("text") or "").strip()
            if text.startswith("{") and text.endswith("}"):
                try:
                    parsed = json.loads(text)
                    result_payload = parsed
                    if parsed.get("step") == "done" or parsed.get("errors"):
                        break
                except json.JSONDecodeError:
                    pass
            time.sleep(0.25)

        ws.close()

        if result_payload is None:
            print("Timed out waiting for probe payload", file=sys.stderr)
            return 1

        print(json.dumps(result_payload, indent=2))

        if result_payload.get("errors"):
            return 1
        if result_payload.get("readyBeforeInit"):
            return 1
        if not result_payload.get("readyAfterInit"):
            return 1
        if not result_payload.get("readyAfterDeinit"):
            return 1
        if not result_payload.get("initOk"):
            return 1
        if not result_payload.get("writeOk"):
            return 1
        if not result_payload.get("existsAfterWrite"):
            return 1
        if not result_payload.get("secondInitOk"):
            return 1
        if not result_payload.get("existsAfterRestore"):
            return 1

        idb_scan = result_payload.get("idbScan") or {}
        if not idb_scan.get("hit"):
            return 1

        return 0
    finally:
        for proc in (chrome, server):
            proc.terminate()
        for proc in (chrome, server):
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()


if __name__ == "__main__":
    sys.exit(main())
