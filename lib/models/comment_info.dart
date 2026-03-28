/// 评论数据模型 — 对齐 LX Music
class Comment {
  final String id; // 评论ID
  final String content; // 评论内容
  final String nickname; // 用户昵称
  final String? avatar; // 用户头像
  final String time; // 评论时间
  final int liked; // 点赞数
  final int replyCount; // 回复数

  const Comment({
    required this.id,
    required this.content,
    required this.nickname,
    this.avatar,
    required this.time,
    this.liked = 0,
    this.replyCount = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'],
      time: json['time'] ?? '',
      liked: json['liked'] ?? 0,
      replyCount: json['replyCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'nickname': nickname,
        'avatar': avatar,
        'time': time,
        'liked': liked,
        'replyCount': replyCount,
      };
}

/// 评论结果 — 对齐 LX Music CommentResult
class CommentResult {
  final List<Comment> list; // 评论列表
  final int total; // 总数
  final int page; // 当前页

  const CommentResult({
    required this.list,
    required this.total,
    required this.page,
  });

  factory CommentResult.fromJson(Map<String, dynamic> json) {
    final list = <Comment>[];
    if (json['list'] is List) {
      for (final item in json['list'] as List) {
        if (item is Map<String, dynamic>) {
          list.add(Comment.fromJson(item));
        }
      }
    }
    return CommentResult(
      list: list,
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'list': list.map((c) => c.toJson()).toList(),
        'total': total,
        'page': page,
      };
}
