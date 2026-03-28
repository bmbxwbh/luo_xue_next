/// 酷我音乐封面 — 对齐 LX Music kw/pic.js
import '../../utils/http_client.dart';

class KwPic {
  /// 获取歌曲封面
  static Future<String?> getPic(Map<String, dynamic> songInfo) async {
    try {
      final songmid = songInfo['songmid']?.toString() ?? '';
      final resp = await HttpClient.get(
        'http://artistpicserver.kuwo.cn/pic.web?corp=kuwo&type=rid_pic&pictype=500&size=500&rid=$songmid',
      );
      if (resp.ok && resp.body.startsWith('http')) {
        return resp.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
