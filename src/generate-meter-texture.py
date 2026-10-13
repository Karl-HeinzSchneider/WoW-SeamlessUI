"""Generate Seamless's original shaded meter fill; run from any directory."""

from pathlib import Path
import struct

WIDTH, HEIGHT = 256, 32
target = Path(__file__).resolve().parent.parent / "SeamlessDamageMeter" / "Textures" / "ShadedBar.tga"
target.parent.mkdir(parents=True, exist_ok=True)
# Uncompressed 24-bit grayscale RGB, top-left origin. No reference image is read.
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, WIDTH, HEIGHT, 24, 0x20)
pixels = bytearray()
for y in range(HEIGHT):
    if y == 0:
        shade = 232  # Narrow highlight.
    elif y == HEIGHT - 1:
        shade = 88  # Narrow underside shadow.
    else:
        progress = (y - 1) / (HEIGHT - 3)
        shade = round(198 - 44 * progress ** 1.15)
    pixels.extend(bytes((shade, shade, shade)) * WIDTH)
target.write_bytes(header + pixels)
print(f"Generated {target.name}: {WIDTH} x {HEIGHT}, opaque RGB")
