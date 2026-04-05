import 'package:flutter/foundation.dart';
import '../../models/enums.dart';
import '../../music_sdk/index.dart';

/// 热搜数据管理
class HotSearchStore extends ChangeNotifier {
  List<String> _hotList = [];
  MusicSource _source = MusicSource.kw;
  bool _isLoading = false;

  List<String> get hotList => List.unmodifiable(_hotList);
  MusicSource get source => _source;
  bool get isLoading => _isLoading;

  void setSource(MusicSource src) {
    _source = src;
    notifyListeners();
    loadHotSearch();
  }

  Future<void> loadHotSearch() async {
    _isLoading = true;
    notifyListeners();

    try {
      _hotList = await MusicSdk.getHotSearch(_source);
    } catch (e) {
      // fallback 模拟数据
      _hotList = [
        '周杰伦', '林俊杰', '薛之谦', '毛不易', '陈奕迅',
        '邓紫棋', '李荣浩', '华晨宇', '张杰', '赵雷',
      ];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<String>> getSuggestions(String keyword) async {
    if (keyword.isEmpty) return [];
    try {
      return await MusicSdk.getTipSearch(_source, keyword);
    } catch (_) {
      // fallback: 从热搜筛选
      return _hotList.where((s) => s.contains(keyword)).take(10).toList();
    }
  }
}
