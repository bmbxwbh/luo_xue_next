import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'services/player/player_service.dart';
import 'services/music/list_store.dart';
import 'services/music/local_music_service.dart';
import 'services/music/hot_search_store.dart';
import 'services/user_api/user_api_manager.dart';
import 'services/user_api/musicfree_manager.dart';
import 'screens/home/tab_mylist.dart';
import 'store/dislike_list_store.dart';
import 'store/search_store.dart' as store_search;
import 'store/player_store.dart';
import 'services/settings/setting_store.dart';
import 'services/audio/equalizer_service.dart';
import 'services/log/log_upload_service.dart';
import 'utils/app_logger.dart';
import 'utils/global.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/tab_search.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/about_screen.dart';
import 'widgets/unified_bottom_bar.dart';

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

  // 初始化 MusicFree 插件管理器
  final musicFreeManager = MusicFreeManager();
  await musicFreeManager.init();

  // 初始化设置存储
  final settingStore = SettingStore();
  await settingStore.init();

  // 液态玻璃模式：初始化玻璃引擎
  await LiquidGlassWidgets.initialize();

  // 初始化均衡器服务
  final equalizerService = EqualizerService();
  await equalizerService.init();

  // 初始化日志上传服务
  await LogUploadService().init();

  // 初始化全局播放器
  initGlobalPlayer(
    settingStore: settingStore,
    userApiManager: userApiManager,
    musicFreeManager: musicFreeManager,
  );

  runApp(LuoXueNextApp(
    userApiManager: userApiManager,
    musicFreeManager: musicFreeManager,
    settingStore: settingStore,
    equalizerService: equalizerService,
  ));
}

class LuoXueNextApp extends StatelessWidget {
  final UserApiManager userApiManager;
  final MusicFreeManager musicFreeManager;
  final SettingStore settingStore;
  final EqualizerService equalizerService;

  const LuoXueNextApp({
    super.key, 
    required this.userApiManager,
    required this.musicFreeManager,
    required this.settingStore,
    required this.equalizerService,
  });

  @override
  Widget build(BuildContext context) {
    final app = _buildApp(context);
    // 液态玻璃模式：用 wrap 包裹整个应用
    return LiquidGlassWidgets.wrap(app);
  }

  Widget _buildApp(BuildContext context) {
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
        ChangeNotifierProvider.value(value: musicFreeManager),
        ChangeNotifierProvider.value(value: equalizerService),
      ],
      child: Consumer<SettingStore>(
        builder: (_, settings, __) => DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final useSystemMonet = settings.themeColor == 'system';
            return MaterialApp(
              title: '浮生音乐',
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
              themeMode: switch (settings.themeMode) {
                'dark' => ThemeMode.dark,
                'light' => ThemeMode.light,
                _ => ThemeMode.system,
              },
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

  @override
  void initState() {
    super.initState();
    // 首次启动弹出免责协议
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<SettingStore>();
      AboutScreen.showDisclaimerIfNeeded(context, store);
    });
  }

  static final _pages = [
    const HomeScreen(),
    const SearchScreen(),
    const TabMyList(),
    const SettingsScreen(),
  ];

  void _onTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 主页面内容（占满全屏）
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: _pages[_index],
            ),
          ),
          // 统一毛玻璃底栏（集成导航 + 迷你播放器 + 进度条）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: UnifiedBottomBar(
              currentIndex: _index,
              onTap: _onTap,
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

