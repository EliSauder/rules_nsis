"""Ensure the source fallback produces Windows x86 artifacts on every host."""

from pathlib import Path
import struct
import sys
import unittest


ZLIB = next(
    Path(name).parent
    for arg in sys.argv[1:]
    for name in arg.split()
    if name.endswith("/zlib1.dll")
)
sys.argv[1:] = []


class WindowsZlibTest(unittest.TestCase):
    def test_dll_is_windows_x86(self):
        dll = (ZLIB / "zlib1.dll").read_bytes()
        self.assertEqual(dll[:2], b"MZ")
        pe = struct.unpack_from("<I", dll, 0x3C)[0]
        self.assertEqual(dll[pe:pe + 4], b"PE\0\0")
        self.assertEqual(struct.unpack_from("<H", dll, pe + 4)[0], 0x14C)

    def test_static_library_contains_x86_coff(self):
        archive = (ZLIB / "lib" / "zlib.lib").read_bytes()
        self.assertEqual(archive[:8], b"!<arch>\n")
        offset = 8
        objects = 0
        while offset < len(archive):
            header = archive[offset:offset + 60]
            self.assertEqual(header[58:], b"`\n")
            name = header[:16].strip()
            size = int(header[48:58])
            if name not in (b"/", b"//", b"/SYM64/"):
                self.assertEqual(struct.unpack_from("<H", archive, offset + 60)[0], 0x14C)
                objects += 1
            offset += 60 + size + size % 2
        self.assertGreater(objects, 0)

    def test_nsis_layout_and_license(self):
        for name in ("include/zlib.h", "include/zconf.h", "lib/zdll.lib", "lib/libzdll.a"):
            with self.subTest(name=name):
                self.assertGreater((ZLIB / name).stat().st_size, 0)
        self.assertIn("Permission is granted", (ZLIB / "LICENSE").read_text())


if __name__ == "__main__":
    unittest.main()
