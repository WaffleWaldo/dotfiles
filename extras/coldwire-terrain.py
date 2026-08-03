"""Coldwire wallpaper: dot-matrix mountain terrain, white points on near-black.
3440x1440, styled after the point-cloud mountain in Dev/Desktop Inspo."""
import numpy as np
from PIL import Image

W, H = 3440, 1440
BG = 5  # #050505
rng = np.random.default_rng(31)


def value_noise(nx, nz, freq, rng):
    gw, gh = int(freq) + 2, int(freq) + 2
    grid = rng.random((gh, gw))
    x = nx * freq
    z = nz * freq
    x0 = np.floor(x).astype(int)
    z0 = np.floor(z).astype(int)
    fx = x - x0
    fz = z - z0
    fx = fx * fx * (3 - 2 * fx)
    fz = fz * fz * (3 - 2 * fz)
    a = grid[z0, x0]
    b = grid[z0, x0 + 1]
    c = grid[z0 + 1, x0]
    d = grid[z0 + 1, x0 + 1]
    return a + (b - a) * fx + (c - a) * fz + (a - b - c + d) * fx * fz


def fbm(nx, nz, octaves=6, base_freq=3.0):
    out = np.zeros_like(nx)
    amp, freq, tot = 1.0, base_freq, 0.0
    for _ in range(octaves):
        out += amp * value_noise(nx, nz, freq, rng)
        tot += amp
        amp *= 0.5
        freq *= 2.03
    return out / tot


# --- sample terrain on a depth grid (far -> near) ---
ROWS, COLS = 300, 1500
z = np.linspace(0.0, 1.0, ROWS)[:, None]          # 0 far, 1 near
x = np.linspace(0.0, 1.0, COLS)[None, :]
zz = np.repeat(z, COLS, axis=1)
xx = np.repeat(x, ROWS, axis=0)

h = fbm(xx, zz, octaves=6, base_freq=3.0)
ridge = 1.0 - np.abs(fbm(xx, zz, octaves=5, base_freq=2.0) * 2.0 - 1.0)
h = 0.45 * h + 0.75 * ridge ** 2.2

# mountain mass envelope: main peak left-of-center, mid-depth
env = (np.exp(-(((xx - 0.38) / 0.20) ** 2) - (((zz - 0.45) / 0.38) ** 2)) * 1.15
       + np.exp(-(((xx - 0.78) / 0.16) ** 2) - (((zz - 0.30) / 0.30) ** 2)) * 0.45
       + 0.06)
h = h * env
h = np.clip(h - 0.05, 0, None) ** 1.25

# --- project to screen ---
horizon = 0.42 * H
depth = zz ** 1.55                                  # perspective row spacing
ybase = horizon + depth * (H * 0.60)
spread = 0.62 + 0.55 * zz                           # rows widen toward viewer
sx = (xx - 0.5) * spread * W * 1.35 + W * 0.5
lift = h * (220 + 900 * zz)                         # taller relief up close
sy = ybase - lift

# jitter for the hand-plotted dot look
sx = sx + rng.normal(0, 1.1, sx.shape)
sy = sy + rng.normal(0, 1.1, sy.shape)

# brightness: height + distance fade + sparkle
hn = h / (h.max() + 1e-9)
bright = (0.30 + 1.60 * hn ** 0.85) * (0.40 + 0.60 * zz ** 0.6)
bright = bright * rng.uniform(0.55, 1.0, bright.shape)
keep = rng.random(h.shape) < (0.45 + 0.55 * (h / (h.max() + 1e-9)))  # sparse valleys

canvas = np.zeros((H, W), dtype=np.float32)
xs = np.clip(sx[keep].astype(int), 0, W - 1)
ys = np.clip(sy[keep].astype(int), 0, H - 1)
np.add.at(canvas, (ys, xs), bright[keep])

# faint dotted horizon grid lines in the sky region
for gy in np.linspace(horizon * 0.35, horizon * 0.96, 5):
    gxs = np.arange(0, W, 7)
    canvas[int(gy), gxs] += 0.10

img = np.clip(canvas, 0, 1.6)
img = (img / 1.6) ** 0.60                            # gamma lift for thin dots
px = (BG + img * (242 - BG)).astype(np.uint8)        # up to fg0-ish white
Image.fromarray(px, mode="L").convert("RGB").save(
    "/home/m31/Pictures/wallpapers/coldwire-terrain-01.png", optimize=True)
print("saved")
