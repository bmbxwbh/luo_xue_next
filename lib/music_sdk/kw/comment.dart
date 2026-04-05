/// 酷我音乐评论 — 对齐 LX Music kw/comment.js
import '../../utils/http_client.dart';
import '../../models/comment_info.dart';

class KwComment {
  static const int _defaultLimit = 20;

  /// 获取评论列表
  static Future<CommentResult> getComment({
    required String sid, // 歌曲ID
    required String digest, // 摘要
    int page = 1,
    int limit = 20,
    int retryNum = 0,
  }) async {
    if (retryNum > 3) throw Exception('try max num');

    try {
      final resp = await HttpClient.get(
        'http://comment.kuwo.cn/cm/comment?comment=getcomment&type=get_comment&f=web&page=$page&rows=$limit&digest=$digest&sid=$sid',
      );

      if (!resp.ok || resp.jsonBody == null) {
        return getComment(sid: sid, digest: digest, page: page, limit: limit, retryNum: retryNum + 1);
      }

      final body = resp.jsonBody;
      final rawList = body['rows'] as List? ?? body['comments'] as List? ?? [];
      final total = body['total'] ?? 0;

      final list = rawList.map<Comment>((item) {
        return Comment(
          id: item['id']?.toString() ?? '',
          content: item['msg'] ?? item['content'] ?? '',
          nickname: item['u_name'] ?? item['nickname'] ?? '',
          avatar: item['u_pic'] ?? item['avatar'],
          time: item['time']?.toString() ?? '',
          liked: item['like'] ?? 0,
          replyCount: item['replynum'] ?? item['replyCount'] ?? 0,
        );
      }).toList();

      return CommentResult(list: list, total: total, page: page);
    } catch (e) {
      return getComment(sid: sid, digest: digest, page: page, limit: limit, retryNum: retryNum + 1);
    }
  }
}
