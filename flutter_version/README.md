# 📱 TGBot Flutter Android 独立应用

基于 Google Flutter 构建的 Telegram 机器人 Android 原生后台常驻应用。拥有现代化 Material 3 图形交互界面、插槽式服务扩展架构以及 7×24 小时系统级前台保活能力。

---

## ✨ 核心特性

- 🎨 **现代化图形界面**：告别命令行与 Termux 黑框，提供清晰直观的运行状态、在线时长、处理计数与一键启停大开关。
- ⚙️ **独立配置面板**：Telegram 凭据统一收纳于设置页，支持一键测试 Token 有效性并实时读取机器人用户名。
- 🧩 **动态插槽式服务扩展**：
  - 首期搭载 **Twitter / X 视频解析服务**（自动探测最高画质、文件体积、生成规范中文文件名、支持 Telegram 聊天内按需推送）。
  - 底层基于插件总线设计，未来新增任何消息回复功能只需在代码中注册模块，**界面自动流式追加新卡片，无需重新设计或大改 UI**。
- 🔋 **7×24 小时系统级保活**：
  - 基于 Android 系统前台服务（Foreground Service）常驻通知栏控制器；
  - 智能持有 CPU 防休眠锁（WakeLock）；
  - 提供系统电池优化白名单一键引导与自启动适配。
- 📦 **纯 Dart 高效架构**：告别繁重的 Python 解释器打包，单架构 APK 体积仅 **15MB ~ 18MB**，冷启动秒开。

---

## 📦 安装包下载 (32 位 / 64 位独立精简包)

安装包位于根目录 `apk/` 以及 `flutter_version/release_apks/`：

| 安装包文件 | 目标 CPU 架构 | 适用设备 | 单包大小 |
| :--- | :--- | :--- | :--- |
| **`TGBot_64bit_arm64.apk`** | `arm64-v8a` | **99% 的现代主流安卓手机**（推荐） | **~18 MB** |
| **`TGBot_32bit_arm.apk`** | `armeabi-v7a` | 早期 32 位老旧安卓备用机 | **~15 MB** |

👉 也可在 [GitHub Releases 最新发布页](https://github.com/MrcolorH/TGBot/releases/latest) 直接下载 APK。

---

## 📲 安装与使用指南

### 1. 安装到手机
电脑连接手机后，可通过 ADB 一键安装：
```bash
# 64 位主流手机：
adb install -r apk/TGBot_64bit_arm64.apk

# 32 位老旧机型：
adb install -r apk/TGBot_32bit_arm.apk
```
*（也可以直接将 APK 传到手机上点击安装包进行系统安装）*

### 2. 使用步骤
1. 打开应用，点击右上角 **⚙️ 设置** 图标进入配置页；
2. 填入从 Telegram 官方 `@BotFather` 申请的 **Bot Token**，点击【测试有效性】完成校验并保存；
3. 返回首页，点击显目的 **【启动机器人服务】** 按钮；
4. 通知栏将出现常驻保活卡片，服务进入监听状态；
5. 向你的 Telegram 机器人发送任意一条包含推特视频的推文链接，即可秒级获取封面卡片与最高清晰度直链！

---

## 🧩 如何拓展新增功能（未来开发者指南）

本应用采用**数据驱动的插槽架构**，未来如果你想添加如“YouTube 下载”、“AI 聊天”、“定时早报”等新模块：

1. 在 `lib/modules/` 下新建模块文件，实现抽象接口 `BotServiceModule`：
   ```dart
   class MyNewModule extends BotServiceModule {
     @override
     String get id => 'my_module';
     @override
     String get name => '新功能名称';
     @override
     String get description => '功能简介';
     @override
     IconData get icon => Icons.extension_rounded;
     // 实现 canHandle、handleMessage 等核心业务
   }
   ```
2. 在 `lib/modules/service_registry.dart` 中注册它：
   ```dart
   register(MyNewModule());
   ```
3. **完成！** UI 会自动在首页动态渲染新卡片、独立开关与展开配置，无需修改任何界面代码。

---

## 🛠️ 本地编译与打包

```bash
# 1. 确保 Flutter 3.x 环境就绪
flutter doctor

# 2. 一键编译生成 32位 与 64位 独立包
bash build_apks.sh

# 3. 仅编译 64 位版本
bash build_apks.sh 64
```
