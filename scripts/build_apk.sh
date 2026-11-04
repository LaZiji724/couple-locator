#!/usr/bin/env bash
# 构建 Android APK：分 ABI 包 + 通用大包。
# 用法：scripts/build_apk.sh [env 文件，默认 env/dev.json]
# 需要：Flutter 3.x、JDK 17、Android SDK。签名：android/key.properties（见 docs/BUILD.md）。
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE="${1:-env/dev.json}"
[ -f "$ENV_FILE" ] || { echo "缺少 $ENV_FILE，请复制 env/example.json 并填写"; exit 1; }
python3 scripts/fill_defaults.py "$ENV_FILE"  # 补全公开的默认高德 Key（env/defaults.json）
AMAP_KEY=$(python3 -c "import json,sys;print(json.load(open('$ENV_FILE')).get('AMAP_ANDROID_KEY',''))")
export AMAP_ANDROID_KEY="$AMAP_KEY"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --split-per-abi --dart-define-from-file="$ENV_FILE"
flutter build apk --release --dart-define-from-file="$ENV_FILE"
mkdir -p dist
cp build/app/outputs/flutter-apk/*.apk dist/
ls -lh dist
