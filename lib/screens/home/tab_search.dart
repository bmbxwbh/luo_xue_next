import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../models/song_model.dart';
import '../../store/search_store.dart';
import '../../services/music/hot_search_store.dart';
import '../../services/settings/setting_store.dart';
import '../../services/user_api/musicfree_manager.dart';
import '../../services/player/player_service.dart';
import '../../widgets/source_selector.dart';
import '../../widgets/song_list_tile.dart';
import '../../widgets/search_tip_list.dart';
import '../../core/search/music.dart';

/// 搜索 Tab
class TabSearch extends StatefulWidget {
  const TabSearch({super.key});

  @override
  State<TabSearch> createState() => _TabSearchState();
}

class _TabSearchState extends State<TabSearch> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showTips = false;
  List<String> _tips = [];

  // 搜索结果
  List<SongModel> _results = [];
  bool _hasSearched = false;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  late MusicSearchService _searchService;
  bool _isAggregateSearch = false;

  @override
  void initState() {
    super.initState();
    final setting = context.read<SettingStore>();
    final searchStore = context.read<SearchStore>();
    // 同步默认音源
    searchStore.setTempSource(setting.defaultSource);

    _searchService = MusicSearchService(searchStore);
    _searchService.setFullMfMode(setting.isFullMfMode);
    _searchController.addListener(_onSearchChanged);
    context.read<HotSearchStore>().loadHotSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _searchController.text;
    context.read<SearchStore>().setSearchText(text);

    if (text.isNotEmpty) {
      _loadSuggestions(text);
    } else {
      setState(() {
        _showTips = false;
        _tips = [];
      });
    }
  }

  Future<void> _loadSuggestions(String keyword) async {
    final hotStore = context.read<HotSearchStore>();
    final tips = await hotStore.getSuggestions(keyword);
    if (mounted) {
      setState(() {
        _tips = tips;
        _showTips = tips.isNotEmpty && _focusNode.hasFocus;
      });
    }
  }

  Future<void> _search({bool aggregate = false}) async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final searchStore = context.read<SearchStore>();
    searchStore.addHistory(keyword);
    _focusNode.unfocus();

    setState(() {
      _showTips = false;
      _hasSearched = true;
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _isAggregateSearch = aggregate;
    });

    try {
      List<SongModel> results;
      if (_isAggregateSearch) {
        final futures = <Future<List<SongModel>>>[];
        for (final source in MusicSource.values.where((s) => s != MusicSource.local)) {
          futures.add(
            _searchService.search(keyword, source, _currentPage)
                .catchError((_) => <SongModel>[])
          );
        }
        final allResults = await Future.wait(futures);
        results = [];
        for (final list in allResults) {
          results.addAll(list);
        }
        final seen = <String>{};
        final deduplicated = <SongModel>[];
        for (final song in results) {
          final key = '${song.name}_${song.singer}';
          if (!seen.contains(key)) {
            seen.add(key);
            deduplicated.add(song);
          }
        }
        results = deduplicated;
      } else {
        results = await _searchService.search(
          keyword,
          searchStore.tempSource,
          _currentPage,
        );
      }

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _results = [];
        });
      }
    }
  }

  /// 加载更多
  Future<void> _loadMore() async {
    if (_isLoading) return;

    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final searchStore = context.read<SearchStore>();

    setState(() {
      _isLoading = true;
    });

    try {
      _currentPage++;
      final results = await _searchService.search(
        keyword,
        searchStore.tempSource,
        _currentPage,
      );

      if (mounted) {
        setState(() {
          _results.addAll(results);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
      children: [
        // 搜索框
        _buildSearchBar(),
        // 内容区
        Expanded(
          child: _buildContent(),
        ),
      ],
    ),
    );
  }

  Widget _buildSearchBar() {
    final searchStore = context.watch<SearchStore>();
    final colorScheme = Theme.of(context).colorScheme;
    final setting = context.watch<SettingStore>();
    final mfManager = context.watch<MusicFreeManager>();
    final isFullMf = setting.isFullMfMode && mfManager.currentPlugin != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // 搜索框 + 按钮
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      // 聚合搜索开关
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFullMf)
                            // 完整 MF 模式：显示插件名
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.extension_rounded, size: 14, color: colorScheme.onPrimaryContainer),
                                  const SizedBox(width: 4),
                                  Text(
                                    mfManager.currentPlugin?.name ?? 'MF插件',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onPrimaryContainer),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                          FilterChip(
                            label: const Text('聚合', style: TextStyle(fontSize: 11)),
                            selected: _isAggregateSearch,
                            onSelected: (v) {
                              if (v) {
                                _search(aggregate: true);
                              }
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (!_isAggregateSearch) ...[
                            PopupMenuButton<MusicSource>(
                              initialValue: searchStore.tempSource,
                              onSelected: (src) => searchStore.setTempSource(src),
                              itemBuilder: (_) => MusicSource.values.map((src) =>
                                PopupMenuItem(value: src, child: Text(src.name))
                              ).toList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      searchStore.tempSource.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 16,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                        ], // close else
                      const SizedBox(width: 4),
                      // 输入框
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: '搜索歌曲、歌手',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _showTips = false;
                                        _tips = [];
                                        _hasSearched = false;
                                        _results = [];
                                        _isAggregateSearch = false;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          style: const TextStyle(fontSize: 14),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          onTap: () {
                            if (_tips.isNotEmpty) {
                              setState(() => _showTips = true);
                            }
                          },
                        ),
                      ),
                      // 搜索按钮
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.search_rounded, color: colorScheme.primary),
                          onPressed: () => _search(aggregate: _isAggregateSearch),
                          tooltip: '搜索',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 搜索类型
          Row(
            children: [
              _buildTypeChip('歌曲', searchStore.searchType == SearchType.music, () {
                searchStore.setSearchType(SearchType.music);
              }),
              const SizedBox(width: 8),
              _buildTypeChip('歌单', searchStore.searchType == SearchType.songlist, () {
                searchStore.setSearchType(SearchType.songlist);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildContent() {
    if (_showTips) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SearchTipList(
          suggestions: _tips,
          onSelected: (tip) {
            _searchController.text = tip;
            _search();
          },
        ),
      );
    }

    if (_hasSearched) {
      return _buildSearchResults();
    }

    return _buildBlankView();
  }

  Widget _buildSourceDropdown(SearchStore store) {
    return PopupMenuButton<MusicSource>(
      initialValue: store.tempSource,
      onSelected: (src) => store.setTempSource(src),
      itemBuilder: (_) => MusicSource.values.map((src) =>
        PopupMenuItem(value: src, child: Text(src.name))
      ).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              store.tempSource.name,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlankView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        // 热搜
        _buildHotSearch(),
        const SizedBox(height: 16),
        // 搜索历史
        _buildHistory(),
      ],
    );
  }

  Widget _buildHotSearch() {
    final hotStore = context.watch<HotSearchStore>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, size: 18),
            const SizedBox(width: 4),
            Text(
              '热搜',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (hotStore.isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hotStore.hotList.map((kw) {
              return ActionChip(
                label: Text(kw),
                onPressed: () {
                  _searchController.text = kw;
                  _search();
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHistory() {
    final searchStore = context.watch<SearchStore>();
    final recent = searchStore.recentSearches;

    if (recent.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 18),
            const SizedBox(width: 4),
            Text(
              '搜索历史',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => searchStore.clearHistory(),
              child: const Text('清除'),
            ),
          ],
        ),
        ...recent.map((kw) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 20),
              title: Text(kw, style: const TextStyle(fontSize: 14)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => searchStore.removeHistory(kw),
              ),
              onTap: () {
                _searchController.text = kw;
                _search();
              },
            )),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '搜索失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _search(aggregate: _isAggregateSearch),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(child: Text('未找到相关结果'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
            !_isLoading) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: _results.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _results.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildResultItem(_results[index], index);
        },
      ),
    );
  }

  Widget _buildResultItem(SongModel song, int index) {
    final sourceColors = {
      MusicSource.kw: Colors.orange,
      MusicSource.kg: Colors.red,
      MusicSource.tx: Colors.green,
      MusicSource.wy: Colors.blue,
      MusicSource.mg: Colors.purple,
      MusicSource.local: Colors.grey,
    };
    final color = sourceColors[song.source] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: const Icon(Icons.music_note, size: 20),
        ),
        title: Row(
          children: [
            Expanded(child: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (_isAggregateSearch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  song.source.name,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(song.singer, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () {
          final player = context.read<PlayerService>();
          player.playSong(song, listId: 'search');
        },
      ),
    );
  }
}
