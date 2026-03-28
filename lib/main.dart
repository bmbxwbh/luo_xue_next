import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/player/player_service.dart';
import 'services/music/list_store.dart';
import 'services/music/local_music_service.dart';
import 'services/music/hot_search_store.dart';
import 'services/user_api/user_api_manager.dart';
import 'store/dislike_list_store.dart';
import 'store/search_store.dart' as store_search;
import 'store/player_store.dart';
import 'services/settings/setting_store.dart';
import 'utils/app_logger.dart';
import 'utils/global.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/tab_search.dart';
import 'screens/settings/settings_screen.dart';
import 'widgets/mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 拦截 debugPrint，同步写入 AppLogger
  final origDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    origDebugPrint(message, wrapWidth: wrapWidth);
    if (message != null && message.isNotEmpty) {
      // 解析 [TAG] 格式，否则归入 "App"
      final match = RegExp(r'^\[(\w+)\]\s*(.*)', dotAll: true).firstMatch(message);
      if (match != null) {
        logger.log(LogLevel.debug, match.group(1)!, match.group(2)!);
      } else {
        logger.log(LogLevel.debug, 'App', message);
      }
    }
  };

  // 全局错误捕获
  FlutterError.onError = (details) {
    logger.error('Flutter', details.exceptionAsString(), st: details.stack);
  };

  // 初始化用户 API 管理器
  final userApiManager = UserApiManager();
  await userApiManager.init();

  // 初始化设置存储
  final settingStore = SettingStore();
  await settingStore.init();

  // 初始化全局播放器
  initGlobalPlayer(
    settingStore: settingStore,
    userApiManager: userApiManager,
  );

  runApp(LuoXueNextApp(
    userApiManager: userApiManager,
    settingStore: settingStore,
  ));
}

class LuoXueNextApp extends StatelessWidget {
  final UserApiManager userApiManager;
  final SettingStore settingStore;

  const LuoXueNextApp({
    super.key, 
    required this.userApiManager,
    required this.settingStore,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerStore>.value(value: globalPlayerStore),
        ChangeNotifierProvider(create: (_) => PlayerService()),
        ChangeNotifierProvider(create: (_) => ListStore()),
        ChangeNotifierProvider(create: (_) => LocalMusicService()),
        ChangeNotifierProvider(create: (_) => store_search.SearchStore()),
        ChangeNotifierProvider(create: (_) => HotSearchStore()),
        ChangeNotifierProvider.value(value: settingStore),
        ChangeNotifierProvider(create: (_) => DislikeListStore()..init()),
        ChangeNotifierProvider.value(value: userApiManager),
      ],
      child: Consumer<SettingStore>(
        builder: (_, settings, __) => DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final useSystemMonet = settings.themeColor == 'system';
            return MaterialApp(
              title: '洛雪Next',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: useSystemMonet && lightDynamic != null
                    ? lightDynamic
                    : ColorScheme.fromSeed(
                        seedColor: _themeColorSeed(settings.themeColor),
                        brightness: Brightness.light,
                      ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: useSystemMonet && darkDynamic != null
                    ? darkDynamic
                    : ColorScheme.fromSeed(
                        seedColor: _themeColorSeed(settings.themeColor),
                        brightness: Brightness.dark,
                      ),
              ),
              themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              home: const MainScreen(),
            );
          },
        ),
      ),
    );
  }

  Color _themeColorSeed(String color) {
    return switch (color) {
      'red' => Colors.red,
      'orange' => Colors.orange,
      'green' => Colors.green,
      'purple' => Colors.purple,
      'pink' => Colors.pink,
      'teal' => Colors.teal,
      _ => Colors.blue, // 'system' 兜底也用 blue
    };
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    SearchScreen(),
    MyScreen(),
    SettingsScreen(),
  ];

  void _onTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 主页面内容（占满全屏）
          Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: _pages[_index],
                  ),
                ),
              ),
              // 音乐栏放在原来底栏的位置（底部固定）
              const MiniPlayer(),
            ],
          ),
          // 悬浮底栏（在 MiniPlayer 上方）
          Positioned(
            left: 16,
            right: 16,
            bottom: 52 + MediaQuery.of(context).padding.bottom + 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh.withAlpha(204),
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: List.generate(4, (i) {
                      final icons = [
                        Icons.home_outlined,
                        Icons.search_outlined,
                        Icons.library_music_outlined,
                        Icons.settings_outlined,
                      ];
                      final selectedIcons = [
                        Icons.home,
                        Icons.search,
                        Icons.library_music,
                        Icons.settings,
                      ];
                      final labels = ['首页', '搜索', '我的', '设置'];
                      final selected = _index == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onTap(i),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.symmetric(
                                  horizontal: selected ? 12 : 0,
                                  vertical: selected ? 2 : 0,
                                ),
                                decoration: selected
                                    ? BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      )
                                    : null,
                                child: Icon(
                                  selected ? selectedIcons[i] : icons[i],
                                  size: 20,
                                  color: selected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索页面 — 复用 TabSearch 组件
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: TabSearch());
  }
}

/// 我的页面 — 真实数据版
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  bool _scanning = false;

  Future<void> _scanLocalMusic() async {
    if (_scanning) return;
    setState(() => _scanning = true);

    final localService = context.read<LocalMusicService>();
    final count = await localService.scanLocalMusic();

    if (mounted) {
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? '发现 $count 首本地音乐' : '未发现本地音乐'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localService = context.watch<LocalMusicService>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            '我的',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          // 用户信息卡
          _buildUserCard(context, localService),
          const SizedBox(height: 16),
          // 功能网格
          Row(
            children: [
              Expanded(child: _buildGridCard(context, Icons.favorite_rounded, '收藏', Colors.red, () {})),
              const SizedBox(width: 10),
              Expanded(child: _buildGridCard(context, Icons.download_rounded, '下载', Colors.green, () {})),
              const SizedBox(width: 10),
              Expanded(child: _buildGridCard(context, Icons.history_rounded, '历史', Colors.orange, () {})),
              const SizedBox(width: 10),
              Expanded(child: _buildGridCard(context, Icons.access_time_rounded, '稍后', Colors.blue, () {})),
            ],
          ),
          const SizedBox(height: 24),
          // 本地音乐
          _buildLocalMusicCard(context, localService),
          const SizedBox(height: 12),
          // 功能列表
          _buildListItem(context, Icons.playlist_play_rounded, '最近播放', () {}),
          _buildListItem(context, Icons.radio_rounded, '私人FM', () {}),
          _buildListItem(context, Icons.cloud_download_rounded, '云盘音乐', () {}),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, LocalMusicService localService) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primary,
            child: Icon(Icons.music_note_rounded, size: 28, color: colorScheme.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的音乐',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${localService.count} 首本地歌曲',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalMusicCard(BuildContext context, LocalMusicService localService) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (localService.songs.isNotEmpty) {
            _showLocalMusicList(context, localService);
          } else {
            _scanLocalMusic();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_rounded, color: Colors.green, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('本地音乐', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      localService.count > 0
                          ? '已导入 ${localService.count} 首'
                          : '点击扫描导入本地歌曲',
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (_scanning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _scanLocalMusic,
                  tooltip: '扫描',
                ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onSecondaryContainer),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onTap: onTap,
    );
  }

  void _showLocalMusicList(BuildContext context, LocalMusicService localService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '本地音乐 (${localService.count})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: localService.songs.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(localService.songs[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(localService.songs[i].singer, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      globalPlayer.playMusic(localService.songs[i]);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
