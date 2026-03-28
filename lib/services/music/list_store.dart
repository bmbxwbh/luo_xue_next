import 'package:flutter/foundation.dart';
import '../../models/user_list.dart';

/// 歌单列表管理
class ListStore extends ChangeNotifier {
  final Map<String, UserList> _lists = {};
  String _activeListId = 'default';

  ListStore() {
    _lists['default'] = UserList.defaultList();
    _lists['love'] = UserList.loveList();
    _lists['temp'] = UserList.tempList();
  }

  List<UserList> get allLists => _lists.values.toList();
  String get activeListId => _activeListId;
  UserList? get activeList => _lists[_activeListId];
  UserList? get defaultList => _lists['default'];
  UserList? get loveList => _lists['love'];

  /// 用户创建的歌单（非默认）
  List<UserList> get userLists =>
      _lists.values.where((l) => !l.isDefault).toList();

  void setActiveList(String id) {
    _activeListId = id;
    notifyListeners();
  }

  void addList(UserList list) {
    _lists[list.id] = list;
    notifyListeners();
  }

  void createList(String name) {
    final id = 'list_${DateTime.now().millisecondsSinceEpoch}';
    _lists[id] = UserList(id: id, name: name, source: null);
    notifyListeners();
  }

  void removeList(String id) {
    final list = _lists[id];
    if (list != null && !list.isDefault) {
      _lists.remove(id);
      if (_activeListId == id) {
        _activeListId = 'default';
      }
      notifyListeners();
    }
  }

  void renameList(String id, String newName) {
    final list = _lists[id];
    if (list != null) {
      _lists[id] = list.copyWith(name: newName);
      notifyListeners();
    }
  }

  void addSongToList(String listId, String musicId) {
    final list = _lists[listId];
    if (list != null) {
      _lists[listId] = list.addMusic(musicId);
      notifyListeners();
    }
  }

  void removeSongFromList(String listId, String musicId) {
    final list = _lists[listId];
    if (list != null) {
      _lists[listId] = list.removeMusic(musicId);
      notifyListeners();
    }
  }

  UserList? getList(String id) => _lists[id];

  bool isInList(String listId, String musicId) {
    final list = _lists[listId];
    return list?.musicIds.contains(musicId) ?? false;
  }
}
