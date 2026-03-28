import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../services/settings/setting_store.dart';
import 'tab_songlist.dart';
import 'tab_leaderboard.dart';

/// 首页 — 推荐歌单 / 排行榜 / 我的歌单
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  MusicSource _source = MusicSource.kw;

  final List<_TabInfo> _tabs = const [
    _TabInfo('推荐', Icons.explore_rounded),
    _TabInfo('排行', Icons.bar_chart_rounded),
  ];

  bool _headerVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    final setting = context.read<SettingStore>();
    _source = setting.defaultSource;
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

  void _showSourceSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('选择音源', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: MusicSource.values.map((src) {
                    if (src == MusicSource.local) return const SizedBox.shrink();
                    final selected = src == _source;
                    return ChoiceChip(
                      label: Text(src.name),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _source = src);
                        context.read<SettingStore>().setDefaultSource(src);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // 顶栏（可隐藏）
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: _headerVisible ? null : 0,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(),
            child: AnimatedOpacity(
              opacity: _headerVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行：标题 + 音源选择 + 通知
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '洛雪NEXT',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        // 音源选择按钮
                        InkWell(
                          onTap: _showSourceSelector,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.source_rounded, size: 16, color: colorScheme.onPrimaryContainer),
                                const SizedBox(width: 4),
                                Text(
                                  _source.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_drop_down, size: 18, color: colorScheme.onPrimaryContainer),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_none_rounded, size: 22),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tab栏
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: false,
                        dividerHeight: 0,
                        indicator: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: colorScheme.onPrimary,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
                        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        unselectedLabelStyle: const TextStyle(fontSize: 14),
                        padding: const EdgeInsets.all(3),
                        tabs: _tabs
                            .map((t) => Tab(
                                  icon: Icon(t.icon, size: 18),
                                  text: t.label,
                                  height: 36,
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
                children: [
                  TabSongList(source: _source),
                  TabLeaderboard(source: _source),
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
