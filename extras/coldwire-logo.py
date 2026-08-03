"""Coldwire fastfetch logo: wireframe icosahedron over dot-matrix terrain.
550x300 RGBA (transparent bg) -> ~/.config/fastfetch/coldwire-logo.png"""
import math
import numpy as np
from PIL import Image, ImageDraw

W, H = 550, 300
INK = (242, 242, 240)
DIM = (138, 138, 138)
AMBER = (255, 176, 0)
rng = np.random.default_rng(4)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# ── dot-matrix terrain, lower band ──
ROWS, COLS = 42, 220
for r in range(ROWS):
    z = r / (ROWS - 1)                      # 0 far, 1 near
    y_base = H * 0.55 + z ** 1.4 * H * 0.42
    spread = 0.72 + 0.28 * z
    for c in range(COLS):
        x01 = c / (COLS - 1)
        h = (math.sin(x01 * 9 + z * 3) * 0.5 + 0.5) * math.exp(-((x01 - 0.68) / 0.30) ** 2)
        h += 0.25 * (math.sin(x01 * 23 + z * 8) * 0.5 + 0.5) * h
        x = (x01 - 0.5) * spread * W * 1.3 + W * 0.5 + rng.normal(0, 0.8)
        y = y_base - h * (30 + 90 * z) + rng.normal(0, 0.8)
        if 0 <= x < W and 0 <= y < H and rng.random() < 0.30 + 0.70 * h:
            a = int(255 * (0.25 + 0.75 * h) * (0.45 + 0.55 * z))
            img.putpixel((int(x), int(y)), (*INK, min(a, 230)))

# ── icosahedron wireframe ──
phi = (1 + 5 ** 0.5) / 2
verts = [(-1, phi, 0), (1, phi, 0), (-1, -phi, 0), (1, -phi, 0),
         (0, -1, phi), (0, 1, phi), (0, -1, -phi), (0, 1, -phi),
         (phi, 0, -1), (phi, 0, 1), (-phi, 0, -1), (-phi, 0, 1)]
edges = [(0, 1), (0, 5), (0, 7), (0, 10), (0, 11), (1, 5), (1, 7), (1, 8), (1, 9),
         (2, 3), (2, 4), (2, 6), (2, 10), (2, 11), (3, 4), (3, 6), (3, 8), (3, 9),
         (4, 5), (4, 9), (4, 11), (5, 9), (5, 11), (6, 7), (6, 8), (6, 10),
         (7, 8), (7, 10), (8, 9), (10, 11)]
cx, cy, scale = W * 0.32, H * 0.40, 62
ang = 0.55
ca, sa, cb, sb = math.cos(ang), math.sin(ang), math.cos(ang * 0.7), math.sin(ang * 0.7)
proj = []
for vx, vy, vz in verts:
    x1 = vx * ca + vz * sa
    z1 = -vx * sa + vz * ca
    y1 = vy * cb - z1 * sb
    z2 = vy * sb + z1 * cb
    p = 1 / (1 + z2 * 0.10)
    proj.append((cx + x1 * scale * p, cy + y1 * scale * p, z2))
for a, b in edges:
    pa, pb = proj[a], proj[b]
    depth = (pa[2] + pb[2]) / 2
    alpha = int(255 * (0.30 + 0.45 * (1 - (depth + 2) / 4)))
    d.line([pa[0], pa[1], pb[0], pb[1]], fill=(*INK, alpha), width=1)
for i, (px, py, _) in enumerate(proj):
    d.rectangle([px - 1, py - 1, px + 1, py + 1], fill=(*INK, 210))
# one amber vertex: the "you are here" marker
ax, ay, _ = proj[9]
d.rectangle([ax - 2, ay - 2, ax + 2, ay + 2], fill=(*AMBER, 255))

# ── corner tick marks ──
for tx, ty, dx, dy in [(3, 3, 1, 1), (W - 4, 3, -1, 1), (3, H - 4, 1, -1), (W - 4, H - 4, -1, -1)]:
    d.line([tx, ty, tx + 8 * dx, ty], fill=(*DIM, 200), width=1)
    d.line([tx, ty, tx, ty + 8 * dy], fill=(*DIM, 200), width=1)

img.save("/home/m31/.config/fastfetch/coldwire-logo.png")
print("saved coldwire-logo.png")
