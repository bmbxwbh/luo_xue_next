# 浮生音乐（Fu Sheng Music）

> 基于 Flutter 开发的跨平台音乐播放器，致敬 [洛雪音乐](https://github.com/lyswhut/lx-music-mobile) 和 [MusicFree](https://github.com/maotoumao/MusicFree)

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
