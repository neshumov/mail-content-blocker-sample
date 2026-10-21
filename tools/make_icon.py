#!/usr/bin/env python3
"""Draws the app icon (an envelope with a blocked tracking pixel) and writes App/Assets.xcassets/AppIcon.appiconset.
Needs Pillow:  python3 -m pip install pillow
"""
import json
import pathlib
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "App/Assets.xcassets/AppIcon.appiconset"
S = 4096  # draw big, scale down
k = S / 1024


def px(v):
    return int(round(v * k))


def rrect(draw, box, r, **kw):
    draw.rounded_rectangle([px(box[0]), px(box[1]), px(box[2]), px(box[3])], radius=px(r), **kw)


img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# soft shadow under the tile
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
rrect(ImageDraw.Draw(shadow), (100, 112, 924, 936), 186, fill=(0, 0, 0, 110))
img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(px(14))))

# tile with a vertical gradient
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
top, bottom = (66, 112, 238), (22, 48, 128)
for y in range(S):
    t = y / (S - 1)
    gd.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
mask = Image.new("L", (S, S), 0)
rrect(ImageDraw.Draw(mask), (100, 100, 924, 924), 186, fill=255)
img.paste(grad, (0, 0), mask)

d = ImageDraw.Draw(img)

# envelope
ex0, ey0, ex1, ey1 = 232, 330, 792, 700
rrect(d, (ex0 + 4, ey0 + 14, ex1 + 4, ey1 + 14), 44, fill=(10, 24, 70, 90))
rrect(d, (ex0, ey0, ex1, ey1), 44, fill=(246, 247, 250, 255))
cx = (ex0 + ex1) / 2
d.line([(px(ex0 + 30), px(ey0 + 34)), (px(cx), px(ey0 + 220)), (px(ex1 - 30), px(ey0 + 34))],
       fill=(150, 165, 205, 255), width=px(26), joint="curve")
d.line([(px(ex0 + 40), px(ey1 - 36)), (px(cx - 120), px(ey0 + 150))], fill=(205, 212, 232, 255), width=px(16))
d.line([(px(ex1 - 40), px(ey1 - 36)), (px(cx + 120), px(ey0 + 150))], fill=(205, 212, 232, 255), width=px(16))

# blocked pixel badge, top right of the envelope
bx, by, br = 770, 330, 118
d.ellipse([px(bx - br - 12), px(by - br - 12), px(bx + br + 12), px(by + br + 12)], fill=(30, 58, 150, 255))
d.ellipse([px(bx - br), px(by - br), px(bx + br), px(by + br)], fill=(255, 107, 115, 255))
d.rectangle([px(bx - 44), px(by - 44), px(bx + 44), px(by + 44)], fill=(255, 255, 255, 255))
d.line([(px(bx - 78), px(by + 78)), (px(bx + 78), px(by - 78))], fill=(255, 107, 115, 255), width=px(34))
d.line([(px(bx - 78), px(by + 78)), (px(bx + 78), px(by - 78))], fill=(255, 255, 255, 255), width=px(16))

master = img.resize((1024, 1024), Image.LANCZOS)
OUT.mkdir(parents=True, exist_ok=True)
images = []
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
        master.resize((size * scale, size * scale), Image.LANCZOS).save(OUT / name)
        images.append({"idiom": "mac", "size": f"{size}x{size}", "scale": f"{scale}x", "filename": name})
(OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"version": 1, "author": "xcode"}}, indent=2) + "\n")
(OUT.parent / "Contents.json").write_text(json.dumps({"info": {"version": 1, "author": "xcode"}}, indent=2) + "\n")
master.save(OUT.parent.parent.parent / "icon-preview.png")
print("ok")
