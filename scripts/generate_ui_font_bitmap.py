#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import urllib.request
from PIL import Image, ImageDraw, ImageFont


try:
    _resample_lanczos = Image.Resampling.LANCZOS
except AttributeError:
    _resample_lanczos = Image.LANCZOS

_glyph_id_re = re.compile(r"\[(\d+)=")


def glyph_id_for_char(font_path: Path, ch: str) -> int:
    result = subprocess.run(
        ["hb-shape", "--no-glyph-names", str(font_path), ch],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    match = _glyph_id_re.search(result.stdout)
    if match is None:
        raise RuntimeError(f"could not read glyph id for {ch!r}: {result.stdout}")
    return int(match.group(1))


def render_glyph_alpha(
    font: ImageFont.FreeTypeFont,
    ch: str,
    width: int,
    height: int,
    supersample: int,
    baseline: float,
) -> list[int]:
    scale = max(supersample, 1)
    canvas_w = width * scale
    canvas_h = height * scale
    image = Image.new("L", (canvas_w, canvas_h), 0)
    draw = ImageDraw.Draw(image)

    bbox = font.getbbox(ch, anchor="ls")
    if bbox is None:
        return [0] * (width * height)

    left, top, right, bottom = bbox
    glyph_w = right - left

    x = -left
    y = baseline * scale
    draw.text((x, y), ch, fill=255, font=font, anchor="ls")

    if scale > 1:
        image = image.resize((width, height), _resample_lanczos)

    try:
        return list(image.get_flattened_data())
    except AttributeError:
        return list(image.getdata())


def write_bitmap(
    output: Path,
    atlas_output: Path,
    font_path: Path,
    glyph_first: int,
    glyph_last: int,
    width: int,
    height: int,
    columns: int,
    supersample: int,
    font_size: int,
    source_url: str,
) -> None:
    font = ImageFont.truetype(str(font_path), font_size)
    glyph_count = glyph_last - glyph_first + 1
    ascent, descent = font.getmetrics()
    vertical_scale = height / max(ascent + descent, 1)
    baseline = ascent * vertical_scale
    glyph_ids = [glyph_id_for_char(font_path, chr(glyph)) for glyph in range(glyph_first, glyph_last + 1)]

    rows = (glyph_count + columns - 1) // columns
    atlas = Image.new("RGBA", (width * columns, height * rows), (255, 255, 255, 0))

    lines: list[str] = []
    lines.append("// Auto-generated from Zelda Sans OTF for ASCII glyphs %d..%d." % (glyph_first, glyph_last))
    lines.append("// Source: %s" % source_url)
    lines.append("// Font file: %s" % font_path)
    lines.append("// Rendered with scripts/generate_ui_font_bitmap.py")
    lines.append("")
    lines.append(f"static const uint UI_FONT_GLYPH_COUNT = {glyph_count}u;")
    lines.append(f"static const uint UI_FONT_GLYPH_WIDTH = {width}u;")
    lines.append(f"static const uint UI_FONT_GLYPH_HEIGHT = {height}u;")
    lines.append(f"static const uint UI_FONT_ATLAS_COLUMNS = {columns}u;")
    lines.append(f"static const uint UI_FONT_ATLAS_ROWS = {rows}u;")
    lines.append(f"static const uint UI_FONT_ATLAS_WIDTH = {width * columns}u;")
    lines.append(f"static const uint UI_FONT_ATLAS_HEIGHT = {height * rows}u;")

    for glyph in range(glyph_first, glyph_last + 1):
        ch = chr(glyph)
        alpha = render_glyph_alpha(font, ch, width, height, supersample, baseline)
        slot = glyph - glyph_first
        dst_x = (slot % columns) * width
        dst_y = (slot // columns) * height
        glyph_image = Image.new("RGBA", (width, height), (255, 255, 255, 0))
        glyph_image.putalpha(Image.frombytes("L", (width, height), bytes(alpha)))
        atlas.paste(glyph_image, (dst_x, dst_y))
        glyph_id = glyph_ids[slot]
        lines.append(f"// slot {slot:3}, codepoint {glyph:3}, glyph id {glyph_id:3}, atlas cell {slot % columns:2},{slot // columns:2}")

    atlas_output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(atlas_output)
    output.write_text("\n".join(lines) + "\n")


def write_metrics(
    output: Path,
    font_path: Path,
    glyph_first: int,
    glyph_last: int,
    cell_height: int,
    logical_height: int,
    font_size: int,
    source_url: str,
) -> None:
    font = ImageFont.truetype(str(font_path), font_size)
    glyph_count = glyph_last - glyph_first + 1
    ascent, descent = font.getmetrics()
    vertical_scale = cell_height / max(ascent + descent, 1)
    pixel_to_logical = logical_height / max(cell_height, 1)
    glyph_ids = [glyph_id_for_char(font_path, chr(glyph)) for glyph in range(glyph_first, glyph_last + 1)]
    max_glyph_id = max(glyph_ids)
    slot_by_id = [-1] * (max_glyph_id + 1)
    for slot, glyph_id in enumerate(glyph_ids):
        slot_by_id[glyph_id] = slot

    lines: list[str] = []
    lines.append("package ui")
    lines.append("")
    lines.append("// Auto-generated from Zelda Sans OTF for ASCII glyph advances %d..%d." % (glyph_first, glyph_last))
    lines.append("// Source: %s" % source_url)
    lines.append("// Font file: %s" % font_path)
    lines.append("// Rendered with scripts/generate_ui_font_bitmap.py")
    lines.append("")
    lines.append(f"GUI_FONT_GLYPH_FIRST :: {glyph_first}")
    lines.append(f"GUI_FONT_GLYPH_LAST :: {glyph_last}")
    lines.append(f"GUI_FONT_GLYPH_COUNT :: {glyph_count}")
    lines.append(f"GUI_FONT_GLYPH_ID_MAX :: {max_glyph_id}")
    lines.append(f"GUI_FONT_LOGICAL_HEIGHT :: f32({logical_height})")
    lines.append("")
    lines.append(f"GUI_FONT_ADVANCES: [{glyph_count}]f32 = {{")
    for glyph in range(glyph_first, glyph_last + 1):
        advance = font.getlength(chr(glyph)) * vertical_scale * pixel_to_logical
        lines.append(f"\t{advance:.6f}, // {glyph:3} {chr(glyph)!r}")
    lines.append("}")
    lines.append("")
    lines.append(f"GUI_FONT_GLYPH_SLOT_BY_ID: [{max_glyph_id + 1}]i32 = {{")
    for glyph_id, slot in enumerate(slot_by_id):
        lines.append(f"\t{slot}, // glyph id {glyph_id}")
    lines.append("}")
    lines.append("")
    output.write_text("\n".join(lines) + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate ui_font_bitmap.slang from Zelda Sans OTF.")
    parser.add_argument("--font", default="assets/fonts/ZeldaSans-Regular-v1.otf")
    parser.add_argument("--output", default="assets/shaders/ui_font_bitmap.slang")
    parser.add_argument("--atlas-output", default="assets/fonts/ui_font_atlas.png")
    parser.add_argument("--metrics-output", default="")
    parser.add_argument("--glyph-first", type=int, default=32)
    parser.add_argument("--glyph-last", type=int, default=126)
    parser.add_argument("--cell-width", type=int, default=10)
    parser.add_argument("--cell-height", type=int, default=16)
    parser.add_argument("--columns", type=int, default=16)
    parser.add_argument("--font-size", type=int, default=42)
    parser.add_argument("--logical-height", type=int, default=16)
    parser.add_argument("--supersample", type=int, default=4)
    parser.add_argument(
        "--font-url",
        default="https://www.zeldas.page/fonts/zelda-sans/ZeldaSans-Regular-v1.otf",
    )
    parser.add_argument("--fetch", action="store_true", help="Download font from --font-url if --font is missing")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    font_path = Path(args.font)
    output = Path(args.output)
    atlas_output = Path(args.atlas_output)
    if not font_path.exists():
        if args.fetch:
            font_path.parent.mkdir(parents=True, exist_ok=True)
            print(f"Downloading font: {args.font_url}")
            urllib.request.urlretrieve(args.font_url, str(font_path))
        else:
            print(f"error: font file not found: {font_path}")
            print("Hint: pass --fetch to download from the Zelda Sans source URL")
            return 1

    output.parent.mkdir(parents=True, exist_ok=True)
    write_bitmap(
        output=output,
        atlas_output=atlas_output,
        font_path=font_path,
        glyph_first=args.glyph_first,
        glyph_last=args.glyph_last,
        width=args.cell_width,
        height=args.cell_height,
        columns=max(args.columns, 1),
        supersample=args.supersample,
        font_size=args.font_size,
        source_url=args.font_url,
    )
    if args.metrics_output:
        metrics_output = Path(args.metrics_output)
        metrics_output.parent.mkdir(parents=True, exist_ok=True)
        write_metrics(
            output=metrics_output,
            font_path=font_path,
            glyph_first=args.glyph_first,
            glyph_last=args.glyph_last,
            cell_height=args.cell_height,
            logical_height=args.logical_height,
            font_size=args.font_size,
            source_url=args.font_url,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
