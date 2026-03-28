/// 全局播放器实例
library;

import '../core/player/player.dart';
import '../core/music/online.dart';
import '../store/player_store.dart';
import '../services/settings/setting_store.dart';
import '../services/user_api/user_api_manager.dart';

/// 全局播放器
late final Player globalPlayer;

/// 播放器存储
late final PlayerStore globalPlayerStore;

/// 设置存储
late final SettingStore globalSettingStore;

/// 在线音乐服务
late final OnlineMusicService globalOnlineMusicService;

/// 初始化全局播放器
void initGlobalPlayer({
  required SettingStore settingStore,
  required UserApiManager userApiManager,
}) {
  globalSettingStore = settingStore;
  globalPlayerStore = PlayerStore();
  globalOnlineMusicService = OnlineMusicService();
  
  // 连接用户 API 管理器
  globalOnlineMusicService.setUserApiManager(userApiManager);
  
  globalPlayer = Player(
    playerStore: globalPlayerStore,
    settingStore: globalSettingStore,
    onlineMusicService: globalOnlineMusicService,
  );
  
  // 初始化播放器
  globalPlayer.init();
}
