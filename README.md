# 洛雪音乐 Next（LX Music Next）

> 基于 Flutter 重写的洛雪音乐，致敬原项目 [lx-music-mobile](https://github.com/lyswhut/lx-music-mobile)

## 📖 项目简介

洛雪音乐 Next 是一款跨平台音乐播放器，使用 Flutter 框架重写。本项目继承了洛雪音乐的核心理念——**聚合多平台音源、免费畅听高品质音乐**，同时利用 Flutter 的跨平台优势，为用户提供更流畅、更一致的体验。

**本项目代码逻辑和音源系统完全引用自洛雪音乐原项目**，在此对原作者 [lyswhut](https://github.com/lyswhut) 及所有贡献者表示诚挚的感谢。

## 🎯 支持平台

- ✅ Android（主要开发平台）
- 🔜 iOS（计划中）
- 🔜 桌面端（计划中）

## 🎵 功能特性

### 核心功能
- **多平台音源聚合**：支持网易云音乐、QQ 音乐、酷狗、酷我、咪咕等主流平台
- **用户 API 音源**：支持加载第三方 JavaScript 插件扩展音源
- **高品质播放**：支持标准/高品/无损音质播放
- **歌词同步**：逐行歌词实时同步显示
- **歌单管理**：支持在线歌单、本地收藏、自定义歌单
- **搜索功能**：歌曲、歌手、专辑、歌单搜索
- **排行榜**：多平台热门榜单
- **下载管理**：歌曲下载到本地

### 用户体验
- Material Design 3 设计语言
- 深色/浅色主题切换
- 播放详情页动画效果
- 全局搜索热词推荐
- 不喜欢列表（过滤不喜欢的歌曲）

## 🏗️ 技术架构

```
lib/
├── core/           # 核心业务逻辑（搜索、播放、下载）
├── models/         # 数据模型（歌曲、歌单、歌词等）
├── screens/        # 页面（首页、搜索、播放详情、设置等）
├── services/       # 服务层（播放器、用户 API、设置等）
├── store/          # 状态管理（Provider）
├── utils/          # 工具类（加密、HTTP、格式化等）
├── widgets/        # 通用组件
└── music_sdk/      # 音乐 SDK（各平台 API 封装）
```

### 技术栈
- **框架**：Flutter 3.x + Dart 3.x
- **状态管理**：Provider
- **音频播放**：just_audio
- **持久化**：shared_preferences
- **HTTP 请求**：http + 自封装 HttpClient
- **加密**：encrypt + crypto（网易云 eapi 加密等）

## 📦 用户 API 音源系统

洛雪音乐 Next 支持加载第三方 JavaScript 插件作为音源。插件系统基于原项目的 QuickJS 方案，在 Flutter 端使用 flutter_js 运行 JS 脚本。

### 插件结构
```
lib/services/user_api/
├── user_api_preload.dart   # 预加载脚本
├── user_api_runtime.dart   # 运行时（JS ↔ Dart 事件通信）
├── user_api_manager.dart   # 管理器
└── user_api.dart           # 用户 API 封装
```

### 支持的插件格式
- ikun.js 格式
- 洛雪独家音源格式

详细设计文档请参考 [docs/lx_source_system.md](docs/lx_source_system.md)

## 🚀 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK（Android 开发）
- JDK 17

### 安装依赖
```bash
flutter pub get
```

### 运行
```bash
flutter run
```

### 构建 APK
```bash
flutter build apk --release
```

## 📚 引用与致谢

### 核心引用项目

| 项目 | 说明 | 地址 |
|------|------|------|
| **lx-music-mobile** | 洛雪音乐移动端原项目，本项目的代码逻辑、音源系统、UI 设计均基于此项目 | [GitHub](https://github.com/lyswhut/lx-music-mobile) |
| **lx-music-desktop** | 洛雪音乐桌面端，提供设计参考 | [GitHub](https://github.com/lyswhut/lx-music-desktop) |

### 关键依赖

| 依赖 | 用途 | 版本 |
|------|------|------|
| [flutter_js](https://pub.dev/packages/flutter_js) | JavaScript 运行时，用于执行用户 API 音源插件 | 最新 |
| [just_audio](https://pub.dev/packages/just_audio) | 音频播放引擎 | ^0.9.46 |
| [provider](https://pub.dev/packages/provider) | 状态管理 | ^6.1.5 |
| [encrypt](https://pub.dev/packages/encrypt) | 加密工具（网易云 eapi 等） | ^5.0.3 |
| [permission_handler](https://pub.dev/packages/permission_handler) | 权限管理 | ^11.4.0 |

### 音源系统引用说明

本项目的音源系统**完全引用自洛雪音乐原项目**，包括：

1. **内置音源 API 调用逻辑**：网易云、QQ 音乐、酷狗、酷我等平台的 API 封装
2. **用户 API 插件系统**：基于 QuickJS/flutter_js 的 JavaScript 插件执行框架
3. **预加载脚本**：`user_api_preload.js` 直接引用自原项目的 `script/user-api-preload.js`
4. **加密算法**：网易云 eapi 加密、酷狗 API 签名等

原项目仓库：https://github.com/lyswhut/lx-music-mobile

## ⚖️ 免责声明

1. 本项目仅供学习交流使用，不得用于商业用途
2. 本项目引用的音源 API 逻辑版权归原作者所有
3. 使用本项目产生的任何法律责任由用户自行承担
4. 如有侵权，请联系删除

## 📄 许可证

本项目遵循 [Apache License 2.0](LICENSE) 开源协议。

## 🔗 相关链接

- 洛雪音乐官网：https://lxmusic.toside.cn
- 原项目 Issue：https://github.com/lyswhut/lx-music-mobile/issues
- 本项目 GitHub：https://github.com/bmbxwbh/luo_xue_next
- 本项目 Gitee：https://gitee.com/bmbxwbh/luo_xue_next
