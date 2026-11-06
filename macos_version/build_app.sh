#!/usr/bin/env bash
set -e

# ========================================================
# BotMatrix for macOS 一键编译、签名与全能安装包打包脚本
# 支持生成 .app、.dmg 拖拽镜像包与 .pkg 引导式系统安装包
# ========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="BotMatrix"
VERSION="1.3.0"
VERSION_CODE="130"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🚀 [1/5] 正在编译 Release 版本 (Swift 6 & SwiftUI 原生架构)..."
swift build -c release

BIN_PATH="$SCRIPT_DIR/.build/arm64-apple-macosx/release/TGBot"
if [ ! -f "$BIN_PATH" ]; then
    # 兜底查找通用 release 路径
    BIN_PATH=$(find "$SCRIPT_DIR/.build" -type f -name "TGBot" -perm +111 | grep "release" | head -n 1)
fi

if [ ! -f "$BIN_PATH" ]; then
    echo "❌ 未找到编译生成的可执行二进制文件: $BIN_PATH"
    exit 1
fi

echo "📦 [2/5] 正在组装 macOS .app 应用程序包 ($APP_NAME.app)..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 复制二进制并重命名为主程序名
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# 复制图标
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# 生成 Info.plist
cat << EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.mrcolorh.botmatrix</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION_CODE</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 BotMatrix. All rights reserved.</string>
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

echo "🔐 [3/5] 正在对应用包进行本机 Ad-hoc 代码签名..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

# 同步覆盖本地 /Applications
if [ -d "/Applications/$APP_NAME.app" ]; then
    rm -rf "/Applications/$APP_NAME.app"
fi
cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
echo "✅ 本地已同步更新至 /Applications/$APP_NAME.app"

# 若旧名 TGBot.app 存在，清理旧名
if [ -d "/Applications/TGBot.app" ]; then
    rm -rf "/Applications/TGBot.app"
fi

echo "💿 [4/5] 正在生成 macOS 标准 DMG 拖拽安装镜像 (Disk Image)..."
DMG_ROOT="$BUILD_DIR/dmg_root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

DMG_FILE="$BUILD_DIR/${APP_NAME}_macOS_v${VERSION}.dmg"
rm -f "$DMG_FILE"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_FILE"
rm -rf "$DMG_ROOT"
echo "✅ DMG 磁盘镜像包已生成: $DMG_FILE"

echo "📦 [5/5] 正在生成 macOS 官方引导式安装包 (.pkg) 与通用分发压缩包 (.zip)..."
PKG_FILE="$BUILD_DIR/${APP_NAME}_macOS_v${VERSION}.pkg"
rm -f "$PKG_FILE"

# 准备 PKG 后置处理脚本 (自动移除隔离属性、修复权限、防止路径嵌套)
PKG_SCRIPTS_DIR="$BUILD_DIR/pkg_scripts"
rm -rf "$PKG_SCRIPTS_DIR"
mkdir -p "$PKG_SCRIPTS_DIR"
cat << 'EOF_POST' > "$PKG_SCRIPTS_DIR/postinstall"
#!/bin/bash
TARGET_APP="/Applications/BotMatrix.app"

# 1. 修复早期版本可能产生的嵌套目录问题
if [ -d "$TARGET_APP/BotMatrix.app" ]; then
    cp -R "$TARGET_APP/BotMatrix.app/" "/Applications/BotMatrix_temp.app/"
    rm -rf "$TARGET_APP"
    mv "/Applications/BotMatrix_temp.app" "$TARGET_APP"
fi

# 2. 清除 macOS Gatekeeper Quarantine 隔离标志，彻底杜绝“已损坏无法打开”拦截
xattr -cr "$TARGET_APP" 2>/dev/null || true

# 3. 递归赋予所有权与执行权限
chmod -R 755 "$TARGET_APP" 2>/dev/null || true

# 4. 清理旧版本痕迹
rm -rf "/Applications/TGBot.app" 2>/dev/null || true

exit 0
EOF_POST
chmod +x "$PKG_SCRIPTS_DIR/postinstall"

# 注意：component 为 BotMatrix.app，安装位置必须是 /Applications（非 /Applications/BotMatrix.app，否则会嵌套）
pkgbuild --install-location "/Applications" --component "$APP_BUNDLE" --scripts "$PKG_SCRIPTS_DIR" "$PKG_FILE"
rm -rf "$PKG_SCRIPTS_DIR"
echo "✅ PKG 系统向导安装包已生成 (含 postinstall 自动授权修复): $PKG_FILE"

ZIP_FILE="$BUILD_DIR/${APP_NAME}_macOS_v${VERSION}.zip"
rm -f "$ZIP_FILE"
(cd "$BUILD_DIR" && zip -r -y -q "$(basename "$ZIP_FILE")" "$APP_NAME.app")
echo "✅ ZIP 绿色免安装包已生成: $ZIP_FILE"

echo "--------------------------------------------------------"
echo "🎉 全部安装包构建圆满完成！生成列表："
ls -lh "$DMG_FILE" "$PKG_FILE" "$ZIP_FILE"
echo "--------------------------------------------------------"
