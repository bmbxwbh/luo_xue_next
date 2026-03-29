import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 均衡器频段数据
class EqualizerBand {
  final int bandIndex;
  final int centerFreq; // Hz
  final int minLevel; // mB (milliBel)
  final int maxLevel; // mB
  int currentLevel; // mB

  EqualizerBand({
    required this.bandIndex,
    required this.centerFreq,
    required this.minLevel,
    required this.maxLevel,
    this.currentLevel = 0,
  });

  /// 转换为 dB 值显示
  double get levelInDb => currentLevel / 100.0;

  /// 频率显示文本
  String get freqLabel {
    if (centerFreq >= 1000) {
      return '${centerFreq ~/ 1000}kHz';
    }
    return '${centerFreq}Hz';
  }

  Map<String, dynamic> toJson() => {
    'bandIndex': bandIndex,
    'centerFreq': centerFreq,
    'minLevel': minLevel,
    'maxLevel': maxLevel,
    'currentLevel': currentLevel,
  };

  factory EqualizerBand.fromJson(Map<String, dynamic> json) {
    return EqualizerBand(
      bandIndex: json['bandIndex'] as int,
      centerFreq: json['centerFreq'] as int,
      minLevel: json['minLevel'] as int,
      maxLevel: json['maxLevel'] as int,
      currentLevel: json['currentLevel'] as int? ?? 0,
    );
  }
}

/// 均衡器预设
class EqualizerPreset {
  final String name;
  final List<int> bandLevels; // 每个频段的 mB 值

  const EqualizerPreset({
    required this.name,
    required this.bandLevels,
  });
}

/// 均衡器服务
/// 
/// 封装 Android Equalizer AudioEffect，提供频段调节和预设切换功能。
/// 数据层使用 SharedPreferences 持久化，UI 层通过 ChangeNotifier 响应更新。
class EqualizerService extends ChangeNotifier {
  static const String _prefsKey = 'equalizer_settings';
  
  // 标准 5 频段均衡器频率 (Hz)
  static const List<int> defaultBandFreqs = [60, 230, 910, 3600, 14000];
  
  // 频段范围 (mB)，Android Equalizer 标准范围
  static const int defaultMinLevel = -1500; // -15 dB
  static const int defaultMaxLevel = 1500;  // +15 dB

  /// 内置预设 (频段级别为 mB 值)
  static const List<EqualizerPreset> presets = [
    EqualizerPreset(
      name: 'Normal',
      bandLevels: [0, 0, 0, 0, 0],
    ),
    EqualizerPreset(
      name: 'Rock',
      bandLevels: [500, 300, -300, -200, 400],
    ),
    EqualizerPreset(
      name: 'Pop',
      bandLevels: [-200, 400, 500, 400, -200],
    ),
    EqualizerPreset(
      name: 'Jazz',
      bandLevels: [400, 300, 100, 200, -200],
    ),
    EqualizerPreset(
      name: 'Classical',
      bandLevels: [500, 400, 300, 400, 500],
    ),
    EqualizerPreset(
      name: 'Dance',
      bandLevels: [600, 400, 200, 0, 0],
    ),
    EqualizerPreset(
      name: 'Heavy Metal',
      bandLevels: [500, 300, 0, 300, 500],
    ),
    EqualizerPreset(
      name: 'Hip Hop',
      bandLevels: [500, 400, -100, 200, 300],
    ),
    EqualizerPreset(
      name: 'Bass Boost',
      bandLevels: [800, 500, 0, 0, 0],
    ),
  ];

  List<EqualizerBand> _bands = [];
  int _currentPresetIndex = 0;
  bool _isEnabled = true;
  bool _initialized = false;

  EqualizerService();

  List<EqualizerBand> get bands => _bands;
  int get currentPresetIndex => _currentPresetIndex;
  bool get isEnabled => _isEnabled;
  bool get initialized => _initialized;

  /// 初始化均衡器
  Future<void> init() async {
    if (_initialized) return;

    // 创建默认频段
    _bands = defaultBandFreqs.asMap().entries.map((entry) {
      return EqualizerBand(
        bandIndex: entry.key,
        centerFreq: entry.value,
        minLevel: defaultMinLevel,
        maxLevel: defaultMaxLevel,
        currentLevel: 0,
      );
    }).toList();

    // 从 SharedPreferences 加载保存的设置
    await _loadSettings();
    
    _initialized = true;
    notifyListeners();
  }

  /// 从 SharedPreferences 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        
        _isEnabled = data['isEnabled'] as bool? ?? true;
        _currentPresetIndex = data['currentPresetIndex'] as int? ?? 0;
        
        if (data['bands'] != null) {
          final bandsJson = data['bands'] as List<dynamic>;
          _bands = bandsJson
              .map((b) => EqualizerBand.fromJson(b as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[Equalizer] 加载设置失败: $e');
    }
  }

  /// 保存设置到 SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'isEnabled': _isEnabled,
        'currentPresetIndex': _currentPresetIndex,
        'bands': _bands.map((b) => b.toJson()).toList(),
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[Equalizer] 保存设置失败: $e');
    }
  }

  /// 设置频段级别
  Future<void> setBandLevel(int bandIndex, int level) async {
    if (bandIndex < 0 || bandIndex >= _bands.length) return;

    // 限制范围
    final band = _bands[bandIndex];
    level = level.clamp(band.minLevel, band.maxLevel);
    band.currentLevel = level;

    // 自动切换到自定义预设
    _currentPresetIndex = -1;
    
    notifyListeners();
    await _saveSettings();
  }

  /// 应用预设
  Future<void> applyPreset(int presetIndex) async {
    if (presetIndex < 0 || presetIndex >= presets.length) return;

    final preset = presets[presetIndex];
    for (int i = 0; i < _bands.length && i < preset.bandLevels.length; i++) {
      _bands[i].currentLevel = preset.bandLevels[i];
    }

    _currentPresetIndex = presetIndex;
    
    notifyListeners();
    await _saveSettings();
  }

  /// 重置均衡器
  Future<void> reset() async {
    for (final band in _bands) {
      band.currentLevel = 0;
    }
    _currentPresetIndex = 0;
    
    notifyListeners();
    await _saveSettings();
  }

  /// 启用/禁用均衡器
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    notifyListeners();
    await _saveSettings();
  }

  /// 获取当前频段级别列表 (用于外部应用)
  List<int> get currentBandLevels => _bands.map((b) => b.currentLevel).toList();

  /// 检查当前是否为自定义设置
  bool get isCustom => _currentPresetIndex == -1;

  @override
  void dispose() {
    _bands.clear();
    super.dispose();
  }
}
