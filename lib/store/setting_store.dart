import 'package:flutter/foundation.dart';
import '../models/enums.dart';

/// 应用设置模型 — 对齐 LX Music AppSetting
class AppSettings {
  // ====== 通用 ======
  bool isAutoTheme;
  String? langId;
  String apiSource;
  bool isAgreePact;
  bool autoHidePlayBar;
  bool homePageScroll;
  bool allowProgressBarSeek;
  bool showBackBtn;
  bool showExitBtn;
  bool useSystemFileSelector;

  // ====== 播放器 ======
  bool startupAutoPlay;
  bool startupPushPlayDetailScreen;
  PlayMode togglePlayMethod;
  Quality playQuality;
  bool isSavePlayTime;
  double volume;
  double playbackRate;
  String cacheSize;
  String? timeoutExit;
  bool timeoutExitPlayed;
  bool isAutoCleanPlayedList;
  bool isHandleAudioFocus;
  bool isEnableAudioOffload;
  bool isShowLyricTranslation;
  bool isShowLyricRoma;
  bool isShowNotificationImage;
  bool isS2t;
  bool isShowBluetoothLyric;
  bool isPlayHighQuality;

  // ====== 搜索 ======
  bool isShowHotSearch;
  bool isShowHistorySearch;

  // ====== 列表 ======
  bool isClickPlayList;
  bool isShowSource;
  bool isShowAlbumName;
  bool isShowInterval;
  bool isSaveScrollLocation;
  String addMusicLocationType; // 'top' | 'bottom'

  // ====== 下载 ======
  String downloadFileName;

  // ====== 同步 ======
  bool syncEnable;

  // ====== 主题 ======
  String themeId;
  String themeLightId;
  String themeDarkId;
  bool themeHideBgDark;
  bool dynamicBg;
  bool fontShadow;

  AppSettings({
    this.isAutoTheme = false,
    this.langId,
    this.apiSource = '',
    this.isAgreePact = false,
    this.autoHidePlayBar = true,
    this.homePageScroll = true,
    this.allowProgressBarSeek = true,
    this.showBackBtn = false,
    this.showExitBtn = true,
    this.useSystemFileSelector = true,
    this.startupAutoPlay = false,
    this.startupPushPlayDetailScreen = false,
    this.togglePlayMethod = PlayMode.listLoop,
    this.playQuality = Quality.k128,
    this.isSavePlayTime = false,
    this.volume = 1.0,
    this.playbackRate = 1.0,
    this.cacheSize = '1024',
    this.timeoutExit,
    this.timeoutExitPlayed = true,
    this.isAutoCleanPlayedList = false,
    this.isHandleAudioFocus = true,
    this.isEnableAudioOffload = true,
    this.isShowLyricTranslation = false,
    this.isShowLyricRoma = false,
    this.isShowNotificationImage = true,
    this.isS2t = false,
    this.isShowBluetoothLyric = false,
    this.isPlayHighQuality = false,
    this.isShowHotSearch = false,
    this.isShowHistorySearch = false,
    this.isClickPlayList = false,
    this.isShowSource = true,
    this.isShowAlbumName = false,
    this.isShowInterval = true,
    this.isSaveScrollLocation = true,
    this.addMusicLocationType = 'top',
    this.downloadFileName = '歌名 - 歌手',
    this.syncEnable = false,
    this.themeId = 'green',
    this.themeLightId = 'green',
    this.themeDarkId = 'black',
    this.themeHideBgDark = false,
    this.dynamicBg = false,
    this.fontShadow = false,
  });

  /// 从 JSON 创建
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isAutoTheme: json['common.isAutoTheme'] ?? false,
      langId: json['common.langId'],
      apiSource: json['common.apiSource'] ?? '',
      isAgreePact: json['common.isAgreePact'] ?? false,
      autoHidePlayBar: json['common.autoHidePlayBar'] ?? true,
      homePageScroll: json['common.homePageScroll'] ?? true,
      allowProgressBarSeek: json['common.allowProgressBarSeek'] ?? true,
      showBackBtn: json['common.showBackBtn'] ?? false,
      showExitBtn: json['common.showExitBtn'] ?? true,
      useSystemFileSelector: json['common.useSystemFileSelector'] ?? true,
      startupAutoPlay: json['player.startupAutoPlay'] ?? false,
      startupPushPlayDetailScreen: json['player.startupPushPlayDetailScreen'] ?? false,
      togglePlayMethod: PlayMode.fromString(json['player.togglePlayMethod'] ?? 'listLoop'),
      playQuality: Quality.fromString(json['player.playQuality'] ?? '128k'),
      isSavePlayTime: json['player.isSavePlayTime'] ?? false,
      volume: (json['player.volume'] ?? 1.0).toDouble(),
      playbackRate: (json['player.playbackRate'] ?? 1.0).toDouble(),
      cacheSize: json['player.cacheSize']?.toString() ?? '1024',
      timeoutExit: json['player.timeoutExit'],
      timeoutExitPlayed: json['player.timeoutExitPlayed'] ?? true,
      isAutoCleanPlayedList: json['player.isAutoCleanPlayedList'] ?? false,
      isHandleAudioFocus: json['player.isHandleAudioFocus'] ?? true,
      isEnableAudioOffload: json['player.isEnableAudioOffload'] ?? true,
      isShowLyricTranslation: json['player.isShowLyricTranslation'] ?? false,
      isShowLyricRoma: json['player.isShowLyricRoma'] ?? false,
      isShowNotificationImage: json['player.isShowNotificationImage'] ?? true,
      isS2t: json['player.isS2t'] ?? false,
      isShowBluetoothLyric: json['player.isShowBluetoothLyric'] ?? false,
      isPlayHighQuality: json['player.isPlayHighQuality'] ?? false,
      isShowHotSearch: json['search.isShowHotSearch'] ?? false,
      isShowHistorySearch: json['search.isShowHistorySearch'] ?? false,
      isClickPlayList: json['list.isClickPlayList'] ?? false,
      isShowSource: json['list.isShowSource'] ?? true,
      isShowAlbumName: json['list.isShowAlbumName'] ?? false,
      isShowInterval: json['list.isShowInterval'] ?? true,
      isSaveScrollLocation: json['list.isSaveScrollLocation'] ?? true,
      addMusicLocationType: json['list.addMusicLocationType'] ?? 'top',
      downloadFileName: json['download.fileName'] ?? '歌名 - 歌手',
      syncEnable: json['sync.enable'] ?? false,
      themeId: json['theme.id'] ?? 'green',
      themeLightId: json['theme.lightId'] ?? 'green',
      themeDarkId: json['theme.darkId'] ?? 'black',
      themeHideBgDark: json['theme.hideBgDark'] ?? false,
      dynamicBg: json['theme.dynamicBg'] ?? false,
      fontShadow: json['theme.fontShadow'] ?? false,
    );
  }

  /// 转 JSON
  Map<String, dynamic> toJson() => {
        'common.isAutoTheme': isAutoTheme,
        'common.langId': langId,
        'common.apiSource': apiSource,
        'common.isAgreePact': isAgreePact,
        'common.autoHidePlayBar': autoHidePlayBar,
        'common.homePageScroll': homePageScroll,
        'common.allowProgressBarSeek': allowProgressBarSeek,
        'common.showBackBtn': showBackBtn,
        'common.showExitBtn': showExitBtn,
        'common.useSystemFileSelector': useSystemFileSelector,
        'player.startupAutoPlay': startupAutoPlay,
        'player.startupPushPlayDetailScreen': startupPushPlayDetailScreen,
        'player.togglePlayMethod': togglePlayMethod.value,
        'player.playQuality': playQuality.value,
        'player.isSavePlayTime': isSavePlayTime,
        'player.volume': volume,
        'player.playbackRate': playbackRate,
        'player.cacheSize': cacheSize,
        'player.timeoutExit': timeoutExit,
        'player.timeoutExitPlayed': timeoutExitPlayed,
        'player.isAutoCleanPlayedList': isAutoCleanPlayedList,
        'player.isHandleAudioFocus': isHandleAudioFocus,
        'player.isEnableAudioOffload': isEnableAudioOffload,
        'player.isShowLyricTranslation': isShowLyricTranslation,
        'player.isShowLyricRoma': isShowLyricRoma,
        'player.isShowNotificationImage': isShowNotificationImage,
        'player.isS2t': isS2t,
        'player.isShowBluetoothLyric': isShowBluetoothLyric,
        'player.isPlayHighQuality': isPlayHighQuality,
        'search.isShowHotSearch': isShowHotSearch,
        'search.isShowHistorySearch': isShowHistorySearch,
        'list.isClickPlayList': isClickPlayList,
        'list.isShowSource': isShowSource,
        'list.isShowAlbumName': isShowAlbumName,
        'list.isShowInterval': isShowInterval,
        'list.isSaveScrollLocation': isSaveScrollLocation,
        'list.addMusicLocationType': addMusicLocationType,
        'download.fileName': downloadFileName,
        'sync.enable': syncEnable,
        'theme.id': themeId,
        'theme.lightId': themeLightId,
        'theme.darkId': themeDarkId,
        'theme.hideBgDark': themeHideBgDark,
        'theme.dynamicBg': dynamicBg,
        'theme.fontShadow': fontShadow,
      };

  AppSettings copy() => AppSettings.fromJson(toJson());
}

/// 设置状态管理 — 对齐 LX Music store/setting/state.ts
class SettingStore extends ChangeNotifier {
  AppSettings _setting = AppSettings();
  AppSettings get setting => _setting;

  /// 全量替换设置
  void setSetting(AppSettings settings) {
    _setting = settings;
    notifyListeners();
  }

  /// 更新部分设置
  void patchSetting(Map<String, dynamic> patch) {
    final json = _setting.toJson();
    json.addAll(patch);
    _setting = AppSettings.fromJson(json);
    notifyListeners();
  }

  /// 播放模式
  void setTogglePlayMethod(PlayMode mode) {
    _setting.togglePlayMethod = mode;
    notifyListeners();
  }

  /// 音量
  void setVolume(double volume) {
    _setting.volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 播放速率
  void setPlaybackRate(double rate) {
    _setting.playbackRate = rate;
    notifyListeners();
  }

  /// 音质
  void setPlayQuality(Quality quality) {
    _setting.playQuality = quality;
    notifyListeners();
  }

  /// 是否显示歌词翻译
  void setShowLyricTranslation(bool value) {
    _setting.isShowLyricTranslation = value;
    notifyListeners();
  }

  /// 是否显示歌词罗马音
  void setShowLyricRoma(bool value) {
    _setting.isShowLyricRoma = value;
    notifyListeners();
  }

  /// 添加歌曲位置类型
  void setAddMusicLocationType(String type) {
    _setting.addMusicLocationType = type;
    notifyListeners();
  }
}
