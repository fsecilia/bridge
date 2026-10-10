#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

"""Validate consumer-rendered icons and assemble platform icon resources.

No image is resized. The PNGs are embedded or copied byte-for-byte.
"""

import argparse
import re
import shutil
import struct
import sys
import zlib
from pathlib import Path
from xml.sax.saxutils import escape

COMPLETE_SIZES = (16, 24, 32, 48, 64, 72, 96, 128, 144, 192, 256, 512)
ADAPTIVE_SIZES = (108, 162, 216, 324, 432)
WINDOWS_SIZES = (16, 24, 32, 48, 64, 256)
ANDROID_DENSITIES = (
    ("mdpi", 48, 108),
    ("hdpi", 72, 162),
    ("xhdpi", 96, 216),
    ("xxhdpi", 144, 324),
    ("xxxhdpi", 192, 432),
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def required_files():
    return (
        *(f"icon-{size}.png" for size in COMPLETE_SIZES),
        *(f"foreground-{size}.png" for size in ADAPTIVE_SIZES),
        *(f"monochrome-{size}.png" for size in ADAPTIVE_SIZES),
    )


def validate_png(path: Path, expected_size: int) -> bytes:
    try:
        data = path.read_bytes()
    except OSError as error:
        raise ValueError(f"{path}: cannot read PNG: {error}") from error

    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: invalid PNG signature")

    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    idat = bytearray()
    seen_end = False
    while offset + 12 <= len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        chunk_type = data[offset + 4 : offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError(f"{path}: truncated PNG chunk {chunk_type!r}")
        content = data[offset + 8 : end - 4]
        crc = struct.unpack_from(">I", data, end - 4)[0]
        if zlib.crc32(chunk_type + content) != crc:
            raise ValueError(f"{path}: invalid PNG checksum in {chunk_type!r}")
        if chunk_type == b"IHDR":
            if width is not None or offset != len(PNG_SIGNATURE) or length != 13:
                raise ValueError(f"{path}: invalid PNG header")
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", content
            )
            if (compression, filtering, interlace) != (0, 0, 0):
                raise ValueError(f"{path}: expected non-interlaced PNG")
        elif chunk_type == b"IDAT":
            idat.extend(content)
        elif chunk_type == b"IEND":
            if length != 0 or end != len(data):
                raise ValueError(f"{path}: invalid PNG end")
            seen_end = True
            break
        offset = end

    if not seen_end or not idat:
        raise ValueError(f"{path}: missing PNG image data or terminator")
    if (width, height) != (expected_size, expected_size):
        raise ValueError(
            f"{path}: expected {expected_size}x{expected_size}, got {width}x{height}"
        )
    if bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(f"{path}: expected 8-bit RGB or RGBA PNG")
    channels = 3 if color_type == 2 else 4
    expected_bytes = height * (width * channels + 1)
    try:
        decompressor = zlib.decompressobj()
        raw = decompressor.decompress(bytes(idat), expected_bytes + 1)
        raw += decompressor.flush()
    except zlib.error as error:
        raise ValueError(f"{path}: invalid compressed PNG data: {error}") from error
    if len(raw) != expected_bytes or not decompressor.eof or decompressor.unused_data:
        raise ValueError(f"{path}: invalid PNG pixel data length")
    if any(raw[row * (width * channels + 1)] > 4 for row in range(height)):
        raise ValueError(f"{path}: invalid PNG scanline filter")
    return data


def validate_directory(source: Path):
    if not source.is_dir():
        raise ValueError(f"icon directory does not exist: {source}")
    for filename in required_files():
        validate_png(source / filename, int(filename.split("-")[-1][:-4]))


def write_ico(source: Path, output: Path):
    images = [validate_png(source / f"icon-{size}.png", size) for size in WINDOWS_SIZES]
    output.parent.mkdir(parents=True, exist_ok=True)
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + 16 * len(images)
    entries = bytearray()
    for size, image in zip(WINDOWS_SIZES, images):
        entries.extend(struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(image), offset))
        offset += len(image)
    output.write_bytes(header + entries + b"".join(images))


def write_android(source: Path, output: Path, background: str):
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}", background):
        raise ValueError(f"adaptive background must be #RRGGBB, got {background!r}")
    if output.exists():
        shutil.rmtree(output)
    for density, legacy, adaptive in ANDROID_DENSITIES:
        directory = output / f"mipmap-{density}"
        directory.mkdir(parents=True)
        for filename, size in (
            ("ic_launcher.png", f"icon-{legacy}.png"),
            ("ic_launcher_foreground.png", f"foreground-{adaptive}.png"),
            ("ic_launcher_monochrome.png", f"monochrome-{adaptive}.png"),
        ):
            shutil.copyfile(source / size, directory / filename)

    values = output / "values"
    values.mkdir()
    (values / "colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        f'    <color name="bridge_launcher_background">{escape(background)}</color>\n'
        '</resources>\n',
        encoding="utf-8",
    )
    adaptive = output / "mipmap-anydpi-v26"
    adaptive.mkdir()
    (adaptive / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/bridge_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    for command in ("validate", "ico", "android"):
        subcommand = subcommands.add_parser(command)
        subcommand.add_argument("--source", required=True, type=Path)
        if command != "validate":
            subcommand.add_argument("--output", required=True, type=Path)
        if command == "android":
            subcommand.add_argument("--background", required=True)
    args = parser.parse_args()
    try:
        validate_directory(args.source)
        if args.command == "ico":
            write_ico(args.source, args.output)
        elif args.command == "android":
            write_android(args.source, args.output, args.background)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Bridge icon error: {error}\n")


if __name__ == "__main__":
    main()
