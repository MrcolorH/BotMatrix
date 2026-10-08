# 📱 TGBot Flutter Android 独立应用

基于 Flutter 构建的 Telegram 机器人 Android 原生常驻应用。拥有现代化 Material 3 图形交互界面、插槽式服务扩展架构以及 7×24 小时系统级前台保活。

---

## ✨ 核心亮点

- 🚀 **极简打包体验**：使用纯 Dart 技术栈，告别繁重配置，一键编译发布 APK。
- 🤖 **全局机器人中心**：全局配置 Telegram 机器人凭据（Bot Token、状态检测、一键启停）。
- 🧩 **动态服务插槽卡片**：
  - 首期内置 **Twitter / X 视频解析** 服务卡片；
  - 架构完全插件化，未来添加新服务仅需挂载模块，UI 自动呈现，**无需重构或大改界面**。
- 🔋 **Android 原生前台保活**：系统通知栏常驻控制卡片，支持锁屏防休眠。

---

## 🛠️ 构建与编译指南

### 1. 检查 Flutter 环境
```bash
flutter doctor
```

### 2. 获取依赖
```bash
flutter pub get
```

### 3. 一键编译 Release APK
```bash
flutter build apk --release
```
编译产物位于：`build/app/outputs/flutter-apk/app-release.apk`
