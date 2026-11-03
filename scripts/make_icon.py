#!/usr/bin/env python3
"""生成应用图标：珊瑚→蜜桃→暖阳渐变底 + 白色爱心定位针。依赖 Pillow。"""
import os, sys, json
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

def make(size=1024):
    img = Image.new('RGB', (size, size))
    px = img.load()
    c = [(255, 107, 138), (255, 154, 108), (255, 209, 102)]
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size - 2)
            a, b, u = (c[0], c[1], t * 2) if t < .5 else (c[1], c[2], (t - .5) * 2)
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3))
    s = size
    # 定位针（水滴）
    layer = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy, r = s // 2, int(s * .42), int(s * .24)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 255))
    d.polygon([(cx - int(r * .86), cy + int(r * .5)), (cx + int(r * .86), cy + int(r * .5)), (cx, int(s * .80))], fill=(255, 255, 255, 255))
    # 爱心
    hr = int(r * .5)
    hx, hy = cx, cy - int(hr * .1)
    heart = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    hd = ImageDraw.Draw(heart)
    col = (255, 107, 138, 255)
    hd.ellipse([hx - hr, hy - hr, hx, hy + int(hr * .1)], fill=col)
    hd.ellipse([hx, hy - hr, hx + hr, hy + int(hr * .1)], fill=col)
    hd.polygon([(hx - hr + 2, hy - int(hr * .25)), (hx + hr - 2, hy - int(hr * .25)), (hx, hy + int(hr * 1.05))], fill=col)
    shadow = layer.filter(ImageFilter.GaussianBlur(s // 60))
    img.paste((120, 40, 60), (0, int(s * .012)), shadow.split()[3].point(lambda v: int(v * .25)))
    img.paste(layer, (0, 0), layer)
    img.paste(heart, (0, 0), heart)
    return img

icon = make(1024)
ios_dir = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
if os.path.isdir(ios_dir):
    contents = json.load(open(os.path.join(ios_dir, 'Contents.json')))
    for im in contents['images']:
        fn = im.get('filename')
        if not fn: continue
        w = float(im['size'].split('x')[0]); sc = int(im['scale'].replace('x', ''))
        px = int(round(w * sc))
        icon.resize((px, px), Image.LANCZOS).save(os.path.join(ios_dir, fn))
sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for k, v in sizes.items():
    d = os.path.join(ROOT, f'android/app/src/main/res/mipmap-{k}')
    if os.path.isdir(d):
        icon.resize((v, v), Image.LANCZOS).save(os.path.join(d, 'ic_launcher.png'))
icon.save(os.path.join(ROOT, 'docs/icon.png'))
print('icons generated')
