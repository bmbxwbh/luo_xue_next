import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/song_model.dart';

/// 用户列表信息
class UserListInfo {
  final String id;
  final String name;
  final MusicSource? source;
  final String? sourceListId;
  final int? locationUpdateTime;

  const UserListInfo({
    required this.id,
    required this.name,
    this.source,
    this.sourceListId,
    this.locationUpdateTime,
  });

  UserListInfo copyWith({String? name, MusicSource? source, String? sourceListId, int? locationUpdateTime}) {
    return UserListInfo(
      id: id,
      name: name ?? this.name,
      source: source ?? this.source,
      sourceListId: sourceListId ?? this.sourceListId,
      locationUpdateTime: locationUpdateTime ?? this.locationUpdateTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (source != null) 'source': source!.id,
        if (sourceListId != null) 'sourceListId': sourceListId,
        if (locationUpdateTime != null) 'locationUpdateTime': locationUpdateTime,
      };

  factory UserListInfo.fromJson(Map<String, dynamic> json) {
    return UserListInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      source: json['source'] != null ? MusicSource.fromId(json['source']) : null,
      sourceListId: json['sourceListId'],
      locationUpdateTime: json['locationUpdateTime'],
    );
  }
}

/// 列表ID常量 — 对齐 LX Music LIST_IDS
class ListIds {
  static const String defaultList = 'default';
  static const String love = 'love';
  static const String temp = 'temp';
  static const String download = 'download';
}

/// 歌单状态管理 — 对齐 LX Music store/list/state.ts
class ListStore extends ChangeNotifier {
  /// 全部歌单音乐 Map<listId, List<SongModel>>
  final Map<String, List<SongModel>> _allMusicList = {};
  Map<String, List<SongModel>> get allMusicList => _allMusicList;

  /// 默认列表
  String _defaultListId = ListIds.defaultList;
  String get defaultListId => _defaultListId;
  String _defaultListName = '试听列表';
  String get defaultListName => _defaultListName;

  /// 收藏列表
  String _loveListId = ListIds.love;
  String get loveListId => _loveListId;
  String _loveListName = '我的收藏';
  String get loveListName => _loveListName;

  /// 临时列表
  String _tempListId = ListIds.temp;
  String get tempListId => _tempListId;
  String _tempListMetaId = '';
  String get tempListMetaId => _tempListMetaId;

  /// 用户自定义列表
  final List<UserListInfo> _userList = [];
  List<UserListInfo> get userList => List.unmodifiable(_userList);

  /// 当前激活列表ID
  String _activeListId = '';
  String get activeListId => _activeListId;

  /// 正在获取列表状态
  final Map<String, bool> _fetchingListStatus = {};
  Map<String, bool> get fetchingListStatus => _fetchingListStatus;

  // ============ 工具方法 ============

  /// 获取所有列表ID（默认+收藏+用户列表）
  List<String> get allListIds {
    final ids = [_defaultListId, _loveListId];
    for (final u in _userList) {
      ids.add(u.id);
    }
    return ids;
  }

  /// 获取指定列表的歌曲
  List<SongModel> getListMusics(String listId) {
    return _allMusicList[listId] ?? [];
  }

  /// 获取当前激活列表的歌曲
  List<SongModel> get activeListMusics => getListMusics(_activeListId);

  // ============ Mutations ============

  void setListMusics(String listId, List<SongModel> musics) {
    _allMusicList[listId] = List.from(musics);
    notifyListeners();
  }

  void addMusicsToList(String listId, List<SongModel> musics, {bool addToTop = true}) {
    final list = _allMusicList.putIfAbsent(listId, () => []);
    if (addToTop) {
      list.insertAll(0, musics);
    } else {
      list.addAll(musics);
    }
    notifyListeners();
  }

  void removeMusicFromList(String listId, String musicId) {
    final list = _allMusicList[listId];
    if (list == null) return;
    list.removeWhere((m) => m.id == musicId);
    notifyListeners();
  }

  void removeMusicsFromList(String listId, List<String> musicIds) {
    final list = _allMusicList[listId];
    if (list == null) return;
    final idSet = musicIds.toSet();
    list.removeWhere((m) => idSet.contains(m.id));
    notifyListeners();
  }

  void moveMusicInList(String listId, int fromIndex, int toIndex) {
    final list = _allMusicList[listId];
    if (list == null || fromIndex < 0 || fromIndex >= list.length) return;
    if (toIndex < 0 || toIndex >= list.length) return;
    final item = list.removeAt(fromIndex);
    list.insert(toIndex, item);
    notifyListeners();
  }

  void clearListMusics(String listId) {
    _allMusicList.remove(listId);
    notifyListeners();
  }

  void setActiveList(String listId) {
    _activeListId = listId;
    notifyListeners();
  }

  void addUserList(UserListInfo info) {
    _userList.add(info);
    notifyListeners();
  }

  void addUserLists(List<UserListInfo> infos) {
    _userList.addAll(infos);
    notifyListeners();
  }

  void removeUserList(String id) {
    _userList.removeWhere((u) => u.id == id);
    _allMusicList.remove(id);
    notifyListeners();
  }

  void removeUserLists(List<String> ids) {
    final idSet = ids.toSet();
    _userList.removeWhere((u) => idSet.contains(u.id));
    for (final id in ids) {
      _allMusicList.remove(id);
    }
    notifyListeners();
  }

  void updateUserList(UserListInfo info) {
    final index = _userList.indexWhere((u) => u.id == info.id);
    if (index >= 0) {
      _userList[index] = info;
      notifyListeners();
    }
  }

  void setUserLists(List<UserListInfo> lists) {
    _userList.clear();
    _userList.addAll(lists);
    notifyListeners();
  }

  void updateUserListPosition(int position, List<String> ids) {
    final items = <UserListInfo>[];
    for (final id in ids) {
      final idx = _userList.indexWhere((u) => u.id == id);
      if (idx >= 0) {
        items.add(_userList.removeAt(idx));
      }
    }
    _userList.insertAll(position.clamp(0, _userList.length), items);
    notifyListeners();
  }

  void setTempListMeta(String id) {
    _tempListMetaId = id;
    notifyListeners();
  }

  void setFetchingListStatus(String listId, bool status) {
    _fetchingListStatus[listId] = status;
    notifyListeners();
  }
}
