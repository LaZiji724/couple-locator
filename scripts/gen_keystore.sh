#!/usr/bin/env bash
# 生成自己保管的签名 keystore，并写入 android/key.properties（两者都已在 .gitignore 中，切勿提交）。
set -euo pipefail
cd "$(dirname "$0")/../android"
KS="app/upload-keystore.jks"
[ -f "$KS" ] && { echo "$KS 已存在，退出"; exit 1; }
read -r -s -p "设置 keystore 密码(至少 6 位): " PW; echo
keytool -genkeypair -v -keystore "$KS" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias couple -storepass "$PW" -keypass "$PW" -dname "CN=Couple Locator, O=Private, C=CN"
cat > key.properties <<EOP
storePassword=$PW
keyPassword=$PW
keyAlias=couple
storeFile=upload-keystore.jks
EOP
echo "完成。请备份 $KS 与密码；丢失后将无法覆盖安装升级。"
