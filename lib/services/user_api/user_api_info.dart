/// 用户 API 信息定义 — 对齐 LX Music types/user_api.d.ts
library;

/// 用户 API 音源信息类型
enum UserApiSourceInfoType { music }

/// 用户 API 音源支持的操作
enum UserApiSourceAction { musicUrl, lyric, pic }

/// 用户 API 音源信息
class UserApiSourceInfo {
  final String name;
  final UserApiSourceInfoType type;
  final List<UserApiSourceAction> actions;
  final List<String> qualitys;

  const UserApiSourceInfo({
    required this.name,
    this.type = UserApiSourceInfoType.music,
    required this.actions,
    required this.qualitys,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'actions': actions.map((a) => a.name).toList(),
        'qualitys': qualitys,
      };

  factory UserApiSourceInfo.fromJson(Map<String, dynamic> json) {
    return UserApiSourceInfo(
      name: json['name'] ?? '',
      type: UserApiSourceInfoType.music,
      actions: (json['actions'] as List?)
              ?.map((a) => UserApiSourceAction.values.firstWhere(
                    (e) => e.name == a,
                    orElse: () => UserApiSourceAction.musicUrl,
                  ))
              .toList() ??
          [],
      qualitys: (json['qualitys'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// 用户 API 信息
class UserApiInfo {
  final String id;
  final String name;
  final String description;
  final String author;
  final String homepage;
  final String version;
  final bool allowShowUpdateAlert;
  final Map<String, UserApiSourceInfo>? sources;

  const UserApiInfo({
    required this.id,
    required this.name,
    this.description = '',
    this.author = '',
    this.homepage = '',
    this.version = '',
    this.allowShowUpdateAlert = true,
    this.sources,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'author': author,
        'homepage': homepage,
        'version': version,
        'allowShowUpdateAlert': allowShowUpdateAlert,
        if (sources != null)
          'sources': sources!.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory UserApiInfo.fromJson(Map<String, dynamic> json) {
    Map<String, UserApiSourceInfo>? sources;
    if (json['sources'] is Map) {
      sources = (json['sources'] as Map).map(
        (k, v) => MapEntry(
          k as String,
          UserApiSourceInfo.fromJson(v as Map<String, dynamic>),
        ),
      );
    }

    return UserApiInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '未命名',
      description: json['description'] ?? '',
      author: json['author'] ?? '',
      homepage: json['homepage'] ?? '',
      version: json['version'] ?? '',
      allowShowUpdateAlert: json['allowShowUpdateAlert'] ?? true,
      sources: sources,
    );
  }

  UserApiInfo copyWith({
    String? id,
    String? name,
    String? description,
    String? author,
    String? homepage,
    String? version,
    bool? allowShowUpdateAlert,
    Map<String, UserApiSourceInfo>? sources,
  }) {
    return UserApiInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      author: author ?? this.author,
      homepage: homepage ?? this.homepage,
      version: version ?? this.version,
      allowShowUpdateAlert: allowShowUpdateAlert ?? this.allowShowUpdateAlert,
      sources: sources ?? this.sources,
    );
  }
}

/// 用户 API 请求参数
class UserApiRequestParams {
  final String requestKey;
  final UserApiRequestData data;

  const UserApiRequestParams({
    required this.requestKey,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'requestKey': requestKey,
        'data': data.toJson(),
      };
}

/// 用户 API 请求数据
class UserApiRequestData {
  final String source;
  final String action;
  final UserApiRequestInfo info;

  const UserApiRequestData({
    required this.source,
    required this.action,
    required this.info,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'action': action,
        'info': info.toJson(),
      };
}

/// 用户 API 请求信息
class UserApiRequestInfo {
  final String type;
  final Map<String, dynamic> musicInfo;

  const UserApiRequestInfo({
    required this.type,
    required this.musicInfo,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'musicInfo': musicInfo,
      };
}
