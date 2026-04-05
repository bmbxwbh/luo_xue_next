import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../services/settings/setting_store.dart';
import '../../services/user_api/musicfree_manager.dart';
import '../../utils/global.dart';
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
                        bumpSourceVersion();
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
    final setting = context.watch<SettingStore>();
    final mfManager = context.watch<MusicFreeManager>();
    final isFullMf = setting.isFullMfMode && mfManager.currentPlugin != null;
    final displaySource = isFullMf
        ? (mfManager.currentPlugin?.name ?? 'MF插件')
        : _source.name;

    return SafeArea(
      child: Column(
        children: [
          // 顶栏 — 悬浮胶囊，一直存在
          Container(
                  height: 80,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withAlpha(180),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withAlpha(60),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 工具行
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
                            child: Row(
                              children: [
                                // 音源选择按钮
                                InkWell(
                                  onTap: isFullMf ? null : _showSourceSelector,
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
                                        Icon(isFullMf ? Icons.extension_rounded : Icons.source_rounded, size: 16, color: colorScheme.onPrimaryContainer),
                                        const SizedBox(width: 4),
                                        Text(
                                          displaySource,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                        if (!isFullMf) ...[
                                          const SizedBox(width: 2),
                                          Icon(Icons.arrow_drop_down, size: 18, color: colorScheme.onPrimaryContainer),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // 通知按钮
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
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                isScrollable: false,
                                dividerHeight: 0,
                                indicator: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                labelColor: colorScheme.onPrimary,
                                unselectedLabelColor: colorScheme.onSurfaceVariant,
                                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                unselectedLabelStyle: const TextStyle(fontSize: 14),
                                padding: const EdgeInsets.all(2),
                                tabs: _tabs
                                    .map((t) => Tab(
                                          icon: Icon(t.icon, size: 18),
                                          text: t.label,
                                          height: 34,
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
          // Tab内容
          Expanded(
            child: TabBarView(
                controller: _tabController,
                children: [
                  TabSongList(source: _source, sourceVersion: globalSourceVersion),
                  TabLeaderboard(source: _source, sourceVersion: globalSourceVersion),
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
