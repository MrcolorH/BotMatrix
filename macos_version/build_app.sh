#!/usr/bin/env bash
set -e

# ========================================================
# TGBot for macOS 一键编译与应用打包脚本
# ========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="TGBot"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🚀 [1/4] 正在编译 Release 版本 (Swift & SwiftUI 原生架构)..."
swift build -c release

BIN_PATH="$SCRIPT_DIR/.build/arm64-apple-macosx/release/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    # 兜底查找通用 release 路径
    BIN_PATH=$(find "$SCRIPT_DIR/.build" -type f -name "$APP_NAME" -perm +111 | grep "release" | head -n 1)
fi

if [ ! -f "$BIN_PATH" ]; then
    echo "❌ 未找到编译生成的可执行二进制文件: $BIN_PATH"
    exit 1
fi

echo "📦 [2/4] 正在组装 macOS .app 应用程序包..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 复制二进制
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# 复制图标
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# 生成 Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>TGBot</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.mrcolorh.tgbot</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>TGBot</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 TGBot Hub. All rights reserved.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

# 生成 PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "🔐 [3/4] 正在对应用包进行本机 Ad-hoc 代码签名..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "✨ [4/4] 打包圆满完成！"
echo "--------------------------------------------------------"
echo "🎉 应用程序路径: $APP_BUNDLE"

# 若系统 /Applications 中已有安装，自动同步覆盖更新
if [ -d "/Applications/$APP_NAME.app" ]; then
    echo "🔄 检测到 /Applications/$APP_NAME.app，正在自动同步覆盖更新..."
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
    echo "✅ 已成功覆盖更新至 /Applications/$APP_NAME.app！"
fi

echo "💡 您可以直接在终端执行以下命令运行它："
echo "   open \"/Applications/$APP_NAME.app\""
echo "--------------------------------------------------------"
