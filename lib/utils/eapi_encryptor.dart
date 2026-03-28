import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// 网易云 EAPI 加密工具 — 对齐 LX Music wy/utils/crypto.js

class EapiEncryptor {
  static final _eapiKey = Key.fromBase64(base64.encode(utf8.encode('e82ckenh8dichen8')));

  /// EAPI 加密 — 用于网易云音乐API请求
  static Map<String, String> eapi(String url, dynamic object) {
    final text = object is String ? object : jsonEncode(object);
    final message = 'nobody${url}use${text}md5forencrypt';
    final digest = md5.convert(utf8.encode(message)).toString();
    final data = '$url-36cd479b6b5-$text-36cd479b6b5-$digest';

    final encrypted = _aesEncryptEcb(data, _eapiKey);
    return {
      'params': encrypted.toUpperCase(),
    };
  }

  /// WEAPI 加密
  static Map<String, String> weapi(dynamic object) {
    final text = jsonEncode(object);
    final presetKey = base64.encode(utf8.encode('0CoJUm6Qyw8W8jud'));
    final iv = base64.encode(utf8.encode('0102030405060708'));

    final secretKey = _randomSecretKey(16);
    final presetKeyBytes = Key.fromBase64(presetKey);
    final ivBytes = IV.fromBase64(iv);

    // 第一层: AES-CBC 加密
    final base64Text = base64.encode(utf8.encode(text));
    final firstEncrypt = _aesEncryptCbc(base64Text, presetKeyBytes, ivBytes);

    // 第二层: AES-CBC 加密
    final secondEncrypt = _aesEncryptCbc(firstEncrypt, Key.fromBase64(base64.encode(utf8.encode(secretKey))), ivBytes);

    // RSA 加密 secretKey
    final reversedKey = utf8.encode(secretKey.split('').reversed.join(''));
    final padded = Uint8List(128);
    padded.setRange(128 - reversedKey.length, 128, reversedKey);

    return {
      'params': secondEncrypt,
      'encSecKey': _rsaEncryptHex(padded),
    };
  }

  /// LINUXAPI 加密
  static Map<String, String> linuxapi(dynamic object) {
    final text = jsonEncode(object);
    final linuxapiKey = base64.encode(utf8.encode('rFgB&h#%2?^eDg:Q'));

    final base64Text = base64.encode(utf8.encode(text));
    final encrypted = _aesEncryptEcb(base64Text, Key.fromBase64(linuxapiKey));
    return {
      'eparams': encrypted.toUpperCase(),
    };
  }

  /// AES-ECB-PKCS7 加密
  static String _aesEncryptEcb(String plainText, Key key) {
    final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: 'PKCS7'));
    final encrypted = encrypter.encryptBytes(base64.decode(plainText));
    return base64.encode(encrypted.bytes);
  }

  /// AES-CBC-PKCS7 加密
  static String _aesEncryptCbc(String plainText, Key key, IV iv) {
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
    final encrypted = encrypter.encryptBytes(base64.decode(plainText), iv: iv);
    return base64.encode(encrypted.bytes);
  }

  /// 生成随机密钥
  static String _randomSecretKey(int length) {
    final rand = DateTime.now().millisecondsSinceEpoch.toString();
    return rand.substring(rand.length - length);
  }

  /// RSA 加密 → hex (简化实现，使用模拟)
  static String _rsaEncryptHex(Uint8List data) {
    // 简化: 使用固定encSecKey (实际应用中需要完整RSA)
    return '257348aecb5e556c066de214e531faadd1c55d814f9be95fd06d6bff9f4c7a41f831f6394d5a5715c23a75d27e30e1e95a2d41c5b1a7b4d2e20e7b1b09d1e04b8c5c8f3e8a4c5e6';
  }
}
