/// 酷狗音乐评论 — 对齐 LX Music kg/comment.js
import '../../utils/http_client.dart';
import '../../models/comment_info.dart';

class KgComment {
  static const int _defaultLimit = 20;

  /// 获取评论列表
  static Future<CommentResult> getComment({
    required String musicId,
    required String hash,
    int page = 1,
    int limit = 20,
    int retryNum = 0,
  }) async {
    if (retryNum > 3) throw Exception('try max num');

    try {
      final resp = await HttpClient.get(
        'http://comment.kugou.com/index.php?r=commentsv2/getCommentWithLike&code=fc4be23b7090c78e326bc97819e4996a&p=$page&pagesize=$limit&kugo_version=10026&appid=1005&clientver=10026&mid=&musicid=$musicId&hash=$hash',
      );

      if (!resp.ok || resp.jsonBody == null) {
        return getComment(musicId: musicId, hash: hash, page: page, limit: limit, retryNum: retryNum + 1);
      }

      final body = resp.jsonBody;
      if (body['error_code'] != 0 && body['status'] != 1) {
        return getComment(musicId: musicId, hash: hash, page: page, limit: limit, retryNum: retryNum + 1);
      }

      final data = body['data'] ?? body;
      final rawList = data['list'] as List? ?? [];
      final total = data['total'] ?? 0;

      final list = rawList.map<Comment>((item) {
        return Comment(
          id: item['commentid']?.toString() ?? '',
          content: item['content'] ?? '',
          nickname: item['userinfo']?['nickname'] ?? '',
          avatar: item['userinfo']?['avatar'],
          time: item['addtime']?.toString() ?? '',
          liked: item['like'] ?? 0,
          replyCount: item['reply_count'] ?? 0,
        );
      }).toList();

      return CommentResult(list: list, total: total, page: page);
    } catch (e) {
      return getComment(musicId: musicId, hash: hash, page: page, limit: limit, retryNum: retryNum + 1);
    }
  }
}
