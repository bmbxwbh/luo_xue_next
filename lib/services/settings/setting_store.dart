import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/enums.dart';

/// 应用设置状态
class SettingStore extends ChangeNotifier {
  // 基本设置
  MusicSource _defaultSource = MusicSource.mg;
  String _apiHost = '';
  int _apiPort = 0;
  bool _isDarkMode = false;
  bool _followSystem = true; // 默认跟随系统
  String _themeColor = 'blue';

  // 播放设置
  Quality _quality = Quality.k320;
  PlayMode _playMode = PlayMode.listLoop;
  double _volume = 1.0;
  double _speed = 1.0;
  int _maxCacheMB = 500;
  bool _autoPlayNext = true;

  // 搜索设置
  bool _enableHotSearch = true;
  bool _saveSearchHistory = true;

  // 列表设置
  bool _showAlbumName = true;
  bool _showDuration = true;
  bool _showSourceTag = true;

  // 定时停止 & 洛雪缺失设置项
  String _timeoutExit = ''; // 定时退出时间, 如 "30" 表示30分钟
  bool _timeoutExitPlayed = true; // 定时结束后播放完当前歌
  bool _isSavePlayTime = false; // 保存播放进度
  bool _isShowLyricTranslation = false; // 显示歌词翻译
  bool _isShowLyricRoma = false; // 显示歌词罗马音
  bool _isHandleAudioFocus = true; // 音频焦点
  bool _isAutoCleanPlayedList = false; // 自动清理已播放列表
  bool _disclaimerAccepted = false; // 免责协议已同意

  final Completer<void> _initCompleter = Completer<void>();
  bool _initialized = false;

  SettingStore() {
    _loadSettings();
  }

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 等待设置加载完成
  Future<void> init() async {
    if (_initialized) return;
    return _initCompleter.future;
  }

  // Getters
  MusicSource get defaultSource => _defaultSource;
  String get apiHost => _apiHost;
  int get apiPort => _apiPort;
  bool get isDarkMode => _isDarkMode;
  bool get followSystem => _followSystem;
  String get themeColor => _themeColor;

  /// 主题模式: system / light / dark
  String get themeMode {
    if (_followSystem) return 'system';
    return _isDarkMode ? 'dark' : 'light';
  }
  Quality get quality => _quality;
  PlayMode get playMode => _playMode;
  double get volume => _volume;
  double get speed => _speed;
  int get maxCacheMB => _maxCacheMB;
  bool get autoPlayNext => _autoPlayNext;
  bool get enableHotSearch => _enableHotSearch;
  bool get saveSearchHistory => _saveSearchHistory;
  bool get showAlbumName => _showAlbumName;
  bool get showDuration => _showDuration;
  bool get showSourceTag => _showSourceTag;
  String get timeoutExit => _timeoutExit;
  bool get timeoutExitPlayed => _timeoutExitPlayed;
  bool get isSavePlayTime => _isSavePlayTime;
  bool get isShowLyricTranslation => _isShowLyricTranslation;
  bool get isShowLyricRoma => _isShowLyricRoma;
  bool get isHandleAudioFocus => _isHandleAudioFocus;
  bool get isAutoCleanPlayedList => _isAutoCleanPlayedList;
  bool get disclaimerAccepted => _disclaimerAccepted;

  void setDefaultSource(MusicSource v) {
    _defaultSource = v;
    _saveAndNotify();
  }

  void setApiHost(String v) {
    _apiHost = v;
    _saveAndNotify();
  }

  void setApiPort(int v) {
    _apiPort = v;
    _saveAndNotify();
  }

  void setDarkMode(bool v) {
    _isDarkMode = v;
    _followSystem = false;
    _saveAndNotify();
  }

  void setFollowSystem(bool v) {
    _followSystem = v;
    _saveAndNotify();
  }

  void setThemeColor(String v) {
    _themeColor = v;
    _saveAndNotify();
  }

  void setThemeMode(String mode) {
    switch (mode) {
      case 'system':
        _followSystem = true;
        _isDarkMode = false;
      case 'light':
        _followSystem = false;
        _isDarkMode = false;
      case 'dark':
        _followSystem = false;
        _isDarkMode = true;
    }
    _saveAndNotify();
  }

  void setQuality(Quality v) {
    _quality = v;
    _saveAndNotify();
  }

  void setPlayMode(PlayMode v) {
    _playMode = v;
    _saveAndNotify();
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _saveAndNotify();
  }

  void setSpeed(double v) {
    _speed = v.clamp(0.5, 3.0);
    _saveAndNotify();
  }

  void setMaxCacheMB(int v) {
    _maxCacheMB = v;
    _saveAndNotify();
  }

  void setAutoPlayNext(bool v) {
    _autoPlayNext = v;
    _saveAndNotify();
  }

  void setEnableHotSearch(bool v) {
    _enableHotSearch = v;
    _saveAndNotify();
  }

  void setSaveSearchHistory(bool v) {
    _saveSearchHistory = v;
    _saveAndNotify();
  }

  void setShowAlbumName(bool v) {
    _showAlbumName = v;
    _saveAndNotify();
  }

  void setShowDuration(bool v) {
    _showDuration = v;
    _saveAndNotify();
  }

  void setShowSourceTag(bool v) {
    _showSourceTag = v;
    _saveAndNotify();
  }

  void setTimeoutExit(String v) {
    _timeoutExit = v;
    _saveAndNotify();
  }

  void setTimeoutExitPlayed(bool v) {
    _timeoutExitPlayed = v;
    _saveAndNotify();
  }

  void setIsSavePlayTime(bool v) {
    _isSavePlayTime = v;
    _saveAndNotify();
  }

  void setIsShowLyricTranslation(bool v) {
    _isShowLyricTranslation = v;
    _saveAndNotify();
  }

  void setIsShowLyricRoma(bool v) {
    _isShowLyricRoma = v;
    _saveAndNotify();
  }

  void setIsHandleAudioFocus(bool v) {
    _isHandleAudioFocus = v;
    _saveAndNotify();
  }

  void setIsAutoCleanPlayedList(bool v) {
    _isAutoCleanPlayedList = v;
    _saveAndNotify();
  }

  void setDisclaimerAccepted(bool v) {
    _disclaimerAccepted = v;
    _saveAndNotify();
  }

  void _saveAndNotify() {
    notifyListeners();
    _saveSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultSource = MusicSource.fromId(prefs.getString('defaultSource') ?? 'mg');
    _apiHost = prefs.getString('apiHost') ?? '';
    _apiPort = prefs.getInt('apiPort') ?? 0;
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _followSystem = prefs.getBool('followSystem') ?? true;
    _themeColor = prefs.getString('themeColor') ?? 'blue';
    _quality = Quality.fromString(prefs.getString('quality') ?? '320k');
    _playMode = PlayMode.fromString(prefs.getString('playMode') ?? 'listLoop');
    _volume = prefs.getDouble('volume') ?? 1.0;
    _speed = prefs.getDouble('speed') ?? 1.0;
    _maxCacheMB = prefs.getInt('maxCacheMB') ?? 500;
    _autoPlayNext = prefs.getBool('autoPlayNext') ?? true;
    _enableHotSearch = prefs.getBool('enableHotSearch') ?? true;
    _saveSearchHistory = prefs.getBool('saveSearchHistory') ?? true;
    _showAlbumName = prefs.getBool('showAlbumName') ?? true;
    _showDuration = prefs.getBool('showDuration') ?? true;
    _showSourceTag = prefs.getBool('showSourceTag') ?? true;
    _timeoutExit = prefs.getString('timeoutExit') ?? '';
    _timeoutExitPlayed = prefs.getBool('timeoutExitPlayed') ?? true;
    _isSavePlayTime = prefs.getBool('isSavePlayTime') ?? false;
    _isShowLyricTranslation = prefs.getBool('isShowLyricTranslation') ?? false;
    _isShowLyricRoma = prefs.getBool('isShowLyricRoma') ?? false;
    _isHandleAudioFocus = prefs.getBool('isHandleAudioFocus') ?? true;
    _isAutoCleanPlayedList = prefs.getBool('isAutoCleanPlayedList') ?? false;
    _disclaimerAccepted = prefs.getBool('disclaimerAccepted') ?? false;
    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultSource', _defaultSource.id);
    await prefs.setString('apiHost', _apiHost);
    await prefs.setInt('apiPort', _apiPort);
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setBool('followSystem', _followSystem);
    await prefs.setString('themeColor', _themeColor);
    await prefs.setString('quality', _quality.value);
    await prefs.setString('playMode', _playMode.value);
    await prefs.setDouble('volume', _volume);
    await prefs.setDouble('speed', _speed);
    await prefs.setInt('maxCacheMB', _maxCacheMB);
    await prefs.setBool('autoPlayNext', _autoPlayNext);
    await prefs.setBool('enableHotSearch', _enableHotSearch);
    await prefs.setBool('saveSearchHistory', _saveSearchHistory);
    await prefs.setBool('showAlbumName', _showAlbumName);
    await prefs.setBool('showDuration', _showDuration);
    await prefs.setBool('showSourceTag', _showSourceTag);
    await prefs.setString('timeoutExit', _timeoutExit);
    await prefs.setBool('timeoutExitPlayed', _timeoutExitPlayed);
    await prefs.setBool('isSavePlayTime', _isSavePlayTime);
    await prefs.setBool('isShowLyricTranslation', _isShowLyricTranslation);
    await prefs.setBool('isShowLyricRoma', _isShowLyricRoma);
    await prefs.setBool('isHandleAudioFocus', _isHandleAudioFocus);
    await prefs.setBool('isAutoCleanPlayedList', _isAutoCleanPlayedList);
    await prefs.setBool('disclaimerAccepted', _disclaimerAccepted);
  }
}
