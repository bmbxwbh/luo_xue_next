import 'dart:convert';

import 'package:encrypt/encrypt.dart';

/// 酷我 WBD 加密工具
class WbdCrypto {
  static final _key = Key.fromUtf8('7090B36CE136B081');
  static final _iv = IV.fromLength(16);

  /// 构建加密参数
  static String buildParam(Map<String, dynamic> params) {
    final jsonStr = jsonEncode(params);
    final encrypted = Encrypter(AES(_key, mode: AESMode.ecb)).encrypt(jsonStr, iv: _iv);
    return encrypted.base64;
  }

  /// 解密数据
  static dynamic decodeData(String data) {
    try {
      final decrypted = Encrypter(AES(_key, mode: AESMode.ecb)).decrypt64(data, iv: _iv);
      return jsonDecode(decrypted);
    } catch (_) {
      try {
        return jsonDecode(data);
      } catch (__) {
        return null;
      }
    }
  }
}
