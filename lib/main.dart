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

/// 我的页面
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '我的',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // 功能卡片
          _buildFunctionCard(
            context,
            icon: Icons.favorite,
            color: Colors.red,
            title: '我的收藏',
            subtitle: '收藏的歌曲',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildFunctionCard(
            context,
            icon: Icons.download,
            color: Colors.green,
            title: '本地下载',
            subtitle: '已下载的歌曲',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildFunctionCard(
            context,
            icon: Icons.history,
            color: Colors.orange,
            title: '播放历史',
            subtitle: '最近播放记录',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildFunctionCard(
            context,
            icon: Icons.access_time,
            color: Colors.blue,
            title: '稍后播放',
            subtitle: '临时播放列表',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
