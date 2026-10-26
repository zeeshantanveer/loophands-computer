# LoopHands guest wallpaper (wallpaper.png, 1280x800): soft LoopHands teal (#1F6F68) blended
# toward off-white. Original, generated: python3 make-wallpaper.py (needs numpy and Pillow).
import os
import numpy as np
from PIL import Image
W, H = 1280, 800
y, x = np.mgrid[0:H, 0:W].astype(np.float64)
off = np.array([247, 245, 240], float)   # off-white
teal = np.array([31, 111, 104], float)   # #1F6F68
mint = np.array([168, 208, 200], float)  # teal lifted toward white
def blob(cx, cy, r):
    d = np.sqrt(((x - cx) / r) ** 2 + ((y - cy) / r) ** 2)
    return np.clip(1 - d, 0, 1) ** 2 * (3 - 2 * np.clip(1 - d, 0, 1))  # smoothstep falloff
# diagonal wash: light top-left, a little more colour toward bottom-right
diag = np.clip((x / W * 0.55 + y / H * 0.45), 0, 1) ** 1.6
t_mint = np.clip(0.45 * diag + 0.55 * blob(1050, 820, 760) + 0.35 * blob(120, -80, 620), 0, 1)
t_teal = np.clip(0.32 * blob(1180, 900, 620) + 0.12 * blob(-60, 860, 520), 0, 1)
img = off * (1 - t_mint[..., None]) + mint * t_mint[..., None]
img = img * (1 - t_teal[..., None]) + teal * t_teal[..., None]
rng = np.random.default_rng(7)
img += rng.uniform(-0.5, 0.5, img.shape)  # dither against banding
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wallpaper.png')
Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8)).save(out, optimize=True)
