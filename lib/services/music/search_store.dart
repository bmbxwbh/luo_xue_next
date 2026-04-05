import 'package:flutter/foundation.dart';
import '../../models/enums.dart';

/// 搜索状态管理
class SearchStore extends ChangeNotifier {
  final List<String> _history = [];
  String _keyword = '';
  MusicSource _source = MusicSource.kw;
  bool _isSearching = false;
  String _searchType = 'music'; // music / songlist
  int _currentPage = 1;
  int _totalPage = 1;

  List<String> get history => List.unmodifiable(_history);
  String get keyword => _keyword;
  MusicSource get source => _source;
  bool get isSearching => _isSearching;
  String get searchType => _searchType;
  int get currentPage => _currentPage;
  int get totalPage => _totalPage;

  void setKeyword(String kw) {
    _keyword = kw;
    notifyListeners();
  }

  void setSource(MusicSource src) {
    _source = src;
    notifyListeners();
  }

  void setSearchType(String type) {
    _searchType = type;
    notifyListeners();
  }

  void setSearching(bool val) {
    _isSearching = val;
    notifyListeners();
  }

  void setPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  void setTotalPage(int total) {
    _totalPage = total;
    notifyListeners();
  }

  void addHistory(String kw) {
    if (kw.isEmpty) return;
    _history.remove(kw);
    _history.insert(0, kw);
    if (_history.length > 50) _history.removeLast();
    notifyListeners();
  }

  void removeHistory(String kw) {
    _history.remove(kw);
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  void clearKeyword() {
    _keyword = '';
    notifyListeners();
  }
}
