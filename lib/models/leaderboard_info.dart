/// 排行榜信息模型 — 对齐 LX Music
class LeaderboardInfo {
  final String id;
  final String name;
  final String bangid;
  final String source;

  const LeaderboardInfo({
    required this.id,
    required this.name,
    required this.bangid,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bangid': bangid,
        'source': source,
      };
}
