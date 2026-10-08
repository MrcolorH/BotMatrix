# 📱 TGBot Flutter Android 独立应用

基于 Flutter 构建的 Telegram 机器人 Android 原生常驻应用。拥有现代化 Material 3 图形交互界面、插槽式服务扩展架构以及 7×24 小时系统级前台保活。

---

## ✨ 核心亮点

- 🚀 **极简打包体验**：使用纯 Dart 技术栈，提供 32 位与 64 位独立分包脚本，体积仅 15MB~18MB。
- 🤖 **全局机器人中心**：全局配置 Telegram 机器人凭据（Bot Token、有效性测试、一键启停）。
- 🧩 **动态服务插槽卡片**：
  - 首期内置 **Twitter / X 视频解析** 服务卡片；
  - 架构完全插件化，未来添加新服务仅需挂载模块，UI 自动呈现，**无需重构或大改界面**。
- 🔋 **Android 原生前台保活**：系统通知栏常驻控制卡片，支持锁屏防休眠与电池白名单引导。

---

## 📦 已编译安装包下载 (32 位 / 64 位独立拆分)

编译产物位于 `release_apks/` 目录：

| 文件名 | 架构说明 | 适用设备 | 产物体积 |
| :--- | :--- | :--- | :--- |
| **`TGBot_arm64-v8a_64bit.apk`** | 64 位 ARM (`arm64-v8a`) | **99% 的现代主流安卓手机** (推荐) | **~18 MB** |
| **`TGBot_armeabi-v7a_32bit.apk`** | 32 位 ARM (`armeabi-v7a`) | 远古 32 位老旧安卓备用机 | **~15 MB** |

---

## 🛠️ 打包与编译指令

项目中已内置一键分包脚本 `build_apks.sh`：

```bash
# 同时编译 32 位和 64 位独立包
bash build_apks.sh

# 仅编译 64 位包 (主流手机，速度更快)
bash build_apks.sh 64

# 仅编译 32 位包
bash build_apks.sh 32
```

---

## 📲 电脑 ADB 快速安装命令

```bash
# 推荐主流 64 位手机安装：
adb install -r release_apks/TGBot_arm64-v8a_64bit.apk

# 32 位老旧机型安装：
adb install -r release_apks/TGBot_armeabi-v7a_32bit.apk
```
