#!/usr/bin/env bash
# ==============================================================================
# TGBot Flutter Android 32位 / 64位 分离独立打包脚本
# 用法:
#   bash build_apks.sh        # 同时编译 32 位和 64 位 APK
#   bash build_apks.sh 64     # 仅编译 64 位 APK (推荐主流手机)
#   bash build_apks.sh 32     # 仅编译 32 位 APK (老旧备用机)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_DIR="$SCRIPT_DIR/release_apks"
mkdir -p "$OUTPUT_DIR"

TARGET="${1:-all}"

echo "=========================================================="
echo "🚀 开始编译 TGBot Android APK (目标: $TARGET)"
echo "=========================================================="

# 依赖更新与检查
flutter pub get

# 执行分架构构建
echo "📦 正在执行分架构编译 (--split-per-abi)..."
flutter build apk --release --split-per-abi

APK_SOURCE_DIR="$SCRIPT_DIR/build/app/outputs/flutter-apk"

if [ "$TARGET" = "64" ] || [ "$TARGET" = "all" ]; then
    if [ -f "$APK_SOURCE_DIR/app-arm64-v8a-release.apk" ]; then
        cp "$APK_SOURCE_DIR/app-arm64-v8a-release.apk" "$OUTPUT_DIR/TGBot_arm64-v8a_64bit.apk"
        SIZE_64=$(ls -lh "$OUTPUT_DIR/TGBot_arm64-v8a_64bit.apk" | awk '{print $5}')
        echo "✅ [64位] 已生成: release_apks/TGBot_arm64-v8a_64bit.apk ($SIZE_64)"
    fi
fi

if [ "$TARGET" = "32" ] || [ "$TARGET" = "all" ]; then
    if [ -f "$APK_SOURCE_DIR/app-armeabi-v7a-release.apk" ]; then
        cp "$APK_SOURCE_DIR/app-armeabi-v7a-release.apk" "$OUTPUT_DIR/TGBot_armeabi-v7a_32bit.apk"
        SIZE_32=$(ls -lh "$OUTPUT_DIR/TGBot_armeabi-v7a_32bit.apk" | awk '{print $5}')
        echo "✅ [32位] 已生成: release_apks/TGBot_armeabi-v7a_32bit.apk ($SIZE_32)"
    fi
fi

echo "=========================================================="
echo "🎉 打包完成！安装包输出目录: $OUTPUT_DIR"
echo "----------------------------------------------------------"
echo "📲 快速安装至手机命令:"
echo "   64位手机: adb install -r $OUTPUT_DIR/TGBot_arm64-v8a_64bit.apk"
echo "   32位手机: adb install -r $OUTPUT_DIR/TGBot_armeabi-v7a_32bit.apk"
echo "=========================================================="
