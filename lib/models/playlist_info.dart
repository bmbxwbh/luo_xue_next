/// 歌单信息模型 — 对齐 LX Music
class PlaylistInfo {
  final String playCount;
  final String id;
  final String author;
  final String name;
  final String time;
  final String img;
  final int total;
  final String desc;
  final String source;

  const PlaylistInfo({
    required this.playCount,
    required this.id,
    required this.author,
    required this.name,
    this.time = '',
    required this.img,
    this.total = 0,
    this.desc = '',
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'play_count': playCount,
        'id': id,
        'author': author,
        'name': name,
        'time': time,
        'img': img,
        'total': total,
        'desc': desc,
        'source': source,
      };
}
