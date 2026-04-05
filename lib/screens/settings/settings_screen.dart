import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../models/enums.dart';
import '../../services/settings/setting_store.dart';
import '../../services/player/player_service.dart';
import '../../services/user_api/user_api_manager.dart';
import '../../services/user_api/musicfree_manager.dart';
import '../../services/user_api/plugin_format_detector.dart';
import '../../utils/global.dart';
import '../../utils/app_logger.dart';
import '../../utils/page_transitions.dart';
import '../developer/developer_screen.dart';
import 'about_screen.dart';
import 'equalizer_screen.dart';

/// 设置页 — 支持 MD3 / 液态玻璃双风格
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  bool _isGlass(BuildContext c) => c.watch<SettingStore>().appStyle == 'liquid_glass';

  void _showMFImportDialog(BuildContext ctx, TextEditingController controller) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('导入 MF 插件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('通过 URL 导入 MusicFree 插件'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '粘贴插件 URL 或脚本内容',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final script = controller.text.trim();
              if (script.isEmpty) return;
              if (!ctx.mounted) return;
              final mfManager = ctx.read<MusicFreeManager>();
              final result = await mfManager.importPlugin(script);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(result['success'] == true ? '✅ ${result['message']}' : '❌ ${result['message']}')),
                );
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  /// 统一构建列表项 — 根据风格自动选择 MD3 或 玻璃
  Widget _buildTile({
    required BuildContext context,
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool dense = false,
  }) {
    if (_isGlass(context)) {
      return GlassListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      );
    }
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
      dense: dense,
    );
  }

  /// 统一构建开关项
  Widget _buildSwitchTile({
    required BuildContext context,
    required Widget secondary,
    required Widget title,
    required Widget subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool dense = false,
  }) {
    if (_isGlass(context)) {
      return _GlassSwitchTile(
        leading: secondary,
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
        dense: dense,
      );
    }
    return SwitchListTile(
      secondary: secondary,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      dense: dense,
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = _isGlass(context);
    final setting = context.watch<SettingStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 60),
            children: [
              _buildSection(context, '基本设置', [
                _buildSourceDisplay(context),
                _buildUserApiConfig(context),
                _buildTheme(context),
                _buildDownloadManager(context),
              ]),
              _buildSection(context, '外观', [
                _buildAppStyle(context),
                _buildThemeMode(context),
                _buildThemeColorPicker(context),
              ]),
              _buildSection(context, '播放设置', [
                _buildQuality(context),
                _buildPlayMode(context),
                _buildVolume(context),
                _buildSpeed(context),
                _buildCache(context),
                _buildTimeoutExit(context),
                _buildEqualizer(context),
              ]),
              _buildSection(context, '搜索设置', [
                _buildHotSearch(context),
                _buildSearchHistory(context),
              ]),
              _buildSection(context, '列表设置', [
                _buildShowAlbum(context),
                _buildShowDuration(context),
              ]),
              _buildSection(context, '开发者', [
                _buildDevMode(context),
              ]),
              _buildSection(context, '关于', [
                _buildTile(
                  context: context,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于浮生音乐'),
                  subtitle: const Text('软件介绍、免责协议、开源地址'),
                  onTap: () {
                    Navigator.push(
                      context,
                      SlideRightRoute(page: const AboutScreen()),
                    );
                  },
                ),
              ]),
            ],
          ),
          // 液态玻璃模式下，用玻璃面板覆盖整个设置页背景
          if (glass)
            Positioned.fill(
              child: IgnorePointer(
                child: GlassCard(
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    final glass = _isGlass(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        if (glass)
          GlassCard(
            child: Column(children: children),
          )
        else
          ...children,
        const Divider(height: 1),
      ],
    );
  }

  /// 应用风格选择
  Widget _buildAppStyle(BuildContext context) {
    final store = context.watch<SettingStore>();
    final isGlass = store.appStyle == 'liquid_glass';
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.style, size: 24),
          const SizedBox(width: 16),
          const Text('应用风格', style: TextStyle(fontSize: 16)),
          const Spacer(),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'material3', label: Text('MD3')),
              ButtonSegment(value: 'liquid_glass', label: Text('液态玻璃')),
            ],
            selected: {store.appStyle},
            onSelectionChanged: (selected) => store.setAppStyle(selected.first),
          ),
        ],
      ),
    );
  }

  Widget _buildUserApiConfig(BuildContext context) {
    final userApi = context.watch<UserApiManager>();
    final mfManager = context.watch<MusicFreeManager>();
    final hasApi = userApi.isInitialized;
    final hasMfPlugin = mfManager.currentPlugin != null;
    final list = userApi.state.list;
    final mfPlugins = mfManager.plugins;
    final glass = _isGlass(context);
    final cs = Theme.of(context).colorScheme;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        final isMfMode = globalOnlineMusicService.pluginMode == 'musicfree';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模式切换
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.settings_applications, size: 20),
                  const SizedBox(width: 12),
                  const Text('插件系统', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('洛雪脚本')),
                      ButtonSegment(value: true, label: Text('MF插件')),
                    ],
                    selected: {isMfMode},
                    onSelectionChanged: (selected) {
                      final mode = selected.first ? 'musicfree' : 'lx';
                      globalOnlineMusicService.setPluginMode(mode);
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString('plugin_mode', mode);
                      });
                      setLocalState(() {});
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (!isMfMode)
              _buildLxApiSection(context, userApi, hasApi, list)
            else
              _buildMfPluginSection(context, mfManager, hasMfPlugin, mfPlugins),
          ],
        );
      },
    );
  }

  Widget _buildLxApiSection(BuildContext context, UserApiManager userApi, bool hasApi, List list) {
    final glass = _isGlass(context);

    if (list.isEmpty) {
      return _buildTile(
        context: context,
        leading: const Icon(Icons.extension),
        title: const Text('外部音源'),
        subtitle: const Text('导入洛雪音乐源插件'),
        onTap: () => _showUserApiDialog(context),
      );
    }

    final activeName = hasApi
        ? (userApi.state.currentApi?.name ?? list.first.name)
        : '';

    return Column(
      children: [
        _buildSwitchTile(
          context: context,
          secondary: const Icon(Icons.extension),
          title: const Text('外部音源'),
          subtitle: Text(hasApi ? '已启用: $activeName' : '已停用'),
          value: hasApi,
          onChanged: (enabled) async {
            if (enabled) {
              final targetId = userApi.state.currentApiId ?? list.first.id;
              await userApi.setUserApi(targetId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(
                    userApi.isInitialized ? '✅ 初始化成功' : '❌ 启用失败',
                  )),
                );
              }
            } else {
              userApi.destroyUserApi();
            }
          },
        ),
        _buildTile(
          context: context,
          leading: const SizedBox(width: 48),
          title: Text(
            '管理 ${list.length} 个外部音源',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary),
          ),
          dense: true,
          onTap: () => _showUserApiDialog(context),
        ),
      ],
    );
  }

  Widget _buildMfPluginSection(BuildContext context, MusicFreeManager mfManager, bool hasMfPlugin, List<MusicFreePluginInfo> plugins) {
    if (plugins.isEmpty) {
      return _buildTile(
        context: context,
        leading: const Icon(Icons.extension_outlined),
        title: const Text('MF 插件'),
        subtitle: const Text('导入 MusicFree 格式插件'),
        onTap: () => _showMfImportDialog(context),
      );
    }

    return Column(
      children: [
        _buildTile(
          context: context,
          leading: const Icon(Icons.extension_outlined),
          title: const Text('MF 插件'),
          subtitle: Text(hasMfPlugin
              ? '已加载: ${mfManager.currentPlugin?.name}'
              : '有 ${plugins.length} 个插件未加载'),
        ),
        ...plugins.map((plugin) => _buildTile(
              context: context,
              leading: const SizedBox(width: 48),
              title: Text(plugin.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                plugin.methods.map((m) {
                  try {
                    return MfPluginMethod.values.firstWhere((e) => e.name == m).label;
                  } catch (_) {
                    return m;
                  }
                }).join('、'),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              trailing: Wrap(
                children: [
                  if (plugin.supportsGetMediaSource)
                    const Icon(Icons.play_circle_outline, size: 16, color: Colors.green),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () async {
                      await mfManager.removePlugin(plugin.id);
                      bumpSourceVersion();
                    },
                  ),
                ],
              ),
              onTap: () async {
                try {
                  await mfManager.setActivePlugin(plugin.id);
                  bumpSourceVersion();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ ${plugin.name} 已激活')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ 激活失败: $e')),
                    );
                  }
                }
              },
              dense: true,
            )),
        _buildTile(
          context: context,
          leading: const SizedBox(width: 48),
          title: Text(
            '导入 MF 插件',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary),
          ),
          dense: true,
          onTap: () => _showMfImportDialog(context),
        ),
        if (hasMfPlugin && mfManager.currentPlugin!.meta.methods.any((m) => m == MfPluginMethod.importMusicSheet))
          _buildTile(
            context: context,
            leading: const SizedBox(width: 48),
            title: const Text('导入外部歌单'),
            subtitle: const Text('通过链接/酷狗码导入歌单', style: TextStyle(fontSize: 11)),
            dense: true,
            onTap: () => _showImportSheetDialog(context, mfManager),
          ),
        if (hasMfPlugin)
          Consumer<SettingStore>(
            builder: (ctx, setting, _) => _buildSwitchTile(
              context: ctx,
              secondary: const SizedBox(width: 48),
              title: const Text('完整插件模式', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                setting.isFullMfMode ? '搜索/歌单/播放全部走 MF 插件' : '仅播放链接走 MF 插件',
                style: const TextStyle(fontSize: 11),
              ),
              value: setting.isFullMfMode,
              onChanged: (v) {
                setting.setIsFullMfMode(v);
                globalOnlineMusicService.setIsFullMfMode(v);
              },
              dense: true,
            ),
          ),
        if (hasMfPlugin)
          Consumer<SettingStore>(
            builder: (ctx, setting, _) => _buildSwitchTile(
              context: ctx,
              secondary: const SizedBox(width: 48),
              title: const Text('兼容模式', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                '从插件日志中提取播放 URL（部分插件需要）',
                style: TextStyle(fontSize: 11),
              ),
              value: setting.mfCompatibilityMode,
              onChanged: (v) {
                setting.setMfCompatibilityMode(v);
                globalMusicFreeManager.setCompatibilityMode(v);
              },
              dense: true,
            ),
          ),
      ],
    );
  }

  void _showMfImportDialog(BuildContext context) {
    final controller = TextEditingController();
    final glass = _isGlass(context);

    showDialog(
      context: context,
      builder: (ctx) {
        Widget content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '粘贴 MusicFree 格式的插件 JS 代码...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['js'],
                          withData: true,
                        );
                        if (result == null || result.files.isEmpty) return;
                        final file = result.files.first;
                        String script;
                        if (file.bytes != null) {
                          script = utf8.decode(file.bytes!);
                        } else if (file.path != null) {
                          script = await File(file.path!).readAsString(encoding: utf8);
                        } else {
                          throw Exception('无法读取文件');
                        }
                        controller.text = script;
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ 读取文件失败: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.file_open, size: 18),
                    label: const Text('文件导入'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final urlController = TextEditingController();
                      final url = await showDialog<String>(
                        context: context,
                        builder: (urlCtx) => AlertDialog(
                          title: const Text('从 URL 导入'),
                          content: TextField(
                            controller: urlController,
                            decoration: const InputDecoration(
                              hintText: '输入插件 JS 文件的 URL 地址...',
                              border: OutlineInputBorder(),
                            ),
                            autofocus: true,
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(urlCtx), child: const Text('取消')),
                            FilledButton(onPressed: () => Navigator.pop(urlCtx, urlController.text.trim()), child: const Text('导入')),
                          ],
                        ),
                      );
                      if (url == null || url.isEmpty) return;
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在下载...')));
                        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
                        if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
                        controller.text = utf8.decode(response.bodyBytes);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ 下载失败: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('URL 导入'),
                  ),
                ),
              ],
            ),
          ],
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (glass) _showMFImportDialog(ctx, controller);
        });
        return AlertDialog(
                title: const Text('导入 MF 插件'),
                content: content,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final script = controller.text.trim();
                      if (script.isEmpty) return;
                      final mfManager = context.read<MusicFreeManager>();
                      final result = await mfManager.importPlugin(script);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result['success'] == true
                              ? '✅ ${result['message']}'
                              : '❌ ${result['message']}')),
                        );
                      }
                    },
                    child: const Text('导入'),
                  ),
                ],
              );
      },
    );
  }

  void _showImportSheetDialog(BuildContext context, MusicFreeManager mfManager) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入外部歌单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入歌单链接或ID...',
            border: OutlineInputBorder(),
            helperText: '支持酷狗码、歌单链接等格式',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在导入歌单，请稍候...')),
              );
              try {
                final songs = await mfManager.importMusicSheet(url);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(songs.isNotEmpty
                        ? '✅ 导入成功，共 ${songs.length} 首'
                        : '⚠️ 未找到歌曲')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ 导入失败: $e')),
                  );
                }
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadManager(BuildContext context) {
    return _buildTile(
      context: context,
      leading: const Icon(Icons.download),
      title: const Text('下载管理'),
      subtitle: const Text('查看下载文件、清除缓存'),
      onTap: () => _showDownloadManagerDialog(context),
    );
  }

  void _showDownloadManagerDialog(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadPath = '${dir.path}/downloads';
    final downloadDir = Directory(downloadPath);
    
    int totalSize = 0;
    int fileCount = 0;
    if (await downloadDir.exists()) {
      final files = downloadDir.listSync(recursive: true);
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
          fileCount++;
        }
      }
    }

    final sizeStr = _formatFileSize(totalSize);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载管理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('下载目录'),
              subtitle: Text(downloadPath, style: const TextStyle(fontSize: 12)),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('已下载文件'),
              subtitle: Text('$fileCount 个文件 (共 $sizeStr)'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('打开目录'),
                    onPressed: () async {
                      final uri = Uri.file(downloadPath);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('清除缓存'),
                    onPressed: () async {
                      if (!await downloadDir.exists()) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        return;
                      }
                      final files = downloadDir.listSync();
                      for (final file in files) {
                        await file.delete(recursive: true);
                      }
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('下载缓存已清除')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showUserApiDialog(BuildContext context) {
    final userApi = context.read<UserApiManager>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('外部音源管理'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '支持导入洛雪音乐源插件 (.js 文件)，开启开关即可使用',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _importUserApi(context, ctx),
                      icon: const Icon(Icons.file_open, size: 18),
                      label: const Text('文件导入'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _importUserApiFromUrl(context, ctx),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('URL 导入'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (userApi.state.list.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text('已导入的音源:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: userApi.state.list.length,
                    itemBuilder: (_, index) {
                      final api = userApi.state.list[index];
                      final isActive = userApi.isInitialized && userApi.state.currentApiId == api.id;
                      return ListTile(
                        leading: Icon(
                          isActive ? Icons.check_circle : Icons.music_note,
                          color: isActive ? Theme.of(ctx).colorScheme.primary : null,
                        ),
                        title: Text(api.name),
                        subtitle: Text('${api.version}${isActive ? ' · 使用中' : ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            await userApi.removeUserApi([api.id]);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                        onTap: isActive ? null : () async {
                          await userApi.setUserApi(api.id);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(
                                userApi.isInitialized
                                    ? '✅ 已切换到: ${api.name}'
                                    : '❌ 切换失败',
                              )),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _importUserApi(BuildContext context, BuildContext dialogCtx) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['js'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      String script;
      if (file.bytes != null) {
        script = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        script = await File(file.path!).readAsString(encoding: utf8);
      } else {
        throw Exception('无法读取文件');
      }
      final userApi = context.read<UserApiManager>();
      final apiInfo = await userApi.importUserApi(script);
      await userApi.setUserApi(apiInfo.id);
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            userApi.isInitialized
                ? '✅ 初始化成功: ${apiInfo.name}'
                : '⚠️ 已导入但初始化失败: ${apiInfo.name}',
          )),
        );
        _showUserApiDialog(context);
      }
    } catch (e) {
      if (dialogCtx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 导入失败: $e')),
        );
      }
    }
  }

  Future<void> _importUserApiFromUrl(BuildContext context, BuildContext dialogCtx) async {
    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从 URL 导入'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: '输入 .js 文件的 URL 地址...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, urlController.text.trim()), child: const Text('导入')),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在下载...')));
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final script = utf8.decode(response.bodyBytes);
      final userApi = context.read<UserApiManager>();
      final apiInfo = await userApi.importUserApi(script);
      await userApi.setUserApi(apiInfo.id);
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            userApi.isInitialized
                ? '✅ 初始化成功: ${apiInfo.name}'
                : '⚠️ 已导入但初始化失败: ${apiInfo.name}',
          )),
        );
        _showUserApiDialog(context);
      }
    } catch (e) {
      if (dialogCtx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 导入失败: $e')),
        );
      }
    }
  }

  Widget _buildSourceDisplay(BuildContext context) {
    final store = context.watch<SettingStore>();
    return _buildTile(
      context: context,
      leading: const Icon(Icons.music_note),
      title: const Text('音乐源'),
      subtitle: Text(store.defaultSource.name),
      onTap: () => _showSourcePicker(context),
    );
  }

  void _showSourcePicker(BuildContext context) {
    final store = context.read<SettingStore>();
    final glass = _isGlass(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => glass
          ? _GlassSheet(
              title: const Text('选择音乐源'),
              child: ListView(
                shrinkWrap: true,
                children: MusicSource.values.map((src) {
                  return RadioListTile<MusicSource>(
                    title: Text(src.name),
                    value: src,
                    groupValue: store.defaultSource,
                    onChanged: (v) {
                      if (v != null) {
                        store.setDefaultSource(v);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            )
          : SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: MusicSource.values.map((src) {
                  return RadioListTile<MusicSource>(
                    title: Text(src.name),
                    value: src,
                    groupValue: store.defaultSource,
                    onChanged: (v) {
                      if (v != null) {
                        store.setDefaultSource(v);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildTheme(BuildContext context) {
    final store = context.watch<SettingStore>();
    const labels = {
      'system': '跟随系统', 'blue': '蓝色', 'red': '红色',
      'orange': '橙色', 'green': '绿色', 'purple': '紫色',
      'pink': '粉色', 'teal': '青色',
    };
    return _buildTile(
      context: context,
      leading: const Icon(Icons.palette),
      title: const Text('主题颜色'),
      subtitle: Text(labels[store.themeColor] ?? store.themeColor),
      onTap: () => _showThemePicker(context),
    );
  }

  void _showThemePicker(BuildContext context) {
    final store = context.read<SettingStore>();
    const colors = ['system', 'blue', 'red', 'orange', 'green', 'purple', 'pink', 'teal'];
    const labels = {
      'system': '跟随系统', 'blue': '蓝色', 'red': '红色',
      'orange': '橙色', 'green': '绿色', 'purple': '紫色',
      'pink': '粉色', 'teal': '青色',
    };
    final glass = _isGlass(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => glass
          ? _GlassSheet(
              title: const Text('选择主题颜色'),
              child: ListView(
                shrinkWrap: true,
                children: colors.map((c) {
                  return RadioListTile<String>(
                    title: Text(labels[c] ?? c),
                    value: c,
                    groupValue: store.themeColor,
                    onChanged: (v) {
                      if (v != null) { store.setThemeColor(v); Navigator.pop(ctx); }
                    },
                  );
                }).toList(),
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: colors.map((c) {
                return RadioListTile<String>(
                  title: Text(labels[c] ?? c),
                  value: c,
                  groupValue: store.themeColor,
                  onChanged: (v) {
                    if (v != null) { store.setThemeColor(v); Navigator.pop(ctx); }
                  },
                );
              }).toList(),
            ),
    );
  }

  Widget _buildThemeColorPicker(BuildContext context) {
    final store = context.watch<SettingStore>();
    const colors = [
      {'key': 'purple', 'color': Colors.purple},
      {'key': 'blue', 'color': Colors.blue},
      {'key': 'green', 'color': Colors.green},
      {'key': 'orange', 'color': Colors.orange},
      {'key': 'red', 'color': Colors.red},
      {'key': 'pink', 'color': Colors.pink},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: colors.map((c) {
          final isSelected = store.themeColor == c['key'];
          return GestureDetector(
            onTap: () => store.setThemeColor(c['key'] as String),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c['color'] as Color,
                border: isSelected
                    ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemeMode(BuildContext context) {
    final store = context.watch<SettingStore>();
    const labels = {
      'system': '跟随系统',
      'light': '浅色模式',
      'dark': '深色模式',
    };
    return _buildTile(
      context: context,
      leading: const Icon(Icons.brightness_6),
      title: const Text('深色模式'),
      subtitle: Text(labels[store.themeMode] ?? store.themeMode),
      onTap: () => _showThemeModePicker(context),
    );
  }

  void _showThemeModePicker(BuildContext context) {
    final store = context.read<SettingStore>();
    const modes = ['system', 'light', 'dark'];
    const labels = {
      'system': '跟随系统',
      'light': '浅色模式',
      'dark': '深色模式',
    };
    final glass = _isGlass(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => glass
          ? _GlassSheet(
              title: const Text('选择深色模式'),
              child: ListView(
                shrinkWrap: true,
                children: modes.map((m) {
                  return RadioListTile<String>(
                    title: Text(labels[m] ?? m),
                    value: m,
                    groupValue: store.themeMode,
                    onChanged: (v) {
                      if (v != null) {
                        store.setThemeMode(v);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: modes.map((m) {
                return RadioListTile<String>(
                  title: Text(labels[m] ?? m),
                  value: m,
                  groupValue: store.themeMode,
                  onChanged: (v) {
                    if (v != null) {
                      store.setThemeMode(v);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
    );
  }

  Widget _buildQuality(BuildContext context) {
    final store = context.watch<SettingStore>();
    return _buildTile(
      context: context,
      leading: const Icon(Icons.high_quality),
      title: const Text('播放音质'),
      subtitle: Text(store.quality.value),
      onTap: () => _showQualityPicker(context),
    );
  }

  void _showQualityPicker(BuildContext context) {
    final store = context.read<SettingStore>();
    final glass = _isGlass(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => glass
          ? _GlassSheet(
              title: const Text('选择播放音质'),
              child: ListView(
                shrinkWrap: true,
                children: Quality.values.map((q) {
                  return RadioListTile<Quality>(
                    title: Text(q.value),
                    value: q,
                    groupValue: store.quality,
                    onChanged: (v) {
                      if (v != null) {
                        store.setQuality(v);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: Quality.values.map((q) {
                return RadioListTile<Quality>(
                  title: Text(q.value),
                  value: q,
                  groupValue: store.quality,
                  onChanged: (v) {
                    if (v != null) {
                      store.setQuality(v);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPlayMode(BuildContext context) {
    final store = context.watch<SettingStore>();
    return _buildTile(
      context: context,
      leading: const Icon(Icons.repeat),
      title: const Text('播放模式'),
      subtitle: Text(store.playMode.value),
      onTap: () => _showPlayModePicker(context),
    );
  }

  void _showPlayModePicker(BuildContext context) {
    final store = context.read<SettingStore>();
    final glass = _isGlass(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => glass
          ? _GlassSheet(
              title: const Text('选择播放模式'),
              child: ListView(
                shrinkWrap: true,
                children: PlayMode.values.map((m) {
                  return RadioListTile<PlayMode>(
                    title: Text(m.value),
                    value: m,
                    groupValue: store.playMode,
                    onChanged: (v) {
                      if (v != null) {
                        store.setPlayMode(v);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: PlayMode.values.map((m) {
                return RadioListTile<PlayMode>(
                  title: Text(m.value),
                  value: m,
                  groupValue: store.playMode,
                  onChanged: (v) {
                    if (v != null) {
                      store.setPlayMode(v);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
    );
  }

  Widget _buildVolume(BuildContext context) {
    final store = context.watch<SettingStore>();
    return _buildTile(
      context: context,
      leading: const Icon(Icons.volume_up),
      title: const Text('音量'),
      subtitle: Text('${(store.volume * 100).toInt()}%'),
    );
  }

  Widget _buildSpeed(BuildContext context) {
    final store = context.watch<SettingStore>();
    return _buildTile(
      context: context,
      leading: const Icon(Icons.speed),
      title: const Text('播放速度'),
      subtitle: Text('${store.speed}x'),
    );
  }

  Widget _buildCache(BuildContext context) {
    return _buildTile(
      context: context,
      leading: const Icon(Icons.cleaning_services),
      title: const Text('清除缓存'),
      subtitle: const Text('清除搜索历史和播放缓存'),
      onTap: () => _clearCache(context),
    );
  }

  void _clearCache(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清除')),
      );
    }
  }

  Widget _buildTimeoutExit(BuildContext context) {
    final player = context.watch<PlayerService>();
    final hasTimeout = player.timeoutMinutes > 0;
    final stopAfterCurrent = player.stopAfterCurrentSong;
    return Column(
      children: [
        _buildTile(
          context: context,
          leading: const Icon(Icons.timer),
          title: const Text('定时关闭'),
          subtitle: Text(hasTimeout ? '剩余 ${player.timeoutStr}' : '未开启'),
          onTap: () => _showTimeoutPicker(context),
        ),
        if (hasTimeout)
          _buildSwitchTile(
            context: context,
            secondary: const SizedBox(width: 48),
            title: const Text('播完当前歌曲再停'),
            subtitle: Text(stopAfterCurrent ? '已开启' : '已关闭'),
            value: stopAfterCurrent,
            onChanged: (v) => player.setStopAfterCurrentSong(v),
          ),
      ],
    );
  }

  void _showTimeoutPicker(BuildContext context) {
    final player = context.read<PlayerService>();
    final options = [
      {'label': '不开启', 'minutes': 0},
      {'label': '10 分钟', 'minutes': 10},
      {'label': '20 分钟', 'minutes': 20},
      {'label': '30 分钟', 'minutes': 30},
      {'label': '45 分钟', 'minutes': 45},
      {'label': '60 分钟', 'minutes': 60},
      {'label': '90 分钟', 'minutes': 90},
      {'label': '120 分钟', 'minutes': 120},
    ];
    final glass = _isGlass(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => glass
          ? _GlassSheet(
              title: const Text('定时关闭'),
              child: ListView(
                shrinkWrap: true,
                children: options.map((o) {
                  return RadioListTile<int>(
                    title: Text(o['label'] as String),
                    value: o['minutes'] as int,
                    groupValue: player.timeoutMinutes,
                    onChanged: (v) {
                      if (v != null) {
                        player.setTimeoutExit(v);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: options.map((o) {
                return RadioListTile<int>(
                  title: Text(o['label'] as String),
                  value: o['minutes'] as int,
                  groupValue: player.timeoutMinutes,
                  onChanged: (v) {
                    if (v != null) {
                      player.setTimeoutExit(v);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEqualizer(BuildContext context) {
    return _buildTile(
      context: context,
      leading: const Icon(Icons.equalizer),
      title: const Text('均衡器'),
      subtitle: const Text('调节各频段音量'),
      onTap: () {
        Navigator.push(
          context,
          SlideRightRoute(page: const EqualizerScreen()),
        );
      },
    );
  }

  Widget _buildHotSearch(BuildContext context) {
    return _buildSwitchTile(
      context: context,
      secondary: const Icon(Icons.trending_up),
      title: const Text('热搜'),
      subtitle: const Text('显示热搜词'),
      value: true,
      onChanged: (v) {},
    );
  }

  Widget _buildSearchHistory(BuildContext context) {
    return _buildSwitchTile(
      context: context,
      secondary: const Icon(Icons.history),
      title: const Text('搜索历史'),
      subtitle: const Text('保存搜索记录'),
      value: true,
      onChanged: (v) {},
    );
  }

  Widget _buildShowAlbum(BuildContext context) {
    return _buildSwitchTile(
      context: context,
      secondary: const Icon(Icons.album),
      title: const Text('显示专辑'),
      subtitle: const Text('在歌曲列表中显示专辑名'),
      value: true,
      onChanged: (v) {},
    );
  }

  Widget _buildShowDuration(BuildContext context) {
    return _buildSwitchTile(
      context: context,
      secondary: const Icon(Icons.access_time),
      title: const Text('显示时长'),
      subtitle: const Text('在歌曲列表中显示歌曲时长'),
      value: true,
      onChanged: (v) {},
    );
  }

  Widget _buildDevMode(BuildContext context) {
    return _buildTile(
      context: context,
      leading: const Icon(Icons.developer_mode),
      title: const Text('开发者选项'),
      onTap: () {
        Navigator.push(
          context,
          SlideRightRoute(page: const DeveloperScreen()),
        );
      },
    );
  }
}

/// 玻璃开关列表项 (液态玻璃模式适配)
class _GlassSwitchTile extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool dense;

  const _GlassSwitchTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
      onTap: () => onChanged?.call(!value),
      dense: dense,
    );
  }
}

/// 玻璃底部 Sheet (液态玻璃模式适配)
class _GlassSheet extends StatelessWidget {
  final Widget title;
  final Widget child;

  const _GlassSheet({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle(),
                child: title,
              ),
            ),
            child,
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}