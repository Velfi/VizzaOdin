#!/usr/bin/env python3
import base64
import json
import os
import queue
import math
import subprocess
import sys
import threading
import time
from io import BytesIO
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "build" / "vizzaodin"
OUT = Path(os.environ.get("VIZZA_CAPTURE_DIR", "/tmp/vizzaodin-remaining-captures"))
CAPTURE_PELLETS_TRAILS = os.environ.get("VIZZA_CAPTURE_PELLETS_TRAILS") == "1"
CAPTURE_PRIMORDIAL_TRACES = os.environ.get("VIZZA_CAPTURE_PRIMORDIAL_TRACES") == "1"
CAPTURE_VECTORS_IMAGE = os.environ.get("VIZZA_CAPTURE_VECTORS_IMAGE") == "1"
CAPTURE_MOIRE_IMAGE = os.environ.get("VIZZA_CAPTURE_MOIRE_IMAGE") == "1"
CAPTURE_FLOW_IMAGE = os.environ.get("VIZZA_CAPTURE_FLOW_IMAGE") == "1"
CAPTURE_SLIME_IMAGES = os.environ.get("VIZZA_CAPTURE_SLIME_IMAGES") == "1"


SIM_CLICKS = [
    ("slime_mold", 1428, 792),
    ("flow_field", 1990, 914),
    ("pellets", 1428, 1037),
    ("voronoi_ca", 1428, 1158),
    ("moire", 1990, 1158),
    ("vectors", 1428, 1280),
    ("primordial", 1990, 1280),
]

SIM_MODES = {
    "slime_mold": "Slime_Mold",
    "flow_field": "Flow_Field",
    "pellets": "Pellets",
    "voronoi_ca": "Voronoi_CA",
    "moire": "Moire",
    "vectors": "Vectors",
    "primordial": "Primordial",
}


def enqueue_lines(pipe, target):
    for line in iter(pipe.readline, ""):
        target.put(line)
    pipe.close()


def call(proc, outq, method, params=None, timeout=6.0):
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


def tool(proc, outq, name, arguments=None, timeout=6.0):
    return call(
        proc,
        outq,
        "tools/call",
        {"name": name, "arguments": arguments or {}},
        timeout=timeout,
    )


def click(proc, outq, x, y, button=1):
    tool(proc, outq, "click", {"x": x, "y": y})
    time.sleep(0.12)


def tool_text(response):
    result = response.get("result", {})
    content = result.get("content", [])
    if not content:
        return ""
    return content[0].get("text", "")


def status(proc, outq):
    text = tool_text(tool(proc, outq, "app_status"))
    return json.loads(text)


def raw_point(status_payload, pixel_x, pixel_y):
    width = max(float(status_payload.get("window_width", 1)), 1.0)
    height = max(float(status_payload.get("window_height", 1)), 1.0)
    logical_width = float(status_payload.get("logical_window_width", width))
    logical_height = float(status_payload.get("logical_window_height", height))
    return pixel_x * logical_width / width, pixel_y * logical_height / height


def save_screenshot(proc, outq, stem):
    text = tool_text(tool(proc, outq, "screenshot", {"max_width": 640}, timeout=10.0))
    payload = json.loads(text)
    encoded = payload["data_url"].split(",", 1)[1]
    qoi = base64.b64decode(encoded)
    qoi_path = OUT / f"{stem}.qoi"
    png_path = OUT / f"{stem}.png"
    qoi_path.write_bytes(qoi)
    image = Image.open(BytesIO(qoi))
    image.save(png_path)
    return png_path, payload["width"], payload["height"], payload["bytes"]


def write_vectors_test_image():
    path = OUT / "vectors_test_image.png"
    image = Image.new("RGBA", (96, 64))
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            value = int(255 * x / max(image.width - 1, 1))
            if (x // 12 + y // 8) % 2:
                value = 255 - value
            pixels[x, y] = (value, value, value, 255)
    image.save(path)
    return path


def write_moire_test_image():
    path = OUT / "moire_test_image.png"
    image = Image.new("RGBA", (80, 120))
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            dx = x - image.width / 2
            dy = y - image.height / 2
            ring = int((dx * dx + dy * dy) ** 0.5 / 5) % 2
            value = 230 if ring else 35
            pixels[x, y] = (value, value, value, 255)
    image.save(path)
    return path


def write_flow_test_image():
    path = OUT / "flow_test_image.png"
    image = Image.new("RGBA", (128, 80))
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            wave = int((1 + math.sin(x * 0.18 + y * 0.11)) * 127.5)
            pixels[x, y] = (wave, wave, wave, 255)
    image.save(path)
    return path


def write_slime_test_image(stem):
    path = OUT / f"{stem}.png"
    image = Image.new("RGBA", (96, 96))
    pixels = image.load()
    center = (image.width - 1) * 0.5
    for y in range(image.height):
        for x in range(image.width):
            dx = x - center
            dy = y - center
            radius = (dx * dx + dy * dy) ** 0.5 / max(center, 1)
            wave = math.sin(x * 0.21) * math.cos(y * 0.17)
            value = int(max(0.0, min(1.0, 1.0 - radius + 0.25 * wave)) * 255)
            pixels[x, y] = (value, value, value, 255)
    image.save(path)
    return path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.setdefault(
        "VK_ICD_FILENAMES",
        "/opt/homebrew/opt/molten-vk/etc/vulkan/icd.d/MoltenVK_icd.json",
    )
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

    try:
        call(proc, outq, "initialize", {}, timeout=10.0)
        time.sleep(1.0)
        initial = status(proc, outq)
        results = [{"name": "main_menu", "status": initial}]
        save_screenshot(proc, outq, "00_main_menu")

        for index, (name, x, y) in enumerate(SIM_CLICKS, start=1):
            tool(proc, outq, "set_mode", {"mode": SIM_MODES[name]}, timeout=6.0)
            time.sleep(3.5 if name == "primordial" else 2.6)
            current = status(proc, outq)
            png_path, width, height, byte_count = save_screenshot(proc, outq, f"{index:02d}_{name}")
            results.append(
                {
                    "name": name,
                    "mode": current.get("app_mode"),
                    "fps": current.get("fps"),
                    "frame_ms": current.get("frame_ms"),
                    "draw_count": current.get("command_draw_count"),
                    "compute_dispatch_count": current.get("command_compute_dispatch_count"),
                    "pipeline_bind_count": current.get("command_pipeline_bind_count"),
                    "screenshot": str(png_path),
                    "size": [width, height],
                    "bytes": byte_count,
                }
            )
            if CAPTURE_SLIME_IMAGES and name == "slime_mold":
                mask_path = write_slime_test_image("slime_mask_test_image")
                tool(proc, outq, "load_slime_mask_image", {"path": str(mask_path)}, timeout=6.0)
                time.sleep(1.4)
                mask_status = status(proc, outq)
                mask_png, mask_width, mask_height, mask_bytes = save_screenshot(proc, outq, f"{index:02d}_{name}_mask_image")
                results.append(
                    {
                        "name": "slime_mask_image",
                        "mode": mask_status.get("app_mode"),
                        "fps": mask_status.get("fps"),
                        "frame_ms": mask_status.get("frame_ms"),
                        "draw_count": mask_status.get("command_draw_count"),
                        "compute_dispatch_count": mask_status.get("command_compute_dispatch_count"),
                        "pipeline_bind_count": mask_status.get("command_pipeline_bind_count"),
                        "last_message": mask_status.get("last_message"),
                        "screenshot": str(mask_png),
                        "size": [mask_width, mask_height],
                        "bytes": mask_bytes,
                    }
                )
                position_path = write_slime_test_image("slime_position_test_image")
                tool(proc, outq, "load_slime_position_image", {"path": str(position_path)}, timeout=6.0)
                time.sleep(1.8)
                position_status = status(proc, outq)
                position_png, position_width, position_height, position_bytes = save_screenshot(proc, outq, f"{index:02d}_{name}_position_image")
                results.append(
                    {
                        "name": "slime_position_image",
                        "mode": position_status.get("app_mode"),
                        "fps": position_status.get("fps"),
                        "frame_ms": position_status.get("frame_ms"),
                        "draw_count": position_status.get("command_draw_count"),
                        "compute_dispatch_count": position_status.get("command_compute_dispatch_count"),
                        "pipeline_bind_count": position_status.get("command_pipeline_bind_count"),
                        "last_message": position_status.get("last_message"),
                        "screenshot": str(position_png),
                        "size": [position_width, position_height],
                        "bytes": position_bytes,
                    }
                )
            if CAPTURE_PELLETS_TRAILS and name == "pellets":
                trail_x, trail_y = raw_point(initial, 2690, 1138)
                click(proc, outq, trail_x, trail_y)
                time.sleep(1.8)
                trail_status = status(proc, outq)
                trail_png, trail_width, trail_height, trail_bytes = save_screenshot(proc, outq, f"{index:02d}_{name}_trails")
                results.append(
                    {
                        "name": "pellets_trails",
                        "mode": trail_status.get("app_mode"),
                        "fps": trail_status.get("fps"),
                        "frame_ms": trail_status.get("frame_ms"),
                        "draw_count": trail_status.get("command_draw_count"),
                        "compute_dispatch_count": trail_status.get("command_compute_dispatch_count"),
                        "pipeline_bind_count": trail_status.get("command_pipeline_bind_count"),
                        "render_pass_count": trail_status.get("command_render_pass_count"),
                        "pipeline_barrier_count": trail_status.get("command_pipeline_barrier_count"),
                        "screenshot": str(trail_png),
                        "size": [trail_width, trail_height],
                        "bytes": trail_bytes,
                    }
                )
            if CAPTURE_FLOW_IMAGE and name == "flow_field":
                image_path = write_flow_test_image()
                tool(proc, outq, "load_flow_image", {"path": str(image_path)}, timeout=6.0)
                time.sleep(1.8)
                image_status = status(proc, outq)
                image_png, image_width, image_height, image_bytes = save_screenshot(proc, outq, f"{index:02d}_{name}_image")
                results.append(
                    {
                        "name": "flow_image",
                        "mode": image_status.get("app_mode"),
                        "fps": image_status.get("fps"),
                        "frame_ms": image_status.get("frame_ms"),
                        "draw_count": image_status.get("command_draw_count"),
                        "compute_dispatch_count": image_status.get("command_compute_dispatch_count"),
                        "pipeline_bind_count": image_status.get("command_pipeline_bind_count"),
                        "last_message": image_status.get("last_message"),
                        "screenshot": str(image_png),
                        "size": [image_width, image_height],
                        "bytes": image_bytes,
                    }
                )
            if CAPTURE_PRIMORDIAL_TRACES and name == "primordial":
                trace_x, trace_y = raw_point(initial, 2690, 1718)
                click(proc, outq, trace_x, trace_y)
                time.sleep(1.8)
                trace_status = status(proc, outq)
                trace_png, trace_width, trace_height, trace_bytes = save_screenshot(proc, outq, f"{index:02d}_{name}_traces")
                results.append(
                    {
                        "name": "primordial_traces",
                        "mode": trace_status.get("app_mode"),
                        "fps": trace_status.get("fps"),
                        "frame_ms": trace_status.get("frame_ms"),
                        "draw_count": trace_status.get("command_draw_count"),
                        "compute_dispatch_count": trace_status.get("command_compute_dispatch_count"),
                        "pipeline_bind_count": trace_status.get("command_pipeline_bind_count"),
                        "render_pass_count": trace_status.get("command_render_pass_count"),
                        "pipeline_barrier_count": trace_status.get("command_pipeline_barrier_count"),
                        "screenshot": str(trace_png),
                        "size": [trace_width, trace_height],
                        "bytes": trace_bytes,
                    }
                )
            if CAPTURE_MOIRE_IMAGE and name == "moire":
                image_path = write_moire_test_image()
                tool(proc, outq, "load_moire_image", {"path": str(image_path)}, timeout=6.0)
                time.sleep(1.8)
                image_status = status(proc, outq)
                image_png, image_width, image_height, image_bytes = save_screenshot(proc, outq, f"{index:02d}_{name}_image")
                results.append(
                    {
                        "name": "moire_image",
                        "mode": image_status.get("app_mode"),
                        "fps": image_status.get("fps"),
                        "frame_ms": image_status.get("frame_ms"),
                        "draw_count": image_status.get("command_draw_count"),
                        "compute_dispatch_count": image_status.get("command_compute_dispatch_count"),
                        "pipeline_bind_count": image_status.get("command_pipeline_bind_count"),
                        "last_message": image_status.get("last_message"),
                        "screenshot": str(image_png),
                        "size": [image_width, image_height],
                        "bytes": image_bytes,
                    }
                )
            if CAPTURE_VECTORS_IMAGE and name == "vectors":
                image_path = write_vectors_test_image()
                tool(proc, outq, "load_vectors_image", {"path": str(image_path)}, timeout=6.0)
                time.sleep(1.8)
                image_status = status(proc, outq)
                image_png, image_width, image_height, image_bytes = save_screenshot(proc, outq, f"{index:02d}_{name}_image")
                results.append(
                    {
                        "name": "vectors_image",
                        "mode": image_status.get("app_mode"),
                        "fps": image_status.get("fps"),
                        "frame_ms": image_status.get("frame_ms"),
                        "draw_count": image_status.get("command_draw_count"),
                        "compute_dispatch_count": image_status.get("command_compute_dispatch_count"),
                        "pipeline_bind_count": image_status.get("command_pipeline_bind_count"),
                        "last_message": image_status.get("last_message"),
                        "screenshot": str(image_png),
                        "size": [image_width, image_height],
                        "bytes": image_bytes,
                    }
                )
            tool(proc, outq, "set_mode", {"mode": "Main_Menu"}, timeout=6.0)
            time.sleep(1.4)

        (OUT / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
        print(json.dumps(results, indent=2))
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
