#!/usr/bin/env python3
import json
import os
import queue
import random
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "build" / "vizzaodin"
DEFAULT_OUT = Path("/Users/zelda/Documents/vizza-dot-page/public/assets/screenshots")
OUT = Path(os.environ.get("VIZZA_REMAINING_CAPTURE_DIR", DEFAULT_OUT))
COUNT = int(os.environ.get("VIZZA_REMAINING_CAPTURE_COUNT", "10"))
WIDTH = int(os.environ.get("VIZZA_REMAINING_CAPTURE_WIDTH", "6000"))
HEIGHT = int(os.environ.get("VIZZA_REMAINING_CAPTURE_HEIGHT", "4000"))
SEED = int(os.environ.get("VIZZA_REMAINING_CAPTURE_SEED", str(int(time.time()))))
MODE_FILTER = {
    item.strip()
    for item in os.environ.get("VIZZA_REMAINING_CAPTURE_MODES", "").split(",")
    if item.strip()
}
FRESH_EACH_CAPTURE = os.environ.get("VIZZA_REMAINING_FRESH_EACH_CAPTURE", "0") in {"1", "true", "yes"}

ALL_MODES = [
    ("Pellets", "pellets-random-10-clean", "pellets-random", "configure_pellets", 4.5),
    ("Voronoi_CA", "voronoi-ca-random-10-clean", "voronoi-ca-random", "configure_voronoi_ca", 4.0),
    ("Moire", "moire-random-10-clean", "moire-random", "configure_moire", 4.0),
    ("Vectors", "vectors-random-10-clean", "vectors-random", "configure_vectors", 3.0),
    ("Primordial", "primordial-random-10-clean", "primordial-random", "configure_primordial", 5.0),
]
MODES = [entry for entry in ALL_MODES if not MODE_FILTER or entry[0] in MODE_FILTER or entry[1] in MODE_FILTER]

COLOR_SCHEMES = [
    "MATPLOTLIB_turbo",
    "MATPLOTLIB_plasma",
    "MATPLOTLIB_inferno",
    "MATPLOTLIB_viridis",
    "MATPLOTLIB_magma",
    "MATPLOTLIB_cubehelix",
    "MATPLOTLIB_twilight",
    "ZELDA_Fordite",
    "ZELDA_Jawbreaker",
    "ZELDA_Particles1",
    "ZELDA_Aqua",
    "KTZ_Noice_Blue",
    "KTZ_Noice_Red",
    "KTZ_bw_Ember",
    "KTZ_bw_Lagoon",
    "KTZ_bw_Nebula",
]


def enqueue_lines(pipe, target):
    for line in iter(pipe.readline, ""):
        target.put(line)
    pipe.close()


def call(proc, outq, method, params=None, timeout=12.0):
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


def tool(proc, outq, name, arguments=None, timeout=12.0):
    return call(proc, outq, "tools/call", {"name": name, "arguments": arguments or {}}, timeout=timeout)


def tool_text(response):
    result = response.get("result", {})
    content = result.get("content", [])
    if not content:
        return ""
    return content[0].get("text", "")


def base_config(rng, mode):
    return {
        "mode": mode,
        "color_scheme": rng.choice(COLOR_SCHEMES),
        "reversed": rng.random() < 0.5,
        "reset": True,
        "hide_ui": True,
        "set_mode": True,
    }


def config_for(rng, mode):
    cfg = base_config(rng, mode)
    if mode == "Gray_Scott":
        presets = [
            (0.037, 0.060, 1.0, 0.5),
            (0.022, 0.051, 1.0, 0.5),
            (0.030, 0.055, 1.0, 0.5),
            (0.046, 0.063, 1.0, 0.5),
            (0.026, 0.057, 1.0, 0.5),
        ]
        feed, kill, da, db = rng.choice(presets)
        cfg.update(
            {
                "feed": round(feed + rng.uniform(-0.004, 0.004), 5),
                "kill": round(kill + rng.uniform(-0.004, 0.004), 5),
                "diffusion_a": da,
                "diffusion_b": db,
                "timestep": round(rng.uniform(0.8, 1.35), 3),
                "simulation_speed": round(rng.uniform(0.9, 1.8), 3),
                "seed_noise": True,
                "mask_pattern": rng.choice(["Disabled", "Checkerboard", "Radial Gradient", "Cosine Grid"]),
                "mask_strength": round(rng.uniform(0.0, 0.45), 3),
            }
        )
    elif mode == "Pellets":
        cfg.update(
            {
                "particle_count": rng.randrange(7000, 22001),
                "particle_size": round(rng.uniform(0.006, 0.024), 4),
                "random_seed": rng.randrange(1, 2**31 - 1),
                "gravitational_constant": 10 ** rng.uniform(-8.2, -6.1),
                "energy_damping": round(rng.uniform(0.88, 1.0), 4),
                "gravity_softening": round(rng.uniform(0.0015, 0.008), 4),
                "density_radius": round(rng.uniform(0.018, 0.07), 4),
                "trails_enabled": rng.random() < 0.65,
                "trail_fade": round(rng.uniform(0.32, 0.82), 3),
                "foreground_color_mode": rng.choice(["Density", "Velocity", "Random"]),
                "background_color_mode": "Color Scheme",
            }
        )
    elif mode == "Voronoi_CA":
        cfg.update(
            {
                "point_count": rng.randrange(160, 950),
                "time_scale": round(rng.uniform(0.25, 2.8), 3),
                "drift": round(rng.uniform(0.2, 4.0), 3),
                "brownian_speed": round(rng.uniform(1.0, 26.0), 3),
                "random_seed": rng.randrange(1, 2**31 - 1),
                "borders_enabled": rng.random() < 0.45,
                "border_width": round(rng.uniform(0.5, 3.5), 2),
                "color_mode": rng.choice(["Region", "Velocity", "Random"]),
            }
        )
    elif mode == "Moire":
        cfg.update(
            {
                "generator_type": rng.choice(["Linear", "Radial", "Spiral"]),
                "speed": round(rng.uniform(0.02, 0.45), 3),
                "base_freq": round(rng.uniform(9.0, 54.0), 3),
                "moire_amount": round(rng.uniform(0.22, 0.95), 3),
                "moire_rotation": round(rng.uniform(-0.55, 0.55), 3),
                "moire_scale": round(rng.uniform(0.96, 1.14), 3),
                "moire_interference": round(rng.uniform(0.25, 0.9), 3),
                "moire_rotation3": round(rng.uniform(-0.4, 0.4), 3),
                "moire_scale3": round(rng.uniform(0.92, 1.18), 3),
                "moire_weight3": round(rng.uniform(0.0, 0.65), 3),
                "radial_swirl_strength": round(rng.uniform(0.0, 1.3), 3),
                "radial_starburst_count": round(rng.uniform(6.0, 34.0), 2),
                "advect_strength": round(rng.uniform(0.0, 0.85), 3),
                "advect_speed": round(rng.uniform(0.2, 2.6), 3),
                "curl": round(rng.uniform(0.1, 1.6), 3),
                "decay": round(rng.uniform(0.94, 0.995), 4),
            }
        )
    elif mode == "Vectors":
        cfg.update(
            {
                "vector_field_type": "Noise",
                "noise_kind": rng.choice(["Simplex", "Perlin", "Value", "Voronoi", "Wave", "Billow", "Ridged"]),
                "fractal_mode": rng.choice(["Single", "FBM", "Ridged"]),
                "warp_mode": rng.choice(["None", "Fixed", "Recursive"]),
                "seed": rng.randrange(1, 2**31 - 1),
                "frequency": round(rng.uniform(1.0, 14.0), 3),
                "noise_strength": round(rng.uniform(0.75, 1.35), 3),
                "warp_amplitude": round(rng.uniform(0.0, 0.5), 3),
                "warp_frequency": round(rng.uniform(0.5, 4.0), 3),
                "density": round(rng.uniform(0.012, 0.055), 4),
                "line_length": round(rng.uniform(0.018, 0.09), 4),
                "line_width": round(rng.uniform(0.0007, 0.004), 5),
                "background_color_mode": "Color Scheme",
            }
        )
    elif mode == "Primordial":
        cfg.update(
            {
                "particle_count": rng.randrange(8000, 26001),
                "random_seed": rng.randrange(1, 2**31 - 1),
                "position_generator": rng.choice(["Random", "Circle", "Ring", "Center"]),
                "alpha": round(rng.uniform(40.0, 260.0), 3),
                "beta": round(rng.uniform(-0.8, 0.8), 3),
                "velocity": round(rng.uniform(0.05, 0.65), 3),
                "radius": round(rng.uniform(0.035, 0.18), 4),
                "dt": round(rng.uniform(0.006, 0.024), 4),
                "particle_size": round(rng.uniform(0.004, 0.022), 4),
                "density_radius": round(rng.uniform(0.018, 0.08), 4),
                "traces_enabled": rng.random() < 0.7,
                "trace_fade": round(rng.uniform(0.2, 0.72), 3),
                "wrap_edges": True,
                "foreground_color_mode": rng.choice(["Heading", "Density", "Velocity"]),
                "background_color_mode": "Color Scheme",
            }
        )
    return cfg


def qoi_to_webp(qoi_path, webp_path):
    with Image.open(qoi_path) as image:
        image.save(webp_path, "WEBP", quality=88, method=6)
        return image.size


def capture_env():
    env = os.environ.copy()
    env.setdefault("VK_ICD_FILENAMES", "/opt/homebrew/opt/molten-vk/etc/vulkan/icd.d/MoltenVK_icd.json")
    molten = "/opt/homebrew/opt/molten-vk/lib"
    loader = "/opt/homebrew/opt/vulkan-loader/lib"
    env["DYLD_LIBRARY_PATH"] = f"{molten}:{loader}:{env.get('DYLD_LIBRARY_PATH', '')}".rstrip(":")
    return env


def start_app(env):
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
    call(proc, outq, "initialize", {}, timeout=12.0)
    time.sleep(1.0)
    tool(proc, outq, "hide_ui", {}, timeout=6.0)
    return proc, outq, errq


def stop_app(proc, outq):
    if proc.poll() is None:
        try:
            tool(proc, outq, "close_app", {}, timeout=2.0)
        except Exception:
            pass
        try:
            proc.wait(timeout=3.0)
        except subprocess.TimeoutExpired:
            proc.terminate()


def drain_errors(errq):
    stderr = []
    while not errq.empty():
        stderr.append(errq.get())
    return stderr


def capture_one(proc, outq, rng, temp_dir, mode, stem_name, tool_name, warmup, webp_dir, index):
    config = config_for(rng, mode)
    config_text = tool_text(tool(proc, outq, tool_name, config, timeout=8.0))
    time.sleep(warmup)
    stem = f"{index:02d}-{stem_name}"
    qoi_path = temp_dir / f"{stem}.qoi"
    webp_path = webp_dir / f"{stem}.webp"
    shot_text = tool_text(
        tool(
            proc,
            outq,
            "screenshot",
            {"output_path": str(qoi_path), "output_width": WIDTH, "output_height": HEIGHT},
            timeout=20.0,
        )
    )
    size = qoi_to_webp(qoi_path, webp_path)
    return {
        "mode": mode,
        "index": index,
        "webp": str(webp_path),
        "size": list(size),
        "mcp": json.loads(config_text),
        "screenshot": json.loads(shot_text),
        "config": config,
    }


def main():
    rng = random.Random(SEED)
    temp_dir = Path(tempfile.mkdtemp(prefix="vizza-remaining-random-qoi-"))
    metadata = {
        "seed": SEED,
        "count": COUNT,
        "modes": [mode for mode, *_ in MODES],
        "fresh_each_capture": FRESH_EACH_CAPTURE,
        "results": [],
    }
    env = capture_env()
    all_stderr = []
    proc = None
    outq = None
    try:
        if not FRESH_EACH_CAPTURE:
            proc, outq, errq = start_app(env)
        for mode, folder, stem_name, tool_name, warmup in MODES:
            webp_dir = OUT / folder / "webp"
            webp_dir.mkdir(parents=True, exist_ok=True)
            for existing in webp_dir.glob("*.webp"):
                existing.unlink()
            for index in range(COUNT):
                if FRESH_EACH_CAPTURE:
                    proc, outq, errq = start_app(env)
                item = capture_one(proc, outq, rng, temp_dir, mode, stem_name, tool_name, warmup, webp_dir, index)
                metadata["results"].append(item)
                print(json.dumps(item, separators=(",", ":")), flush=True)
                if FRESH_EACH_CAPTURE:
                    stop_app(proc, outq)
                    all_stderr.extend(drain_errors(errq))
                    proc = None
                    outq = None
    finally:
        if proc is not None:
            stop_app(proc, outq)
            all_stderr.extend(drain_errors(errq))
        meta_path = Path("/private/tmp/vizza-remaining-random-summary.json")
        meta_path.write_text(json.dumps(metadata, indent=2) + "\n")
        if all_stderr:
            Path("/private/tmp/vizza-remaining-random-stderr.log").write_text("".join(all_stderr))
        shutil.rmtree(temp_dir, ignore_errors=True)
        print(json.dumps({"summary": str(meta_path), "temp_cleaned": str(temp_dir)}, separators=(",", ":")), flush=True)


if __name__ == "__main__":
    sys.exit(main())
