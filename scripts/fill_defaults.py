#!/usr/bin/env python3
"""用 env/defaults.json 里的公开默认值补全 env 文件中缺失或为 PLACEHOLDER 的项（高德 Key 不属于机密）。
用法：python3 scripts/fill_defaults.py env/ci.json"""
import json, os, sys

target = sys.argv[1]
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
defaults = json.load(open(os.path.join(root, 'env', 'defaults.json')))
d = json.load(open(target))
for k, v in defaults.items():
    if not d.get(k) or d[k] == 'PLACEHOLDER':
        d[k] = v
json.dump(d, open(target, 'w'), ensure_ascii=False, indent=2)
