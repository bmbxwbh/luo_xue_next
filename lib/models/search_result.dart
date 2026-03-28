/// 搜索结果模型 — 对齐 LX Music
class SearchResult {
  final List<Map<String, dynamic>> list;
  final int allPage;
  final int limit;
  final int total;
  final String source;

  const SearchResult({
    required this.list,
    required this.allPage,
    required this.limit,
    required this.total,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'list': list,
        'allPage': allPage,
        'limit': limit,
        'total': total,
        'source': source,
      };
}
