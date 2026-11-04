#!/usr/bin/env bash
# 构建未签名 IPA（需要 macOS + Xcode + Flutter + CocoaPods）。
# 用法： scripts/build_ipa.sh [--with-widgets] [env 文件]
#   默认：不含 Widget Extension（侧载最稳）→ dist/CoupleLocator-noext.ipa
#   --with-widgets：先运行 scripts/add_widget_extension.rb 加入小组件/实时活动扩展 → dist/CoupleLocator-widgets.ipa
set -euo pipefail
cd "$(dirname "$0")/.."
WITH=0
if [ "${1:-}" = "--with-widgets" ]; then WITH=1; shift; fi
ENV_FILE="${1:-env/dev.json}"
[ -f "$ENV_FILE" ] || { echo "缺少 $ENV_FILE，请复制 env/example.json 并填写"; exit 1; }
python3 scripts/fill_defaults.py "$ENV_FILE"  # 补全公开的默认高德 Key（env/defaults.json）

if [ "$WITH" = 1 ]; then
  gem list -i xcodeproj >/dev/null 2>&1 || gem install xcodeproj --no-document
  ruby scripts/add_widget_extension.rb
  NAME=CoupleLocator-widgets
else
  NAME=CoupleLocator-noext
fi

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build ios --release --no-codesign --dart-define-from-file="$ENV_FILE"

rm -rf build/ipa && mkdir -p build/ipa/Payload dist
cp -R build/ios/iphoneos/Runner.app build/ipa/Payload/Runner.app
(cd build/ipa && zip -qry "../../dist/$NAME.ipa" Payload)
echo "已生成 dist/$NAME.ipa（未签名，请用 AltStore / Sideloadly / TrollStore 等工具重签后安装）"

# 复原工程，避免污染工作区
if [ "$WITH" = 1 ]; then git checkout -- ios/Runner.xcodeproj 2>/dev/null || true; rm -f ios/Runner/Runner.entitlements; fi
