/// 全局播放器实例
library;

import 'package:shared_preferences/shared_preferences.dart';
import '../core/player/player.dart';
import '../core/music/online.dart';
import '../store/player_store.dart';
import '../services/settings/setting_store.dart';
import '../services/user_api/user_api_manager.dart';
import '../services/user_api/musicfree_manager.dart';

/// 全局播放器
late final Player globalPlayer;

/// 播放器存储
late final PlayerStore globalPlayerStore;

/// 设置存储
late final SettingStore globalSettingStore;

/// 在线音乐服务
late final OnlineMusicService globalOnlineMusicService;

/// MusicFree 插件管理器
late final MusicFreeManager globalMusicFreeManager;

/// 初始化全局播放器
void initGlobalPlayer({
  required SettingStore settingStore,
  required UserApiManager userApiManager,
  MusicFreeManager? musicFreeManager,
}) {
  globalSettingStore = settingStore;
  globalPlayerStore = PlayerStore();
  globalOnlineMusicService = OnlineMusicService();
  
  // 连接用户 API 管理器
  globalOnlineMusicService.setUserApiManager(userApiManager);

  // 连接 MusicFree 插件管理器
  if (musicFreeManager != null) {
    globalMusicFreeManager = musicFreeManager;
    globalOnlineMusicService.setMusicFreeManager(musicFreeManager);
  }

  // 同步完整 MF 插件模式
  globalOnlineMusicService.setIsFullMfMode(settingStore.isFullMfMode);

  // 同步插件模式（lx / musicfree）
  SharedPreferences.getInstance().then((prefs) {
    final savedMode = prefs.getString('plugin_mode') ?? 'lx';
    globalOnlineMusicService.setPluginMode(savedMode);
  });
  
  globalPlayer = Player(
    playerStore: globalPlayerStore,
    settingStore: globalSettingStore,
    onlineMusicService: globalOnlineMusicService,
  );
  
  // 初始化播放器
  globalPlayer.init();
}
