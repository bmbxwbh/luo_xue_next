/// 酷狗音乐封面 — 对齐 LX Music kg/pic.js
import '../../utils/http_client.dart';

class KgPic {
  /// 获取歌曲封面
  static Future<String?> getPic(Map<String, dynamic> songInfo) async {
    try {
      final songmid = songInfo['songmid']?.toString() ?? '';
      final audioId = songmid.length == 32
          ? (songInfo['audioId']?.toString() ?? '').split('_')[0]
          : songmid;

      final resp = await HttpClient.post(
        'http://media.store.kugou.com/v1/get_res_privilege',
        headers: {
          'KG-RC': '1',
          'KG-THash': 'expand_search_manager.cpp:852736169:451',
          'User-Agent': 'KuGou2012-9020-ExpandSearchManager',
        },
        body: {
          'appid': 1001,
          'area_code': '1',
          'behavior': 'play',
          'clientver': '9020',
          'need_hash_offset': 1,
          'relate': 1,
          'resource': [
            {
              'album_audio_id': audioId,
              'album_id': songInfo['albumId'],
              'hash': songInfo['hash'],
              'id': 0,
              'name': '${songInfo['singer']} - ${songInfo['name']}.mp3',
              'type': 'audio',
            }
          ],
          'token': '',
          'userid': 2626431536,
          'vip': 1,
        },
      );

      if (!resp.ok || resp.jsonBody == null) return null;
      final body = resp.jsonBody;
      if (body['error_code'] != 0) return null;

      final data = body['data'];
      if (data is List && data.isNotEmpty) {
        final info = data[0]['info'];
        if (info != null) {
          final imgsize = info['imgsize'];
          final image = info['image']?.toString();
          if (image != null && image.isNotEmpty) {
            if (imgsize is List && imgsize.isNotEmpty) {
              return image.replaceAll('{size}', imgsize[0].toString());
            }
            return image;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
