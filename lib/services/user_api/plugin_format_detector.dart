/// MusicFree 插件格式检测器
///
/// 用途：检测 JS 脚本代码是洛雪格式还是 MusicFree 格式，以便选择正确的加载策略。
///
/// 关键逻辑：
/// - 洛雪格式：包含 `lx_setup` 函数调用或 `globalThis.lx` 对象引用
/// - MusicFree 格式：包含 `module.exports` 导出且定义了 `platform` 字段
/// - 检测优先级：先检查 MF 特征（更具体），再检查洛雪特征
/// - 如果脚本同时包含两种特征，以 MF 为准（MF 插件可能也引用了 lx）
library;

/// 插件格式枚举
enum PluginFormat {
  /// 洛雪音乐脚本格式（使用 lx_setup / globalThis.lx）
  lx,

  /// MusicFree 插件格式（使用 module.exports + platform）
  musicfree,

  /// 未知格式
  unknown,
}

/// MusicFree 插件支持的搜索类型
enum MfSearchType {
  music('music'),
  album('album'),
  artist('artist'),
  sheet('sheet');

  const MfSearchType(this.value);
  final String value;
}

/// MusicFree 插件方法名枚举
enum MfPluginMethod {
  search('search'),
  getMediaSource('getMediaSource'),
  getLyric('getLyric'),
  getMusicInfo('getMusicInfo'),
  getAlbumInfo('getAlbumInfo'),
  getMusicSheetInfo('getMusicSheetInfo'),
  importMusicSheet('importMusicSheet'),
  importMusicItem('importMusicItem'),
  getTopLists('getTopLists'),
  getTopListDetail('getTopListDetail'),
  getRecommendSheetTags('getRecommendSheetTags'),
  getRecommendSheetsByTag('getRecommendSheetsByTag');

  const MfPluginMethod(this.name);
  final String name;
}

/// MusicFree 插件元信息（从脚本中提取）
class MfPluginMeta {
  /// 平台名（必须）
  final String platform;

  /// 版本号
  final String? version;

  /// 更新 URL
  final String? srcUrl;

  /// 兼容 app 版本
  final String? appVersion;

  /// 支持的搜索类型
  final List<MfSearchType> supportedSearchType;

  /// 缓存控制策略
  final String? cacheControl;

  /// 用户自定义变量定义
  final List<MfUserVariable>? userVariables;

  /// 插件排序权重
  final int order;

  /// 主键字段列表
  final List<String> primaryKey;

  /// 用户提示信息
  final Map<String, dynamic> hints;

  /// 脚本中实际定义的方法名列表
  final List<MfPluginMethod> methods;

  const MfPluginMeta({
    required this.platform,
    this.version,
    this.srcUrl,
    this.appVersion,
    this.supportedSearchType = const [],
    this.cacheControl,
    this.userVariables,
    this.order = 0,
    this.primaryKey = const [],
    this.hints = const {},
    this.methods = const [],
  });

  /// 是否支持搜索
  bool get supportsSearch => methods.contains(MfPluginMethod.search);

  /// 是否支持获取媒体源
  bool get supportsGetMediaSource =>
      methods.contains(MfPluginMethod.getMediaSource);

  /// 是否支持获取歌词
  bool get supportsGetLyric => methods.contains(MfPluginMethod.getLyric);

  /// 是否支持获取音乐详情
  bool get supportsGetMusicInfo =>
      methods.contains(MfPluginMethod.getMusicInfo);

  /// 是否支持获取专辑信息
  bool get supportsGetAlbumInfo =>
      methods.contains(MfPluginMethod.getAlbumInfo);

  /// 是否支持导入歌单
  bool get supportsImportMusicSheet =>
      methods.contains(MfPluginMethod.importMusicSheet);

  /// 是否支持导入单曲
  bool get supportsImportMusicItem =>
      methods.contains(MfPluginMethod.importMusicItem);

  /// 是否支持获取榜单
  bool get supportsGetTopLists =>
      methods.contains(MfPluginMethod.getTopLists);

  Map<String, dynamic> toJson() => {
        'platform': platform,
        if (version != null) 'version': version,
        if (srcUrl != null) 'srcUrl': srcUrl,
        if (appVersion != null) 'appVersion': appVersion,
        'supportedSearchType':
            supportedSearchType.map((t) => t.value).toList(),
        if (cacheControl != null) 'cacheControl': cacheControl,
        'methods': methods.map((m) => m.name).toList(),
      };

  @override
  String toString() =>
      'MfPluginMeta(platform: $platform, version: $version, methods: ${methods.map((m) => m.name).toList()})';
}

/// MusicFree 用户自定义变量定义
class MfUserVariable {
  /// 变量键名
  final String key;

  /// 变量显示名
  final String? name;

  /// 变量提示
  final String? hint;

  const MfUserVariable({required this.key, this.name, this.hint});
}

/// 插件格式检测结果
class PluginFormatResult {
  /// 检测到的格式
  final PluginFormat format;

  /// MusicFree 元信息（仅当 format == musicfree 时非 null）
  final MfPluginMeta? mfMeta;

  const PluginFormatResult({required this.format, this.mfMeta});

  bool get isLx => format == PluginFormat.lx;
  bool get isMusicFree => format == PluginFormat.musicfree;
  bool get isUnknown => format == PluginFormat.unknown;
}

/// 检测 JS 脚本的插件格式
///
/// [script] JS 脚本内容
/// 返回检测结果，包含格式类型和（如果是 MF 格式）插件元信息
PluginFormatResult detectPluginFormat(String script) {
  if (script.isEmpty) {
    return const PluginFormatResult(format: PluginFormat.unknown);
  }

  // 1. 先检测 MusicFree 特征（更具体的模式优先）
  final mfResult = _detectMusicFree(script);
  if (mfResult != null) {
    return PluginFormatResult(
      format: PluginFormat.musicfree,
      mfMeta: mfResult,
    );
  }

  // 2. 再检测洛雪特征
  if (_detectLx(script)) {
    return const PluginFormatResult(format: PluginFormat.lx);
  }

  return const PluginFormatResult(format: PluginFormat.unknown);
}

/// 检测是否为洛雪格式
///
/// 洛雪特征：
/// - 包含 `lx_setup` 函数调用
/// - 或包含 `globalThis.lx` 引用
/// - 或包含 `__lx_handlers__` 引用
bool _detectLx(String script) {
  // lx_setup 调用（洛雪插件的核心特征）
  if (script.contains('lx_setup')) return true;

  // globalThis.lx 引用
  if (script.contains('globalThis.lx')) return true;

  // __lx_handlers__ 引用
  if (script.contains('__lx_handlers__')) return true;

  return false;
}

/// 检测是否为 MusicFree 格式
///
/// MusicFree 特征：
/// - 必须包含 `module.exports` 或 `exports.platform`
/// - 必须包含 `platform` 字段定义
/// - 通常还有 `require(` 调用
///
/// 返回 MF 插件元信息，如果不是 MF 格式则返回 null
MfPluginMeta? _detectMusicFree(String script) {
  // 必须有 module.exports 或 exports 相关定义
  final hasExports = script.contains('module.exports') ||
      script.contains('exports.platform') ||
      script.contains('exports =');

  if (!hasExports) return null;

  // 必须有 platform 字段定义（在 module.exports 中）
  // 匹配模式：platform: 'xxx' 或 platform: "xxx" 或 platform:`xxx`
  final platformMatch = RegExp(
    r'''platform\s*:\s*['"`]([^'"`]+)['"`]''',
  ).firstMatch(script);

  if (platformMatch == null) return null;

  final platform = platformMatch.group(1)!;

  // 提取其他元信息
  final version = _extractStringField(script, 'version');
  final srcUrl = _extractStringField(script, 'srcUrl');
  final appVersion = _extractStringField(script, 'appVersion');
  final cacheControl = _extractStringField(script, 'cacheControl');

  // 提取 supportedSearchType
  final supportedSearchType = _extractSearchTypes(script);

  // 提取方法列表
  final methods = _extractMethods(script);

  // 提取 userVariables
  final userVariables = _extractUserVariables(script);

  return MfPluginMeta(
    platform: platform,
    version: version,
    srcUrl: srcUrl,
    appVersion: appVersion,
    supportedSearchType: supportedSearchType,
    cacheControl: cacheControl,
    userVariables: userVariables,
    methods: methods,
  );
}

/// 从脚本中提取字符串字段值
String? _extractStringField(String script, String fieldName) {
  final match = RegExp(
    '''$fieldName\\s*:\\s*['"`]([^'"`]+)['"`]''',
  ).firstMatch(script);
  return match?.group(1);
}

/// 从脚本中提取支持的搜索类型
List<MfSearchType> _extractSearchTypes(String script) {
  final types = <MfSearchType>[];

  // 匹配 supportedSearchType: ['music', 'album', ...]
  final match = RegExp(
    r'supportedSearchType\s*:\s*\[([^\]]*)\]',
  ).firstMatch(script);

  if (match != null) {
    final content = match.group(1)!;
    for (final type in MfSearchType.values) {
      if (content.contains("'${type.value}'") ||
          content.contains('"${type.value}"')) {
        types.add(type);
      }
    }
  }

  return types;
}

/// 从脚本中提取已定义的方法名
List<MfPluginMethod> _extractMethods(String script) {
  final methods = <MfPluginMethod>[];

  for (final method in MfPluginMethod.values) {
    // 匹配 async search(...) 或 search: function(...) 或 search(...){ 等模式
    final pattern = RegExp(
      '(?:async\\s+)?${method.name}\\s*[:(]',
    );
    if (pattern.hasMatch(script)) {
      methods.add(method);
    }
  }

  return methods;
}

/// 从脚本中提取 userVariables 定义
List<MfUserVariable>? _extractUserVariables(String script) {
  // 简单检测是否存在 userVariables 定义
  if (!script.contains('userVariables')) return null;

  // 提取 userVariables 数组内容
  final match = RegExp(
    r'userVariables\s*:\s*\[([^\]]*)\]',
    dotAll: true,
  ).firstMatch(script);

  if (match == null) return null;

  final content = match.group(1)!;
  final variables = <MfUserVariable>[];

  // 匹配 { key: 'xxx', name: 'yyy', hint: 'zzz' }
  final varPattern = RegExp(
    r'''key\s*:\s*['"`]([^'"`]+)['"`]''',
  );

  for (final m in varPattern.allMatches(content)) {
    final key = m.group(1)!;
    // 尝试在同一块中提取 name 和 hint
    final block = content.substring(
      m.start,
      content.indexOf('}', m.end) + 1,
    );
    final name = _extractStringField(block, 'name');
    final hint = _extractStringField(block, 'hint');
    variables.add(MfUserVariable(key: key, name: name, hint: hint));
  }

  return variables.isNotEmpty ? variables : null;
}
