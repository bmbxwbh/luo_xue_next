import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../models/song_model.dart';
import '../../store/search_store.dart';
import '../../services/music/hot_search_store.dart';
import '../../services/settings/setting_store.dart';
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

  @override
  void initState() {
    super.initState();
    final setting = context.read<SettingStore>();
    final searchStore = context.read<SearchStore>();
    // 同步默认音源
    searchStore.setTempSource(setting.defaultSource);

    _searchService = MusicSearchService(searchStore);
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

  Future<void> _search() async {
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
    });

    try {
      final results = await _searchService.search(
        keyword,
        searchStore.tempSource,
        _currentPage,
      );

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
    return Column(
      children: [
        // 搜索框
        _buildSearchBar(),
        // 内容区
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final searchStore = context.watch<SearchStore>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              // 音源选择下拉
              _buildSourceDropdown(searchStore),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: '搜索歌曲、歌手',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _showTips = false;
                                _tips = [];
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  onTap: () {
                    if (_tips.isNotEmpty) {
                      setState(() => _showTips = true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _search,
                child: const Text('搜索'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 搜索类型切换
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

    if (searchStore.historyList.isEmpty) {
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: searchStore.historyList.map((kw) {
            return InputChip(
              label: Text(kw),
              onPressed: () {
                _searchController.text = kw;
                _search();
              },
              onDeleted: () => searchStore.removeHistory(kw),
            );
          }).toList(),
        ),
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
              onPressed: _search,
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
          return SongListTile(
            song: _results[index],
            index: index,
            listId: 'search',
          );
        },
      ),
    );
  }
}
