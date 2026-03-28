import 'package:flutter/material.dart';
import 'tab_songlist.dart';
import 'tab_leaderboard.dart';
import 'tab_mylist.dart';

/// 首页 — 包含推荐歌单 / 排行榜 / 我的歌单 三个Tab
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<_TabInfo> _tabs = const [
    _TabInfo('推荐歌单', Icons.queue_music),
    _TabInfo('排行榜', Icons.leaderboard),
    _TabInfo('我的歌单', Icons.folder_special),
  ];

  bool _headerVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      final delta = n.metrics.pixels - _lastScrollOffset;
      if (delta > 5 && _headerVisible) {
        setState(() => _headerVisible = false);
      } else if (delta < -5 && !_headerVisible) {
        setState(() => _headerVisible = true);
      }
      _lastScrollOffset = n.metrics.pixels;
    }
    if (n is ScrollEndNotification) {
      _lastScrollOffset = n.metrics.pixels;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 可隐藏的顶栏
          AnimatedSlide(
            offset: _headerVisible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: _headerVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  // 顶部标题
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          '洛雪Next',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.notifications_none),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  // Tab栏
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: _tabs
                        .map((t) => Tab(
                              icon: Icon(t.icon, size: 20),
                              text: t.label,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          // Tab内容
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: TabBarView(
                controller: _tabController,
                children: const [
                  TabSongList(),
                  TabLeaderboard(),
                  TabMyList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  const _TabInfo(this.label, this.icon);
}
