import 'package:flutter/foundation.dart';
import '../models/enums.dart';

/// 搜索类型
enum SearchType { music, songlist }

/// 搜索提示信息
class TipListInfo {
  final String text;
  final MusicSource source;
  final List<String> list;

  const TipListInfo({
    this.text = '',
    this.source = MusicSource.kw,
    this.list = const [],
  });

  TipListInfo copyWith({String? text, MusicSource? source, List<String>? list}) {
    return TipListInfo(
      text: text ?? this.text,
      source: source ?? this.source,
      list: list ?? this.list,
    );
  }
}

/// 搜索状态管理 — 对齐 LX Music store/search/state.ts
class SearchStore extends ChangeNotifier {
  /// 当前搜索源（临时）
  MusicSource _tempSource = MusicSource.mg;
  MusicSource get tempSource => _tempSource;

  /// 搜索类型
  SearchType _searchType = SearchType.music;
  SearchType get searchType => _searchType;

  /// 搜索关键词
  String _searchText = '';
  String get searchText => _searchText;

  /// 搜索提示信息
  TipListInfo _tipListInfo = const TipListInfo();
  TipListInfo get tipListInfo => _tipListInfo;

  /// 搜索历史
  final List<String> _historyList = [];
  List<String> get historyList => List.unmodifiable(_historyList);

  // ============ Mutations ============

  void setTempSource(MusicSource source) {
    _tempSource = source;
    notifyListeners();
  }

  void setSearchType(SearchType type) {
    _searchType = type;
    notifyListeners();
  }

  void setSearchText(String text) {
    _searchText = text;
    notifyListeners();
  }

  void setTipListInfo(TipListInfo info) {
    _tipListInfo = info;
    notifyListeners();
  }

  void clearTipListInfo() {
    _tipListInfo = const TipListInfo();
    notifyListeners();
  }

  void addHistory(String text) {
    if (text.trim().isEmpty) return;
    _historyList.remove(text);
    _historyList.insert(0, text);
    // 限制历史记录数量
    if (_historyList.length > 50) {
      _historyList.removeRange(50, _historyList.length);
    }
    notifyListeners();
  }

  void removeHistory(String text) {
    _historyList.remove(text);
    notifyListeners();
  }

  void clearHistory() {
    _historyList.clear();
    notifyListeners();
  }

  void setHistoryList(List<String> list) {
    _historyList.clear();
    _historyList.addAll(list);
    notifyListeners();
  }
}
