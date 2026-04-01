# 浮生音乐（Fu Sheng Music）

> 基于 Flutter 开发的跨平台音乐播放器，致敬 [洛雪音乐](https://github.com/lyswhut/lx-music-mobile) 和 [MusicFree](https://github.com/maotoumao/MusicFree)

---

## 🆘 我们需要帮助

**如果你熟悉洛雪音乐的外部音源（用户 API）系统，或者对 QuickJS / JavaScript 桥接有经验，我们非常需要你的帮助。**

目前项目最大的卡点在于**外部音源插件的数据传递**。我们已经把洛雪原版的预加载脚本、事件通信机制、HTTP 代理、加密工具等都移植到了 Flutter 端，音源插件也能正常加载和初始化，但使用 **洛雪独家音源.js** 实际请求播放链接时，**签名（sign）的计算结果和原版 QuickJS 环境下不一致**，导致无法获取到播放地址。

我们已经做了大量排查：
- ✅ SHA-256 / MD5 算法通过标准测试向量验证
- ✅ musicInfo 数据格式对齐原版 `toOldMusicInfo()` 输出
- ✅ HTTP 请求/响应格式对齐原版
- ✅ 事件通信机制对齐原版（`__pushEvent__` → `__lx_event_queue__` → Dart 轮询）
- ❓ 但在 flutter_js 环境下，插件脚本计算出的 sign 值与原版 QuickJS 环境下不同

**可能的原因：**
- flutter_js 和洛雪原版 QuickJS 在某些 JS 行为上存在细微差异
- 独家音源.js 内部的 SHA-256 实现在 flutter_js 环境下有兼容性问题
- 传入插件的 musicInfo 数据在某些边界情况下和原版不完全一致

**我们希望：**
- 有熟悉洛雪音源系统或 QuickJS 的大佬能帮看看问题出在哪
- 或者有 flutter_js / JavaScriptCore 深度使用经验的朋友能帮忙排查环境差异
- 哪怕只是提供排查思路，对我们来说都非常宝贵

联系方式：直接提 [Issue](https://github.com/bmbxwbh/luo_xue_next/issues) 就好，或者加群交流。我们虽然是两个人的小团队，但态度是认真的，你提的问题我们一定第一时间响应。

**感谢每一个看到这里的人 ❤️**

---

## 📖 项目简介

浮生音乐是一款跨平台音乐播放器，使用 Flutter 框架开发。支持多个音乐平台的搜索与播放，致力于为用户提供简洁、流畅的音乐体验。

### 核心特性
- **多平台音源**：支持网易云音乐、QQ 音乐、酷狗、酷我、咪咕等主流平台
- **双插件系统**：洛雪脚本模式 + MusicFree 插件模式，自由切换
- **用户 API 音源**：支持加载第三方 JavaScript 插件扩展音源
- **高品质播放**：支持标准/高品/无损音质
- **歌词同步**：逐行歌词实时同步显示
- **歌单管理**：在线歌单、本地收藏
- **Material Design 3**：深色/浅色主题切换

## 🎯 支持平台

- ✅ Android（主要开发平台）
- 🔜 iOS / 桌面端（计划中）

## 🚀 快速开始

```bash
flutter pub get
flutter run
```

## 📦 插件系统

浮生音乐支持两种插件模式：

### 洛雪脚本模式
兼容洛雪音乐的外部音源脚本，基于 QuickJS 方案。

### MusicFree 插件模式
兼容 [MusicFree](https://github.com/maotoumao/MusicFree) 格式插件，提供 `require('axios')`、`require('crypto-js')`、`require('cheerio')` 等常用库的桥接。

## 🏗️ 技术架构

- **框架**：Flutter 3.x + Dart 3.x
- **状态管理**：Provider
- **音频播放**：just_audio
- **JS 运行时**：flutter_js
- **图片缓存**：cached_network_image
- **持久化**：shared_preferences

## 📚 致谢

本项目的音源系统和插件架构参考了以下开源项目：

- [lx-music-mobile](https://github.com/lyswhut/lx-music-mobile) — 洛雪音乐移动端
- [MusicFree](https://github.com/maotoumao/MusicFree) — MusicFree 插件系统

感谢原作者和所有贡献者 ❤️

## ⚖️ 免责声明

1. 本项目仅供学习交流使用，不得用于商业用途
2. 使用本项目产生的任何法律责任由用户自行承担
3. 如有侵权，请联系删除

## 🔗 链接

- GitHub：https://github.com/bmbxwbh/luo_xue_next
- Gitee：https://gitee.com/bmbxwbh/luo_xue_next
