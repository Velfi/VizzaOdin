#!/usr/bin/env python3
import json
import os
import queue
import random
import subprocess
import sys
import threading
import time
from io import BytesIO
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "build" / "vizzaodin"
DEFAULT_OUT = Path("/Users/zelda/Documents/vizza-dot-page/public/assets/screenshots/flow-field-random-noise-50-clean")
OUT = Path(os.environ.get("VIZZA_FLOW_CAPTURE_DIR", DEFAULT_OUT))
COUNT = int(os.environ.get("VIZZA_FLOW_CAPTURE_COUNT", "50"))
WARMUP_SECONDS = float(os.environ.get("VIZZA_FLOW_WARMUP_SECONDS", "4.5"))
WIDTH = int(os.environ.get("VIZZA_FLOW_CAPTURE_WIDTH", "6000"))
HEIGHT = int(os.environ.get("VIZZA_FLOW_CAPTURE_HEIGHT", "4000"))
SEED = int(os.environ.get("VIZZA_FLOW_CAPTURE_SEED", str(int(time.time()))))

NOISE_KINDS = [
    "Billow",
    "Gabor",
    "Perlin",
    "Phasor",
    "Ridged",
    "Simplex",
    "Value",
    "Voronoi",
    "Wave",
    "Cylinders",
]
FRACTAL_MODES = ["Single", "FBM", "Ridged"]
WARP_MODES = ["None", "Fixed", "Recursive"]
FOREGROUND_MODES = ["Age", "Random", "Direction"]
COLOR_SCHEMES = [
    "MATPLOTLIB_turbo",
    "MATPLOTLIB_plasma",
    "MATPLOTLIB_inferno",
    "MATPLOTLIB_viridis",
    "MATPLOTLIB_cubehelix",
    "ZELDA_Fordite",
    "ZELDA_Jawbreaker",
    "ZELDA_Particles1",
    "KTZ_Noice_Blue",
    "KTZ_Noice_Red",
    "KTZ_bw_Ember",
    "KTZ_bw_Lagoon",
]


def enqueue_lines(pipe, target):
    for line in iter(pipe.readline, ""):
        target.put(line)
    pipe.close()


def call(proc, outq, method, params=None, timeout=10.0):
    call.next_id += 1
    ident = call.next_id
    message = {"jsonrpc": "2.0", "id": ident, "method": method}
    if params is not None:
        message["params"] = params
    proc.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
    proc.stdin.flush()
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            line = outq.get(timeout=0.1)
        except queue.Empty:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if payload.get("id") == ident:
            return payload
    raise TimeoutError(f"timed out waiting for {method} id={ident}")


call.next_id = 0


def tool(proc, outq, name, arguments=None, timeout=10.0):
    return call(proc, outq, "tools/call", {"name": name, "arguments": arguments or {}}, timeout=timeout)


def tool_text(response):
    result = response.get("result", {})
    content = result.get("content", [])
    if not content:
        return ""
    return content[0].get("text", "")


def random_config(rng):
    noise_kind = rng.choice(NOISE_KINDS)
    fractal_mode = rng.choice(FRACTAL_MODES)
    warp_mode = rng.choice(WARP_MODES)
    if noise_kind in {"Gabor", "Phasor", "Wave", "Cylinders"}:
        fractal_mode = "Single"
    return {
        "noise_kind": noise_kind,
        "fractal_mode": fractal_mode,
        "warp_mode": warp_mode,
        "seed": rng.randrange(1, 2**31 - 1),
        "frequency": round(rng.uniform(1.2, 13.5), 3),
        "amplitude": round(rng.uniform(0.75, 1.4), 3),
        "noise_strength": round(rng.uniform(0.65, 1.35), 3),
        "warp_amplitude": round(rng.uniform(0.05, 0.55), 3),
        "warp_frequency": round(rng.uniform(0.55, 4.5), 3),
        "vector_magnitude": round(rng.uniform(0.055, 0.24), 3),
        "particle_count": rng.randrange(90000, 180001),
        "particle_lifetime": round(rng.uniform(3.5, 10.5), 2),
        "particle_speed": round(rng.uniform(0.45, 2.15), 3),
        "particle_size": rng.randrange(2, 7),
        "autospawn_rate": rng.randrange(1200, 6001),
        "show_particles": rng.random() < 0.85,
        "trail_decay_rate": round(rng.uniform(0.0, 0.06), 4),
        "trail_deposition_rate": round(rng.uniform(0.65, 1.45), 3),
        "trail_diffusion_rate": round(rng.uniform(0.0, 0.08), 4),
        "trail_wash_out_rate": round(rng.uniform(0.015, 0.18), 4),
        "foreground_color_mode": rng.choice(FOREGROUND_MODES),
        "background_color_mode": "Color Scheme",
        "color_scheme": rng.choice(COLOR_SCHEMES),
        "reversed": rng.random() < 0.5,
        "reset": True,
        "hide_ui": True,
        "set_mode": True,
    }


def qoi_to_webp(qoi_path, webp_path):
    with Image.open(qoi_path) as image:
        image.save(webp_path, "WEBP", quality=88, method=6)
        return image.size


def main():
    rng = random.Random(SEED)
    qoi_dir = OUT / "qoi"
    webp_dir = OUT / "webp"
    qoi_dir.mkdir(parents=True, exist_ok=True)
    webp_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env.setdefault("VK_ICD_FILENAMES", "/opt/homebrew/opt/molten-vk/etc/vulkan/icd.d/MoltenVK_icd.json")
    molten = "/opt/homebrew/opt/molten-vk/lib"
    loader = "/opt/homebrew/opt/vulkan-loader/lib"
    env["DYLD_LIBRARY_PATH"] = f"{molten}:{loader}:{env.get('DYLD_LIBRARY_PATH', '')}".rstrip(":")

    proc = subprocess.Popen(
        [str(APP), "--mcp"],
        cwd=str(ROOT),
        env=env,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    outq = queue.Queue()
    errq = queue.Queue()
    threading.Thread(target=enqueue_lines, args=(proc.stdout, outq), daemon=True).start()
    threading.Thread(target=enqueue_lines, args=(proc.stderr, errq), daemon=True).start()

    results = []
    try:
        call(proc, outq, "initialize", {}, timeout=12.0)
        time.sleep(1.0)
        tool(proc, outq, "hide_ui", {}, timeout=6.0)

        for index in range(COUNT):
            config = random_config(rng)
            text = tool_text(tool(proc, outq, "configure_flow_field", config, timeout=8.0))
            time.sleep(WARMUP_SECONDS)
            stem = f"{index:02d}-flow-field-random-noise"
            qoi_path = qoi_dir / f"{stem}.qoi"
            webp_path = webp_dir / f"{stem}.webp"
            screenshot_text = tool_text(
                tool(
                    proc,
                    outq,
                    "screenshot",
                    {"output_path": str(qoi_path), "output_width": WIDTH, "output_height": HEIGHT},
                    timeout=20.0,
                )
            )
            screenshot = json.loads(screenshot_text)
            size = qoi_to_webp(qoi_path, webp_path)
            results.append(
                {
                    "index": index,
                    "webp": str(webp_path),
                    "qoi": str(qoi_path),
                    "size": list(size),
                    "mcp": json.loads(text),
                    "screenshot": screenshot,
                    "config": config,
                }
            )
            print(json.dumps(results[-1], separators=(",", ":")), flush=True)

        (OUT / "summary.json").write_text(json.dumps({"seed": SEED, "count": COUNT, "results": results}, indent=2) + "\n")
    finally:
        if proc.poll() is None:
            try:
                tool(proc, outq, "close_app", {}, timeout=2.0)
            except Exception:
                pass
            try:
                proc.wait(timeout=3.0)
            except subprocess.TimeoutExpired:
                proc.terminate()
        stderr = []
        while not errq.empty():
            stderr.append(errq.get())
        if stderr:
            (OUT / "stderr.log").write_text("".join(stderr))


if __name__ == "__main__":
    sys.exit(main())
