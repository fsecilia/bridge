#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

"""Writes a complete, valid Bridge icon directory of solid PNGs for fixtures."""

import importlib.util
import struct
import sys
import zlib
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "bridge_icons.py"
SPEC = importlib.util.spec_from_file_location("bridge_icons", SCRIPT)
icons = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(icons)


def png(size):
    row = b"\x00" + b"\x10\x20\x30\xff" * size

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))

    return (
        icons.PNG_SIGNATURE
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(row * size))
        + chunk(b"IEND", b"")
    )


def main():
    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    for filename in icons.required_files():
        path = output / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        size = int(Path(filename).stem)
        path.write_bytes(png(size))
    icons.validate_directory(output)


if __name__ == "__main__":
    main()
