#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

import importlib.util
import shutil
import struct
import subprocess
import tempfile
import unittest
import zlib
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "bridge_icons.py"
SPEC = importlib.util.spec_from_file_location("bridge_icons", SCRIPT)
icons = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(icons)


def png(size, color=b"\x00\x00\x00\xff"):
    row = b"\x00" + color * size
    pixels = row * size

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))

    return (
        icons.PNG_SIGNATURE
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(pixels))
        + chunk(b"IEND", b"")
    )


class IconsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "icons"
        self.source.mkdir()
        for filename in icons.required_files():
            path = self.source / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            size = int(Path(filename).stem)
            color = b"\x33\x88\xf0\x60" if filename.startswith("transparent/") else b"\x00\x00\x00\xff"
            path.write_bytes(png(size, color))

    def test_validation_and_missing_file(self):
        icons.validate_directory(self.source)
        (self.source / "opaque/32.png").unlink()
        with self.assertRaisesRegex(ValueError, "opaque/32.png: cannot read"):
            icons.validate_directory(self.source)

    def test_wrong_dimensions_are_rejected(self):
        (self.source / "adaptive/162.png").write_bytes(png(108))
        with self.assertRaisesRegex(ValueError, "expected 162x162, got 108x108"):
            icons.validate_directory(self.source)

    def test_corrupted_checksum_is_rejected(self):
        path = self.source / "opaque/16.png"
        data = bytearray(path.read_bytes())
        data[29] ^= 1
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "checksum"):
            icons.validate_directory(self.source)

    def test_windows_resources_without_python(self):
        output = self.root / "application.rc"
        script = Path(__file__).parent / "windows-resources.cmake"
        cmake = shutil.which("cmake")
        self.assertIsNotNone(cmake, "CMake is required to test Windows resources")
        command = [
            cmake,
            "-DCMAKE_DISABLE_FIND_PACKAGE_Python3=TRUE",
            f"-DBRIDGE_ICON_SOURCE={self.source}",
            f"-DBRIDGE_GENERATED_RC={output}",
            "-P", str(script),
        ]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        rc = output.read_text()
        self.assertIn("1 14 BEGIN\n    0, 1, 6,\n", rc)
        for icon_id, size in enumerate((16, 24, 32, 48, 64, 256), start=1):
            image = self.source / icons.transparent_path(size)
            self.assertIn(f'{icon_id} 3 "{image.as_posix()}"', rc)
            encoded = size % 256
            packed = encoded | (encoded << 8)
            terminator = "," if icon_id < 6 else ""
            self.assertIn(f"    {packed}, 0, 1, 32, {image.stat().st_size}L, {icon_id}{terminator}\n", rc)

        image = self.source / "adaptive/162.png"
        original = image.read_bytes()
        invalid = [
            (png(108), r"expected 162x162, got\s+108x108"),
            (original[:-12], r"missing final PNG IEND\s+chunk"),
            (original[:28] + b"\x01" + original[29:], r"expected\s+non-interlaced PNG"),
        ]
        for data, error in invalid:
            with self.subTest(error=error):
                image.write_bytes(data)
                result = subprocess.run(command, capture_output=True, text=True, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertRegex(result.stdout + result.stderr, error)

    def test_android_resources_and_background(self):
        output = self.root / "res"
        icons.write_android(self.source, output, "#070508")
        for density, legacy, adaptive in icons.ANDROID_DENSITIES:
            for filename, source in (
                ("ic_launcher.png", icons.opaque_path(legacy)),
                ("ic_launcher_foreground.png", icons.adaptive_path(adaptive)),
                ("ic_launcher_monochrome.png", icons.monochrome_path(adaptive)),
            ):
                self.assertEqual(
                    (output / f"mipmap-{density}" / filename).read_bytes(),
                    (self.source / source).read_bytes(),
                )
        self.assertIn("#070508", (output / "values/colors.xml").read_text())
        self.assertIn("<monochrome ", (output / "mipmap-anydpi-v26/ic_launcher.xml").read_text())
        with self.assertRaisesRegex(ValueError, "#RRGGBB"):
            icons.write_android(self.source, output, "transparent")


if __name__ == "__main__":
    unittest.main()
