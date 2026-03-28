import 'package:flutter/material.dart';
import 'tab_songlist.dart';
import 'tab_leaderboard.dart';
import 'tab_mylist.dart';

/// 首页 — 推荐歌单 / 排行榜 / 我的歌单
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<_TabInfo> _tabs = const [
    _TabInfo('推荐', Icons.explore_rounded),
    _TabInfo('排行', Icons.bar_chart_rounded),
    _TabInfo('歌单', Icons.library_music_rounded),
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
      if (delta > 8 && _headerVisible) {
        setState(() => _headerVisible = false);
      } else if (delta < -8 && !_headerVisible) {
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
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // 可隐藏的顶栏
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: _headerVisible ? null : 0,
            child: AnimatedOpacity(
              opacity: _headerVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部标题
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '洛雪Next',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_none_rounded, size: 22),
                            onPressed: () {},
                            tooltip: '通知',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tab栏
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: false,
                        dividerHeight: 0,
                        indicator: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: colorScheme.onPrimary,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                        padding: const EdgeInsets.all(3),
                        tabs: _tabs
                            .map((t) => Tab(
                                  icon: Icon(t.icon, size: 18),
                                  text: t.label,
                                  height: 32,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
