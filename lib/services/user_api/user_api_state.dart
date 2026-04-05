/// 用户 API 状态管理 — 对齐 LX Music store/userApi/
library;

import 'package:flutter/foundation.dart';
import 'user_api_info.dart';

/// 用户 API 状态
class UserApiState extends ChangeNotifier {
  /// API 列表
  List<UserApiInfo> _list = [];
  List<UserApiInfo> get list => List.unmodifiable(_list);

  /// 当前状态
  bool _status = false;
  bool get status => _status;

  /// 状态消息
  String? _message;
  String? get message => _message;

  /// 当前选中的 API ID
  String? _currentApiId;
  String? get currentApiId => _currentApiId;

  /// 当前 API 信息
  UserApiInfo? get currentApi {
    if (_currentApiId == null) return null;
    return _list.cast<UserApiInfo?>().firstWhere(
          (api) => api?.id == _currentApiId,
          orElse: () => null,
        );
  }

  /// 已注册的音源 API
  Map<String, UserApiSourceInfo> _apis = {};
  Map<String, UserApiSourceInfo> get apis => Map.unmodifiable(_apis);

  /// 音质列表
  Map<String, List<String>> _qualityList = {};
  Map<String, List<String>> get qualityList => Map.unmodifiable(_qualityList);

  /// 设置 API 列表
  void setList(List<UserApiInfo> list) {
    _list = list;
    notifyListeners();
  }

  /// 添加 API
  void addUserApi(UserApiInfo info) {
    _list.insert(0, info);
    notifyListeners();
  }

  /// 移除 API
  void removeUserApi(String id) {
    _list.removeWhere((api) => api.id == id);
    if (_currentApiId == id) {
      _currentApiId = null;
      _status = false;
      _message = null;
      _apis.clear();
      _qualityList.clear();
    }
    notifyListeners();
  }

  /// 设置状态
  void setStatus(bool status, String? message) {
    _status = status;
    _message = message;
    notifyListeners();
  }

  /// 设置当前 API
  void setCurrentApi(String? id) {
    _currentApiId = id;
    notifyListeners();
  }

  /// 设置已注册的音源
  void setApis(Map<String, UserApiSourceInfo> apis, Map<String, List<String>> qualityList) {
    _apis = apis;
    _qualityList = qualityList;
    notifyListeners();
  }

  /// 清除音源
  void clearApis() {
    _apis.clear();
    _qualityList.clear();
    notifyListeners();
  }

  /// 更新 API 信息
  void updateApiInfo(String id, UserApiInfo info) {
    final index = _list.indexWhere((api) => api.id == id);
    if (index >= 0) {
      _list[index] = info;
      notifyListeners();
    }
  }
}
