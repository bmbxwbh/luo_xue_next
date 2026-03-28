import 'package:flutter/foundation.dart';
import '../models/enums.dart';

/// 热搜状态管理 — 对齐 LX Music store/hotSearch/state.ts
class HotSearchStore extends ChangeNotifier {
  /// 支持热搜的音源列表
  final List<MusicSource> _sources = [];
  List<MusicSource> get sources => List.unmodifiable(_sources);

  /// 各音源的热搜词列表
  final Map<String, List<String>> _sourceList = {};
  Map<String, List<String>> get sourceList => _sourceList;

  /// 全部音源热搜
  final List<String> _allList = [];
  List<String> get allList => List.unmodifiable(_allList);

  // ============ Mutations ============

  void setSources(List<MusicSource> sources) {
    _sources.clear();
    _sources.addAll(sources);
    notifyListeners();
  }

  void addSource(MusicSource source) {
    if (!_sources.contains(source)) {
      _sources.add(source);
      notifyListeners();
    }
  }

  void setSourceList(String sourceId, List<String> list) {
    _sourceList[sourceId] = list;
    notifyListeners();
  }

  void setAllList(List<String> list) {
    _allList.clear();
    _allList.addAll(list);
    notifyListeners();
  }

  /// 清除某个音源的热搜
  void clearSource(String sourceId) {
    _sourceList.remove(sourceId);
    notifyListeners();
  }

  /// 清除全部
  void clearAll() {
    _sourceList.clear();
    _allList.clear();
    notifyListeners();
  }

  /// 获取指定音源的热搜
  List<String> getHotSearch(String sourceId) {
    return _sourceList[sourceId] ?? [];
  }
}
