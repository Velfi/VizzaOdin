#!/usr/bin/env python3
"""Render one Vizza UI fixture through the production renderer."""

import argparse
import base64
import json
import os
import queue
import subprocess
import threading
import time
from io import BytesIO
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "build" / "vizzaodin"


def enqueue_lines(pipe, target):
    for line in iter(pipe.readline, ""):
        target.put(line)


def rpc(proc, output, method, params=None, timeout=10.0):
    rpc.ident += 1
    message = {"jsonrpc": "2.0", "id": rpc.ident, "method": method}
    if params is not None:
        message["params"] = params
    proc.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
    proc.stdin.flush()
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            payload = json.loads(output.get(timeout=0.1))
        except (queue.Empty, json.JSONDecodeError):
            continue
        if payload.get("id") == rpc.ident:
            return payload
    raise TimeoutError(f"timed out waiting for {method}")


rpc.ident = 0


def tool(proc, output, name, arguments=None):
    response = rpc(proc, output, "tools/call", {"name": name, "arguments": arguments or {}})
    if "error" in response:
        raise RuntimeError(response["error"].get("message", str(response["error"])))
    return response


def result_text(response):
    content = response.get("result", {}).get("content", [])
    return content[0].get("text", "") if content else ""


def capture_environment():
    env = os.environ.copy()
    molten = subprocess.run(["brew", "--prefix", "molten-vk"], capture_output=True, text=True, check=True).stdout.strip()
    loader = subprocess.run(["brew", "--prefix", "vulkan-loader"], capture_output=True, text=True, check=True).stdout.strip()
    env["VK_ICD_FILENAMES"] = str(Path(molten) / "etc/vulkan/icd.d/MoltenVK_icd.json")
    env["DYLD_LIBRARY_PATH"] = f"{molten}/lib:{loader}/lib"
    return env


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("component", choices=["button", "toggle", "slider", "number", "integer", "selector", "text_input"])
    parser.add_argument("--state", default="rest", choices=["rest", "hover", "active", "focused", "editing", "disabled"])
    parser.add_argument("--value", type=float, default=0.58)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--max-width", type=int, default=960)
    parser.add_argument("--full-frame", action="store_true", help="Keep the surrounding renderer canvas")
    args = parser.parse_args()
    output_path = args.output or Path("build/ui-components") / f"{args.component}-{args.state}.png"
    output_path.parent.mkdir(parents=True, exist_ok=True)

    proc = subprocess.Popen(
        [str(APP), "--theme-preview", "--mcp"],
        cwd=ROOT,
        env=capture_environment(),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    output = queue.Queue()
    threading.Thread(target=enqueue_lines, args=(proc.stdout, output), daemon=True).start()
    try:
        rpc(proc, output, "initialize", {})
        tool(proc, output, "render_ui_component", {"component": args.component, "state": args.state, "value": args.value})
        time.sleep(0.35)
        shot = tool(proc, output, "screenshot", {"max_width": args.max_width})
        metadata = json.loads(result_text(shot))
        data_url = metadata.get("data_url", "")
        if not data_url:
            raise RuntimeError("renderer returned no screenshot data")
        image = Image.open(BytesIO(base64.b64decode(data_url.split(",", 1)[1])))
        if not args.full_frame:
            pad_x = int(image.width * 0.18)
            pad_y = int(image.height * 0.34)
            image = image.crop((pad_x, pad_y, image.width - pad_x, image.height - pad_y * 0.72))
        image.save(output_path)
        print(output_path.resolve())
    finally:
        try:
            tool(proc, output, "close_app")
        except Exception:
            proc.terminate()
        proc.wait(timeout=5)


if __name__ == "__main__":
    main()
