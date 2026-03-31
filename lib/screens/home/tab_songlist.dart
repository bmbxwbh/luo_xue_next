import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings/setting_store.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/enums.dart';
import '../../models/playlist_info.dart';
import '../../utils/page_transitions.dart';
import '../../utils/playlist_cache.dart';
import '../../utils/global.dart';
import '../../music_sdk/kw/song_list.dart';
import '../../music_sdk/kg/song_list.dart';
import '../../music_sdk/wy/song_list.dart';
import '../../music_sdk/tx/song_list.dart';
import '../../music_sdk/mg/song_list.dart';
import '../songlist_detail/songlist_detail_screen.dart';

/// 每页加载数量
const int _pageSize = 18;

/// 推荐歌单 Tab
class TabSongList extends StatefulWidget {
  final MusicSource source;
  const TabSongList({super.key, required this.source});

  @override
  State<TabSongList> createState() => _TabSongListState();
}

class _TabSongListState extends State<TabSongList> {
  late MusicSource _source;
  String _category = '全部';
  String? _categoryTagId; // 当前选中分类的 tagId
  List<PlaylistInfo> _playlists = [];
  List<_CategoryItem> _categories = [_CategoryItem('全部', null)];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _loadCategories();
    _loadPlaylists();
  }

  @override
  void didUpdateWidget(TabSongList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _source = widget.source;
      _category = '全部';
      _categoryTagId = null;
      _loadCategories();
      _loadPlaylists(refresh: true);
    }
  }

  /// 加载分类标签（带缓存）
  Future<void> _loadCategories() async {
    try {
      // 先尝试本地缓存
      final cached = await PlaylistCache.getCategories(_source.id);
      if (cached != null && cached.isNotEmpty) {
        final cats = [_CategoryItem('全部', null)];
        for (final item in cached) {
          cats.add(_CategoryItem(item['name']?.toString() ?? '', item['tagId']?.toString()));
        }
        if (mounted) setState(() { _categories = cats; });
        return;
      }

      List<_CategoryItem> cats = [_CategoryItem('全部', null)];
      final rawList = <Map<String, dynamic>>[];

      // MF 模式：从 MF 插件获取分类标签
      final setting = context.read<SettingStore>();
      final isFullMf = setting.isFullMfMode && globalOnlineMusicService.mfManagerAvailable;
      if (globalOnlineMusicService.isMfSearchAvailable || isFullMf) {
        final tags = await globalOnlineMusicService.mfGetPlaylistTags();
        for (final tag in tags) {
          final name = tag['title']?.toString() ?? tag['name']?.toString() ?? '';
          if (name.isEmpty) continue;
          cats.add(_CategoryItem(name, name));
          rawList.add({'name': name, 'tagId': name});
        }
        if (rawList.isNotEmpty) {
          await PlaylistCache.setCategories('mf', rawList);
        }
        if (mounted) setState(() { _categories = cats; });
        return;
      }

      switch (_source) {
        case MusicSource.kw:
          final tags = await KwSongList.getTags();
          final hotTags = tags['hotTag'] as List? ?? [];
          final tagGroups = tags['tags'] as List? ?? [];
          // 先添加热门标签
          for (final t in hotTags) {
            if (t is Map) {
              final name = t['name']?.toString() ?? '';
              final id = t['id']?.toString();
              cats.add(_CategoryItem(name, id));
              rawList.add({'name': name, 'tagId': id});
            }
          }
          // 再添加分类标签组
          for (final group in tagGroups) {
            if (group is Map && group['list'] is List) {
              for (final t in group['list']) {
                if (t is Map) {
                  final name = t['name']?.toString() ?? '';
                  final id = t['id']?.toString();
                  cats.add(_CategoryItem(name, id));
                  rawList.add({'name': name, 'tagId': id});
                }
              }
            }
          }
          break;
        case MusicSource.kg:
          final tags = await KgSongList.getTags();
          final hotTags = tags['hotTag'] as List? ?? [];
          final tagGroups = tags['tags'] as List? ?? [];
          for (final t in hotTags) {
            if (t is Map) {
              final name = t['name']?.toString() ?? '';
              final id = t['id']?.toString();
              cats.add(_CategoryItem(name, id));
              rawList.add({'name': name, 'tagId': id});
            }
          }
          for (final group in tagGroups) {
            if (group is Map && group['list'] is List) {
              for (final t in group['list']) {
                if (t is Map) {
                  final name = t['name']?.toString() ?? '';
                  final id = t['id']?.toString();
                  cats.add(_CategoryItem(name, id));
                  rawList.add({'name': name, 'tagId': id});
                }
              }
            }
          }
          break;
        case MusicSource.tx:
          // QQ 音乐静态分类
          final txCats = [
            _CategoryItem('流行', '6'), _CategoryItem('摇滚', '11'),
            _CategoryItem('民谣', '12'), _CategoryItem('电子', '14'),
            _CategoryItem('说唱', '15'), _CategoryItem('古典', '16'),
            _CategoryItem('轻音乐', '17'), _CategoryItem('影视', '18'),
            _CategoryItem('R&B', '19'), _CategoryItem('华语', '20'),
          ];
          cats.addAll(txCats);
          for (final c in txCats) rawList.add({'name': c.name, 'tagId': c.tagId});
          break;
        case MusicSource.wy:
          final wyCats = [
            _CategoryItem('华语', '华语'),
            _CategoryItem('流行', '流行'),
            _CategoryItem('摇滚', '摇滚'),
            _CategoryItem('民谣', '民谣'),
            _CategoryItem('电子', '电子'),
            _CategoryItem('说唱', '说唱'),
            _CategoryItem('古典', '古典'),
            _CategoryItem('轻音乐', '轻音乐'),
            _CategoryItem('影视原声', '影视原声'),
            _CategoryItem('ACG', 'ACG'),
          ];
          cats.addAll(wyCats);
          for (final c in wyCats) rawList.add({'name': c.name, 'tagId': c.tagId});
          break;
        case MusicSource.local:
          // 本地音乐不参与在线歌单
          break;
      case MusicSource.mg:
          // 咪咕使用静态分类
          final mgCats = [
            _CategoryItem('华语', '15127315'),
            _CategoryItem('流行', '15127316'),
            _CategoryItem('摇滚', '15127317'),
            _CategoryItem('民谣', '15127318'),
            _CategoryItem('电子', '15127319'),
            _CategoryItem('古典', '15127320'),
          ];
          cats.addAll(mgCats);
          for (final c in mgCats) rawList.add({'name': c.name, 'tagId': c.tagId});
          break;
      }
      // 保存到缓存
      if (rawList.isNotEmpty) {
        await PlaylistCache.setCategories(_source.id, rawList);
      }
      if (mounted) {
        setState(() {
          _categories = cats;
        });
      }
    } catch (e) {
      // 加载分类失败时使用默认分类
      debugPrint('加载分类失败: $e');
    }
  }

  /// 加载歌单列表（带缓存 + 18个/页限制）
  Future<void> _loadPlaylists({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 先尝试本地缓存（非刷新时）
      if (!refresh) {
        final cached = await PlaylistCache.getList(_source.id, _categoryTagId, _page);
        if (cached != null && cached.isNotEmpty) {
          if (mounted) {
            setState(() {
              _playlists.addAll(cached);
              _isLoading = false;
              _hasMore = cached.length >= _pageSize;
            });
          }
          return;
        }
      }

      Map<String, dynamic> result;

      // MF 模式：从 MF 插件获取歌单
      final setting = context.read<SettingStore>();
      final isFullMf = setting.isFullMfMode && globalOnlineMusicService.mfManagerAvailable;
      if (globalOnlineMusicService.isMfSearchAvailable || isFullMf) {
        final mfResult = await globalOnlineMusicService.mfGetPlaylists(_page);
        final mfList = (mfResult['list'] as List? ?? []);
        final list = mfList.map<PlaylistInfo>((item) => PlaylistInfo(
          playCount: item['playCount']?.toString() ?? item['play_count']?.toString() ?? '0',
          id: item['id']?.toString() ?? '',
          author: item['artist']?.toString() ?? item['author']?.toString() ?? '',
          name: item['title']?.toString() ?? item['name']?.toString() ?? '',
          img: item['artwork']?.toString() ?? item['img']?.toString() ?? '',
          total: item['total'] is int ? item['total'] : int.tryParse(item['total']?.toString() ?? '0') ?? 0,
          desc: item['description']?.toString() ?? item['desc']?.toString() ?? '',
          source: 'mf',
        )).toList();
        if (list.isNotEmpty) {
          await PlaylistCache.setList('mf', null, _page, list);
        }
        if (mounted) {
          setState(() {
            if (refresh || _page == 1) {
              _playlists = list;
            } else {
              _playlists.addAll(list);
            }
            _isLoading = false;
            _hasMore = mfResult['hasMore'] == true && list.length >= _pageSize;
          });
        }
        return;
      }

      // 内置音源获取歌单
      switch (_source) {
        case MusicSource.kw:
          result = await KwSongList.getList('new', _categoryTagId, _page);
          break;
        case MusicSource.kg:
          final kgList = await KgSongList.getSongList('5', _categoryTagId, _page);
          result = {'list': kgList, 'total': null};
          break;
        case MusicSource.tx:
          final sortId = _categoryTagId == null ? 5 : 2;
          result = await TxSongList.getList(sortId, tagId: _categoryTagId, page: _page);
          break;
        case MusicSource.wy:
          result = await WySongList.getList('hot', tagId: _categoryTagId, page: _page);
          break;
        case MusicSource.local:
          result = {'list': [], 'hasMore': false};
          break;
        case MusicSource.mg:
          result = await MgSongList.getList('recommend', tagId: _categoryTagId, page: _page);
          break;
      }

      // 解析列表，限制每页 18 个
      final allItems = (result['list'] as List? ?? []);
      final pageItems = allItems.length > _pageSize ? allItems.sublist(0, _pageSize) : allItems;
      final list = pageItems
          .map<PlaylistInfo>((item) => PlaylistInfo(
                playCount: item['play_count']?.toString() ?? '0',
                id: item['id']?.toString() ?? '',
                author: item['author']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
                img: item['img']?.toString() ?? '',
                total: item['total'] is int
                    ? item['total']
                    : int.tryParse(item['total']?.toString() ?? '0') ?? 0,
                desc: item['desc']?.toString() ?? '',
                source: _source.id,
              ))
          .toList();

      // 缓存本页数据
      if (list.isNotEmpty) {
        await PlaylistCache.setList(_source.id, _categoryTagId, _page, list);
      }

      if (mounted) {
        setState(() {
          if (refresh || _page == 1) {
            _playlists = list;
          } else {
            _playlists.addAll(list);
          }
          _isLoading = false;
          // 判断是否还有下一页：有更多数据且当前页满了 18 个
          final total = result['total'];
          if (total != null && total is int) {
            _hasMore = _playlists.length < total;
          } else {
            _hasMore = list.length >= _pageSize;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 分类标签（跟随顶栏隐藏）
        _buildCategoryChips(),
        // 歌单内容
        Expanded(child: _buildContent()),
      ],
    );
  }

  void _onCategoryChanged(String cat, String? tagId) {
    setState(() {
      _category = cat;
      _categoryTagId = tagId;
    });
    _loadPlaylists(refresh: true);
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final selected = cat.name == _category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat.name),
              selected: selected,
              onSelected: (_) => _onCategoryChanged(cat.name, cat.tagId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _playlists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _loadPlaylists(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_playlists.isEmpty) {
      return const Center(child: Text('暂无歌单数据'));
    }
    return RefreshIndicator(
      onRefresh: () => _loadPlaylists(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200 &&
              !_isLoading &&
              _hasMore) {
            _page++;
            _loadPlaylists();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _playlists.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _playlists.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildPlaylistCard(_playlists[index]);
          },
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(PlaylistInfo playlist) {
    return GestureDetector(
      onTap: () => _openDetail(playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Hero(
                      tag: 'playlist_${playlist.id}',
                      child: playlist.img.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: playlist.img,
                              fit: BoxFit.cover,
                              memCacheWidth: 300,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.music_note, size: 32),
                              ),
                            )
                          : const Center(child: Icon(Icons.music_note, size: 32)),
                    ),
                  ),
                  // 播放数
                  if (playlist.playCount.isNotEmpty && playlist.playCount != '0')
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              _formatCount(playlist.playCount),
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            playlist.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatCount(String count) {
    // count 可能已经是 "1.2万" 格式（来自 SDK 格式化），直接返回
    if (count.contains('万') || count.contains('亿')) return count;
    final n = int.tryParse(count) ?? 0;
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return count;
  }

  void _openDetail(PlaylistInfo playlist) {
    Navigator.of(context).push(
      SlideRightRoute(page: SonglistDetailScreen(playlist: playlist)),
    );
  }
}

/// 分类项
class _CategoryItem {
  final String name;
  final String? tagId;
  const _CategoryItem(this.name, this.tagId);
}
