/// MusicFree 插件预加载脚本 — 在 QuickJS 中提供 require() 桥接系统
///
/// 用途：让 MusicFree 格式的插件能在 QuickJS 环境中运行。
/// 通过 nativeCall 将 axios/crypto-js/qs/he 等库的调用桥接到 Dart 侧。
///
/// 关键逻辑：
/// - 注入 module、exports、require、console、process、env、URL 对象
/// - require('axios') → 通过 nativeCall('mf_http') 发 HTTP 请求
/// - require('crypto-js') → 通过 nativeCall('mf_md5')/nativeCall('mf_sha256') 等做加密
/// - require('qs') → 纯 JS 实现 URL 参数序列化
/// - require('he') → 纯 JS 实现 HTML 实体编解码
/// - 插件执行方式：Function() 包裹（和 MusicFree 原版一致）
///
/// 参考：MusicFree/src/core/pluginManager/plugin.ts 的 mountPlugin 方法
// ignore: prefer_const_declarations
final String kMusicFreePreloadScript = r'''
'use strict';

// ===================== MF 事件推送 =====================
// 复用 __lx_event_queue__ 传递 HTTP 请求到 Dart 侧
function __mf_push_event__(action, data) {
  if (globalThis.__lx_event_queue__) globalThis.__lx_event_queue__.push({action:action, data:JSON.stringify(data)});
}

// ===================== MF HTTP 请求队列 =====================
var __mf_http_counter__ = 0;
var __mf_http_queue__ = {};

function __mf_http__(method, url, config) {
  return new Promise(function(resolve, reject) {
    var id = 'mf_http_' + (++__mf_http_counter__);
    var headers = (config && config.headers) || {};
    var timeout = (config && config.timeout) || 15000;
    var body = null;
    var params = (config && config.params) || null;

    if (method === 'POST' || method === 'PUT') {
      body = (config && config.data) || null;
      if (body && typeof body !== 'string') body = JSON.stringify(body);
      if (!headers['Content-Type']) headers['Content-Type'] = 'application/json';
    }

    // 构建带 params 的 URL
    if (params) {
      var queryParts = [];
      var keys = Object.keys(params);
      for (var i = 0; i < keys.length; i++) {
        queryParts.push(encodeURIComponent(keys[i]) + '=' + encodeURIComponent(params[keys[i]]));
      }
      if (queryParts.length > 0) {
        url += (url.indexOf('?') >= 0 ? '&' : '?') + queryParts.join('&');
      }
    }

    __mf_http_queue__[id] = { resolve: resolve, reject: reject };

    __mf_push_event__('mf_request', {
      requestKey: id,
      url: url,
      options: {
        method: method,
        headers: headers,
        body: body,
        timeout: timeout
      }
    });
  });
}

// Dart 侧调用此函数返回 HTTP 响应
function handleMfNativeResponse(data) {
  var req = __mf_http_queue__[data.requestKey];
  if (!req) return;
  delete __mf_http_queue__[data.requestKey];
  if (data.error == null) {
    var resp = data.response;
    var body = resp.body;
    // 尝试解析 JSON
    if (typeof body === 'string') {
      try { body = JSON.parse(body); } catch(e) {}
    }
    req.resolve({
      data: body,
      status: resp.statusCode || 200,
      statusText: resp.statusMessage || '',
      headers: resp.headers || {}
    });
  } else {
    var err = new Error(data.error);
    err.response = null;
    req.reject(err);
  }
}

// ===================== MF axios 桥接 =====================
var __mf_axios__ = function(config) {
  if (typeof config === 'string') config = { url: config, method: 'GET' };
  return __mf_http__(config.method || 'GET', config.url, config);
};
__mf_axios__.get = function(url, config) { return __mf_http__('GET', url, config); };
__mf_axios__.post = function(url, data, config) {
  var c = config ? JSON.parse(JSON.stringify(config)) : {};
  c.data = data;
  return __mf_http__('POST', url, c);
};
__mf_axios__.put = function(url, data, config) {
  var c = config ? JSON.parse(JSON.stringify(config)) : {};
  c.data = data;
  return __mf_http__('PUT', url, c);
};
__mf_axios__.delete = function(url, config) { return __mf_http__('DELETE', url, config); };
__mf_axios__.head = function(url, config) { return __mf_http__('HEAD', url, config); };

// ===================== MF CryptoJS 桥接 =====================
// 通过 nativeCall 桥接到 Dart 侧的加密工具
var __mf_crypto_counter__ = 0;
var __mf_crypto_queue__ = {};

function __mf_crypto_call__(action, data) {
  return new Promise(function(resolve, reject) {
    var id = 'mf_crypto_' + (++__mf_crypto_counter__);
    __mf_crypto_queue__[id] = { resolve: resolve, reject: reject };
    __mf_push_event__('mf_crypto', { requestKey: id, action: action, data: data });
  });
}

// Dart 侧调用此函数返回加密结果
function handleMfCryptoResponse(data) {
  var req = __mf_crypto_queue__[data.requestKey];
  if (!req) return;
  delete __mf_crypto_queue__[data.requestKey];
  if (data.error == null) {
    req.resolve(data.result);
  } else {
    req.reject(new Error(data.error));
  }
}

// CryptoJS WordArray 模拟
function __mf_word_array_from_hex__(hex) {
  var words = [];
  for (var i = 0; i < hex.length; i += 8) {
    words.push(parseInt(hex.substr(i, 8), 16) | 0);
  }
  return { words: words, sigBytes: hex.length / 2 };
}

function __mf_hex_from_words__(wa) {
  var hex = '';
  for (var i = 0; i < wa.words.length; i++) {
    hex += ((wa.words[i] >>> 0).toString(16).padStart(8, '0'));
  }
  return hex.substr(0, wa.sigBytes * 2);
}

function __mf_utf8_to_str__(wa) {
  var hex = __mf_hex_from_words__(wa);
  var str = '';
  for (var i = 0; i < hex.length; i += 2) {
    str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
  }
  try { return decodeURIComponent(escape(str)); } catch(e) { return str; }
}

function __mf_str_to_utf8__(str) {
  var bytes = unescape(encodeURIComponent(str));
  var words = [];
  for (var i = 0; i < bytes.length; i += 4) {
    words.push(
      ((bytes.charCodeAt(i) || 0) << 24) |
      ((bytes.charCodeAt(i + 1) || 0) << 16) |
      ((bytes.charCodeAt(i + 2) || 0) << 8) |
      (bytes.charCodeAt(i + 3) || 0)
    );
  }
  return { words: words, sigBytes: bytes.length };
}

// ===================== MF 纯 JS SHA256 实现 =====================
function __mf_sha256__(str) {
  var K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];
  var H = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  ];
  function R(n, c) { return (n >>> c) | (n << (32 - c)); }
  function Ch(x, y, z) { return (x & y) ^ (~x & z); }
  function Maj(x, y, z) { return (x & y) ^ (x & z) ^ (y & z); }
  function Sigma0(x) { return R(x, 2) ^ R(x, 13) ^ R(x, 22); }
  function Sigma1(x) { return R(x, 6) ^ R(x, 11) ^ R(x, 25); }
  function sigma0(x) { return R(x, 7) ^ R(x, 18) ^ (x >>> 3); }
  function sigma1(x) { return R(x, 17) ^ R(x, 19) ^ (x >>> 10); }

  var bytes = unescape(encodeURIComponent(str));
  var bitLen = bytes.length * 8;
  var byteArr = [];
  for (var i = 0; i < bytes.length; i++) byteArr.push(bytes.charCodeAt(i));
  byteArr.push(0x80);
  while (byteArr.length % 64 !== 56) byteArr.push(0);
  byteArr.push((bitLen >>> 24) & 0xff, (bitLen >>> 16) & 0xff, (bitLen >>> 8) & 0xff, bitLen & 0xff);

  for (var o = 0; o < byteArr.length; o += 64) {
    var W = [];
    for (var j = 0; j < 16; j++) {
      var p = o + j * 4;
      W[j] = ((byteArr[p] << 24) | (byteArr[p+1] << 16) | (byteArr[p+2] << 8) | byteArr[p+3]) >>> 0;
    }
    for (var j = 16; j < 64; j++) {
      W[j] = (sigma1(W[j-2]) + W[j-7] + sigma0(W[j-15]) + W[j-16]) >>> 0;
    }
    var a = H[0], b = H[1], c = H[2], d = H[3], e = H[4], f = H[5], g = H[6], h = H[7];
    for (var j = 0; j < 64; j++) {
      var T1 = (h + Sigma1(e) + Ch(e, f, g) + K[j] + W[j]) >>> 0;
      var T2 = (Sigma0(a) + Maj(a, b, c)) >>> 0;
      h = g; g = f; f = e; e = (d + T1) >>> 0; d = c; c = b; b = a; a = (T1 + T2) >>> 0;
    }
    H[0] = (H[0] + a) >>> 0; H[1] = (H[1] + b) >>> 0; H[2] = (H[2] + c) >>> 0; H[3] = (H[3] + d) >>> 0;
    H[4] = (H[4] + e) >>> 0; H[5] = (H[5] + f) >>> 0; H[6] = (H[6] + g) >>> 0; H[7] = (H[7] + h) >>> 0;
  }
  var words = [];
  for (var i = 0; i < 8; i++) words.push(H[i]);
  return { words: words, sigBytes: 32 };
}

function __mf_hmac_sha256__(msg, key) {
  var bLen = 64;
  var kBytes = unescape(encodeURIComponent(key));
  if (kBytes.length > bLen) {
    var kh = __mf_sha256__(key);
    var khHex = __mf_hex_from_words__(kh);
    kBytes = '';
    for (var i = 0; i < khHex.length; i += 2) kBytes += String.fromCharCode(parseInt(khHex.substr(i, 2), 16));
  }
  while (kBytes.length < bLen) kBytes += String.fromCharCode(0);
  var iPad = '', oPad = '';
  for (var i = 0; i < bLen; i++) {
    var c = kBytes.charCodeAt(i);
    iPad += String.fromCharCode(c ^ 0x36);
    oPad += String.fromCharCode(c ^ 0x5c);
  }
  var innerHex = __mf_hex_from_words__(__mf_sha256__(iPad + msg));
  var innerBin = '';
  for (var i = 0; i < innerHex.length; i += 2) innerBin += String.fromCharCode(parseInt(innerHex.substr(i, 2), 16));
  return __mf_sha256__(oPad + innerBin);
}

// ===================== MF 纯 JS AES 实现（CBC/PKCS7 + OpenSSL KDF） =====================
var __mf_aes_sbox__ = [
  0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
  0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
  0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
  0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
  0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
  0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
  0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
  0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
  0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
  0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
  0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
  0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
  0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
  0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
  0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
  0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
];
var __mf_aes_inv_sbox__ = [
  0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
  0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
  0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
  0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
  0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
  0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
  0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
  0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
  0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
  0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
  0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
  0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
  0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
  0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
  0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
  0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d
];
var __mf_aes_rcon__ = [0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36];

function __mf_aes_xtime__(a) { return ((a << 1) ^ (((a >> 7) & 1) * 0x1b)) & 0xff; }
function __mf_aes_mul__(a, b) {
  var p = 0;
  for (var i = 0; i < 8; i++) { if (b & 1) p ^= a; a = __mf_aes_xtime__(a); b >>= 1; }
  return p;
}
function __mf_aes_key_exp__(key) {
  var nk = key.length / 4, nb = 4, nr = nk + 6, exp = [];
  for (var i = 0; i < nk; i++) exp[i] = (key[4*i]<<24 | key[4*i+1]<<16 | key[4*i+2]<<8 | key[4*i+3]) >>> 0;
  for (var i = nk; i < nb * (nr + 1); i++) {
    var t = exp[i - 1];
    if (i % nk === 0) t = (__mf_aes_sbox__[(t>>>16)&0xff]<<24 | __mf_aes_sbox__[(t>>>8)&0xff]<<16 | __mf_aes_sbox__[t&0xff]<<8 | __mf_aes_sbox__[(t>>>24)&0xff]) >>> 0 ^ __mf_aes_rcon__[(i/nk)-1];
    else if (nk > 6 && i % nk === 4) t = (__mf_aes_sbox__[(t>>>24)&0xff]<<24 | __mf_aes_sbox__[(t>>>16)&0xff]<<16 | __mf_aes_sbox__[(t>>>8)&0xff]<<8 | __mf_aes_sbox__[t&0xff]) >>> 0;
    exp[i] = (exp[i - nk] ^ t) >>> 0;
  }
  return exp;
}
function __mf_aes_sub_bytes__(s) { for (var i=0;i<4;i++) for (var j=0;j<4;j++) s[i][j] = __mf_aes_sbox__[s[i][j]]; }
function __mf_aes_shift_rows__(s) {
  var t;
  t=s[1][0];s[1][0]=s[1][1];s[1][1]=s[1][2];s[1][2]=s[1][3];s[1][3]=t;
  t=s[2][0];s[2][0]=s[2][2];s[2][2]=t;t=s[2][1];s[2][1]=s[2][3];s[2][3]=t;
  t=s[3][3];s[3][3]=s[3][2];s[3][2]=s[3][1];s[3][1]=s[3][0];s[3][0]=t;
}
function __mf_aes_mix_columns__(s) {
  for (var i = 0; i < 4; i++) {
    var a = s[i][0], b = s[i][1], c = s[i][2], d = s[i][3];
    s[i][0] = __mf_aes_mul__(a,2)^__mf_aes_mul__(b,3)^c^d;
    s[i][1] = a^__mf_aes_mul__(b,2)^__mf_aes_mul__(c,3)^d;
    s[i][2] = a^b^__mf_aes_mul__(c,2)^__mf_aes_mul__(d,3);
    s[i][3] = __mf_aes_mul__(a,3)^b^c^__mf_aes_mul__(d,2);
  }
}
function __mf_aes_add_round_key__(s, k, r) {
  for (var i=0;i<4;i++) for (var j=0;j<4;j++) s[i][j] ^= (k[r*4+j]>>(24-i*8))&0xff;
}
function __mf_aes_encrypt_block__(input, w) {
  var s = [];
  for (var i=0;i<4;i++) { s[i]=[]; for (var j=0;j<4;j++) s[i][j] = input[i*4+j]; }
  var nr = w.length/4 - 1;
  __mf_aes_add_round_key__(s,w,0);
  for (var r = 1; r < nr; r++) { __mf_aes_sub_bytes__(s);__mf_aes_shift_rows__(s);__mf_aes_mix_columns__(s);__mf_aes_add_round_key__(s,w,r); }
  __mf_aes_sub_bytes__(s);__mf_aes_shift_rows__(s);__mf_aes_add_round_key__(s,w,nr);
  var out = [];
  for (var j=0;j<4;j++) for (var i=0;i<4;i++) out.push(s[i][j]);
  return out;
}
function __mf_aes_inv_sub_bytes__(s) { for (var i=0;i<4;i++) for (var j=0;j<4;j++) s[i][j] = __mf_aes_inv_sbox__[s[i][j]]; }
function __mf_aes_inv_shift_rows__(s) {
  var t;
  t=s[1][3];s[1][3]=s[1][2];s[1][2]=s[1][1];s[1][1]=s[1][0];s[1][0]=t;
  t=s[2][0];s[2][0]=s[2][2];s[2][2]=t;t=s[2][1];s[2][1]=s[2][3];s[2][3]=t;
  t=s[3][0];s[3][0]=s[3][1];s[3][1]=s[3][2];s[3][2]=s[3][3];s[3][3]=t;
}
function __mf_aes_inv_mix_columns__(s) {
  for (var i = 0; i < 4; i++) {
    var a = s[i][0], b = s[i][1], c = s[i][2], d = s[i][3];
    s[i][0] = __mf_aes_mul__(a,14)^__mf_aes_mul__(b,11)^__mf_aes_mul__(c,13)^__mf_aes_mul__(d,9);
    s[i][1] = __mf_aes_mul__(a,9)^__mf_aes_mul__(b,14)^__mf_aes_mul__(c,11)^__mf_aes_mul__(d,13);
    s[i][2] = __mf_aes_mul__(a,13)^__mf_aes_mul__(b,9)^__mf_aes_mul__(c,14)^__mf_aes_mul__(d,11);
    s[i][3] = __mf_aes_mul__(a,11)^__mf_aes_mul__(b,13)^__mf_aes_mul__(c,9)^__mf_aes_mul__(d,14);
  }
}
function __mf_aes_decrypt_block__(input, w) {
  var s = [];
  for (var i=0;i<4;i++) { s[i]=[]; for (var j=0;j<4;j++) s[i][j] = input[i*4+j]; }
  var nr = w.length/4 - 1;
  __mf_aes_add_round_key__(s,w,nr);
  for (var r = nr-1; r >= 1; r--) { __mf_aes_inv_shift_rows__(s);__mf_aes_inv_sub_bytes__(s);__mf_aes_add_round_key__(s,w,r);__mf_aes_inv_mix_columns__(s); }
  __mf_aes_inv_shift_rows__(s);__mf_aes_inv_sub_bytes__(s);__mf_aes_add_round_key__(s,w,0);
  var out = [];
  for (var j=0;j<4;j++) for (var i=0;i<4;i++) out.push(s[i][j]);
  return out;
}
function __mf_aes_encrypt_bytes__(data, keyBytes) {
  var nk = keyBytes.length / 4;
  var w = __mf_aes_key_exp__(keyBytes);
  var pad = 16 - (data.length % 16);
  var padded = data.slice();
  for (var i = 0; i < pad; i++) padded.push(pad);
  var out = [];
  for (var i = 0; i < padded.length; i += 16) out = out.concat(__mf_aes_encrypt_block__(padded.slice(i, i+16), w));
  return out;
}
function __mf_aes_decrypt_bytes__(data, keyBytes) {
  var w = __mf_aes_key_exp__(keyBytes);
  var out = [];
  for (var i = 0; i < data.length; i += 16) out = out.concat(__mf_aes_decrypt_block__(data.slice(i, i+16), w));
  var pad = out[out.length - 1];
  if (pad >= 1 && pad <= 16) out = out.slice(0, out.length - pad);
  return out;
}
function __mf_openssl_bytes_to_key__(password, salt, keyLen, ivLen) {
  var d = [], prev = '';
  var pBytes = unescape(encodeURIComponent(password));
  while (d.length < keyLen + ivLen) {
    var md = __lx_md5__(prev + pBytes + salt);
    for (var i = 0; i < md.length; i += 2) d.push(parseInt(md.substr(i, 2), 16));
    prev = md;
    for (var i = 0; i < md.length; i += 2) prev += String.fromCharCode(parseInt(md.substr(i, 2), 16));
    prev = unescape(encodeURIComponent(prev));
  }
  return { key: d.slice(0, keyLen), iv: d.slice(keyLen, keyLen + ivLen) };
}
function __mf_random_bytes__(n) {
  var a = [];
  for (var i = 0; i < n; i++) a.push(Math.floor(Math.random() * 256));
  return a;
}
function __mf_aes_cbc_encrypt__(plaintext, password) {
  var pBytes = []; for (var i = 0; i < plaintext.length; i++) pBytes.push(plaintext.charCodeAt(i));
  var salt = String.fromCharCode.apply(null, __mf_random_bytes__(8));
  var kv = __mf_openssl_bytes_to_key__(password, salt, 16, 16);
  var encrypted = __mf_aes_encrypt_bytes__(pBytes, kv.key);
  var result = [83,97,108,116,101,100,95,95];
  for (var i = 0; i < salt.length; i++) result.push(salt.charCodeAt(i));
  result = result.concat(encrypted);
  var bin = ''; for (var i = 0; i < result.length; i++) bin += String.fromCharCode(result[i]);
  return btoa(bin);
}
function __mf_aes_cbc_decrypt__(ciphertext, password) {
  var bin = atob(ciphertext);
  if (bin.length < 16 || bin.substr(0, 8) !== 'Salted__') return '';
  var salt = bin.substr(8, 8);
  var encrypted = []; for (var i = 16; i < bin.length; i++) encrypted.push(bin.charCodeAt(i));
  var kv = __mf_openssl_bytes_to_key__(password, salt, 16, 16);
  var decrypted = __mf_aes_decrypt_bytes__(encrypted, kv.key);
  var result = ''; for (var i = 0; i < decrypted.length; i++) result += String.fromCharCode(decrypted[i]);
  try { return decodeURIComponent(escape(result)); } catch(e) { return result; }
}

var __mf_CryptoJS__ = {
  MD5: function(msg) {
    var str = (typeof msg === 'object' && msg !== null) ? __mf_utf8_to_str__(msg) : String(msg);
    // 同步：直接用 preload 中的 __lx_md5__（如果可用）
    // 异步：通过 nativeCall 桥接
    if (typeof __lx_md5__ !== 'undefined') {
      var hex = __lx_md5__(str);
      return __mf_word_array_from_hex__(hex);
    }
    // 回退：返回空（实际应该走 nativeCall）
    return { words: [], sigBytes: 0 };
  },
  SHA256: function(msg) {
    var str = (typeof msg === 'object' && msg !== null) ? __mf_utf8_to_str__(msg) : String(msg);
    return __mf_sha256__(str);
  },
  HmacSHA256: function(msg, key) {
    var m = (typeof msg === 'object' && msg !== null) ? __mf_utf8_to_str__(msg) : String(msg);
    var k = (typeof key === 'object' && key !== null) ? __mf_utf8_to_str__(key) : String(key);
    return __mf_hmac_sha256__(m, k);
  },
  AES: {
    encrypt: function(msg, key) {
      var m = (typeof msg === 'object' && msg !== null) ? __mf_utf8_to_str__(msg) : String(msg);
      var k = (typeof key === 'object' && key !== null) ? __mf_hex_from_words__(key) : String(key);
      var b64 = __mf_aes_cbc_encrypt__(m, k);
      return { ciphertext: b64, toString: function(enc) { return b64; } };
    },
    decrypt: function(ciphertext, key) {
      var c = typeof ciphertext === 'string' ? ciphertext : (ciphertext.ciphertext || '');
      var k = (typeof key === 'object' && key !== null) ? __mf_hex_from_words__(key) : String(key);
      var pt = __mf_aes_cbc_decrypt__(c, k);
      var wa = __mf_str_to_utf8__(pt);
      return { words: wa.words, sigBytes: wa.sigBytes, toString: function(enc) {
        if (enc && enc === __mf_CryptoJS__.enc.Utf8) return pt;
        return pt;
      }};
    }
  },
  enc: {
    Hex: {
      stringify: function(wa) { return __mf_hex_from_words__(wa); },
      parse: function(hex) { return __mf_word_array_from_hex__(hex); }
    },
    Utf8: {
      stringify: function(wa) { return __mf_utf8_to_str__(wa); },
      parse: function(str) { return __mf_str_to_utf8__(str); }
    },
    Base64: {
      stringify: function(wa) {
        var hex = __mf_hex_from_words__(wa);
        var bin = '';
        for (var i = 0; i < hex.length; i += 2) bin += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        return btoa(bin);
      },
      parse: function(b64) {
        var bin = atob(b64);
        var hex = '';
        for (var i = 0; i < bin.length; i++) hex += (bin.charCodeAt(i).toString(16).padStart(2, '0'));
        return __mf_word_array_from_hex__(hex);
      }
    },
    Latin1: {
      stringify: function(wa) { return __mf_hex_from_words__(wa).replace(/(.{2})/g, function(m) { return String.fromCharCode(parseInt(m, 16)); }); },
      parse: function(str) { var hex = ''; for (var i = 0; i < str.length; i++) hex += str.charCodeAt(i).toString(16).padStart(2, '0'); return __mf_word_array_from_hex__(hex); }
    }
  }
};

// 处理 CryptoJS 的异步加密操作
function __mf_process_crypto__(data) {
  return __mf_crypto_call__(data.action, data.data);
}

// ===================== MF qs 桥接（纯 JS） =====================
var __mf_qs__ = {
  stringify: function(obj, sep, eq, options) {
    if (!obj) return '';
    sep = sep || '&';
    eq = eq || '=';
    var parts = [];
    var keys = Object.keys(obj);
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      var val = obj[key];
      if (val === undefined || val === null) continue;
      if (Array.isArray(val)) {
        for (var j = 0; j < val.length; j++) {
          parts.push(encodeURIComponent(key) + eq + encodeURIComponent(val[j]));
        }
      } else {
        parts.push(encodeURIComponent(key) + eq + encodeURIComponent(val));
      }
    }
    return parts.join(sep);
  },
  parse: function(str, sep, eq, options) {
    if (!str) return {};
    // 去掉开头的 ? 或 #
    if (str.charAt(0) === '?') str = str.substr(1);
    if (str.charAt(0) === '#') str = str.substr(1);
    sep = sep || '&';
    eq = eq || '=';
    var result = {};
    var pairs = str.split(sep);
    for (var i = 0; i < pairs.length; i++) {
      var pair = pairs[i];
      var idx = pair.indexOf(eq);
      if (idx < 0) {
        result[decodeURIComponent(pair)] = '';
      } else {
        var key = decodeURIComponent(pair.substr(0, idx));
        var val = decodeURIComponent(pair.substr(idx + eq.length));
        if (result[key] !== undefined) {
          if (!Array.isArray(result[key])) result[key] = [result[key]];
          result[key].push(val);
        } else {
          result[key] = val;
        }
      }
    }
    return result;
  }
};

// ===================== MF he 桥接（纯 JS） =====================
var __mf_he_entities__ = {
  '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'",
  '&apos;': "'", '&nbsp;': ' ', '&copy;': '©', '&reg;': '®', '&trade;': '™',
  '&mdash;': '—', '&ndash;': '–', '&hellip;': '…', '&laquo;': '«', '&raquo;': '»'
};

var __mf_he__ = {
  decode: function(str, options) {
    if (!str) return '';
    // 处理命名实体
    str = str.replace(/&[a-zA-Z]+;/g, function(entity) {
      return __mf_he_entities__[entity] || entity;
    });
    // 处理数字实体 &#123; 和十六进制 &#x1F;
    str = str.replace(/&#(\d+);/g, function(m, code) {
      return String.fromCharCode(parseInt(code, 10));
    });
    str = str.replace(/&#x([0-9a-fA-F]+);/g, function(m, code) {
      return String.fromCharCode(parseInt(code, 16));
    });
    return str;
  },
  encode: function(str, options) {
    if (!str) return '';
    var entities = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
    return str.replace(/[&<>"']/g, function(ch) { return entities[ch]; });
  }
};

// ===================== MF cheerio 实现（轻量 HTML 解析器 + CSS 选择器） =====================
var __mf_cheerio__ = (function() {
  var SELF_CLOSE = { img:1, br:1, hr:1, input:1, meta:1, link:1, area:1, base:1, col:1, embed:1, source:1, track:1, wbr:1 };

  // 解析 HTML 为扁平元素列表
  function parseHtml(html) {
    var elems = [{ tag:'_root', attrStr:'', ch:[], par:-1, text:'' }];
    var stk = [0], pos = 0, len = html.length;
    while (pos < len) {
      if (html[pos] === '<') {
        var end = html.indexOf('>', pos);
        if (end === -1) break;
        if (html[pos+1] === '!') {
          if (html.substr(pos+2, 2) === '--') {
            pos = html.indexOf('-->', pos+3);
            if (pos === -1) break; pos += 3;
          } else { pos = end + 1; }
          continue;
        }
        if (html[pos+1] === '/') {
          var clTag = html.substring(pos+2, end).trim().toLowerCase();
          for (var si = stk.length-1; si > 0; si--) {
            if (elems[stk[si]].tag === clTag) { stk.length = si; break; }
          }
          pos = end + 1; continue;
        }
        var inner = html.substring(pos+1, end);
        var sp = inner.search(/[\s\/]/);
        var tag, attrStr;
        if (sp === -1) { tag = inner.toLowerCase(); attrStr = ''; }
        else { tag = inner.substring(0, sp).toLowerCase(); attrStr = inner.substring(sp); }
        var selfClose = SELF_CLOSE[tag] || inner[inner.length-1] === '/';
        var idx = elems.length;
        elems.push({ tag:tag, attrStr:attrStr, ch:[], par:stk[stk.length-1], text:'' });
        elems[stk[stk.length-1]].ch.push(idx);
        if (!selfClose) stk.push(idx);
        pos = end + 1;
      } else {
        var nx = html.indexOf('<', pos);
        if (nx === -1) nx = len;
        var txt = html.substring(pos, nx);
        if (txt.replace(/\s+/g, '').length > 0) {
          var ti = elems.length;
          elems.push({ tag:'_text', attrStr:'', ch:[], par:stk[stk.length-1], text:txt });
          elems[stk[stk.length-1]].ch.push(ti);
        }
        pos = nx;
      }
    }
    return elems;
  }

  // 解析属性字符串
  function parseAttrs(attrStr) {
    var attrs = {};
    var rx = /([\w\-:]+)(?:=(?:'([^']*)'|"([^"]*)"|(\S+)))?/g;
    var m;
    while ((m = rx.exec(attrStr)) !== null) {
      attrs[m[1].toLowerCase()] = m[2] !== undefined ? m[2] : (m[3] !== undefined ? m[3] : (m[4] !== undefined ? m[4] : ''));
    }
    return attrs;
  }

  // 解析单个选择器片段（支持 tag.class#id[attr] 复合写法）
  function parseSel(sel) {
    var parts = [];
    var rx = /\.([a-zA-Z0-9_-]+)|#([a-zA-Z0-9_-]+)|\[([^\]]+)\]|([a-zA-Z][\w-]*)/g;
    var m, hasTag = false;
    while ((m = rx.exec(sel)) !== null) {
      if (m[1] !== undefined) { parts.push({ t:'cls', v:m[1] }); }
      else if (m[2] !== undefined) { parts.push({ t:'id', v:m[2] }); }
      else if (m[3] !== undefined) {
        var am = m[3].match(/^([\w\-:]+)(?:([~|^$*]?=)\s*['"]?([^'"\]]*)['"]?)?$/);
        if (am) parts.push({ t:'attr', k:am[1].toLowerCase(), op:am[2]||'', v:am[3]||'' });
      }
      else if (m[4] !== undefined) { parts.push({ t:'tag', v:m[4].toLowerCase() }); hasTag = true; }
    }
    if (!hasTag && parts.length > 0) {
      // 如果没有显式 tag，需要匹配任何 tag
      var hasExplicitMatch = false;
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].t === 'tag') { hasExplicitMatch = true; break; }
      }
      if (!hasExplicitMatch) parts.unshift({ t:'any' });
    }
    return parts;
  }

  // 匹配元素
  function matchSel(elems, idx, parts) {
    var el = elems[idx];
    if (!el || el.tag === '_text' || el.tag === '_root') return false;
    var attrs = null;
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i];
      if (p.t === 'tag' && el.tag !== p.v) return false;
      if (p.t === 'any') { if (el.tag === '_text' || el.tag === '_root') return false; }
      if (p.t === 'cls') {
        if (!attrs) attrs = parseAttrs(el.attrStr);
        var cls = (attrs['class'] || '');
        if ((' '+cls+' ').indexOf(' '+p.v+' ') < 0) return false;
      }
      if (p.t === 'id') {
        if (!attrs) attrs = parseAttrs(el.attrStr);
        if (attrs['id'] !== p.v) return false;
      }
      if (p.t === 'attr') {
        if (!attrs) attrs = parseAttrs(el.attrStr);
        var av = attrs[p.k];
        if (av === undefined) return false;
        if (!p.op) continue;
        if (p.op === '=' && av !== p.v) return false;
        if (p.op === '*=' && av.indexOf(p.v) < 0) return false;
        if (p.op === '^=' && av.substring(0, p.v.length) !== p.v) return false;
        if (p.op === '$=' && av.substring(av.length - p.v.length) !== p.v) return false;
        if (p.op === '~=' && (' '+av+' ').indexOf(' '+p.v+' ') < 0) return false;
      }
    }
    return true;
  }

  // 递归查找
  function findIn(elems, rootIdx, result, matchFn) {
    var ch = elems[rootIdx].ch;
    for (var i = 0; i < ch.length; i++) {
      if (matchFn(elems, ch[i])) result.push(ch[i]);
      findIn(elems, ch[i], result, matchFn);
    }
  }

  // 提取元素 innerHTML
  function getInnerHtml(elems, idx) {
    var el = elems[idx];
    if (el.tag === '_text') return el.text;
    var html = '';
    for (var i = 0; i < el.ch.length; i++) {
      var child = elems[el.ch[i]];
      if (child.tag === '_text') { html += child.text; }
      else { html += getOuterHtml(elems, el.ch[i]); }
    }
    return html;
  }

  function getOuterHtml(elems, idx) {
    var el = elems[idx];
    if (el.tag === '_text') return el.text;
    var inner = getInnerHtml(elems, idx);
    return '<' + el.tag + (el.attrStr ? ' ' + el.attrStr.trim() : '') + '>' + inner + '</' + el.tag + '>';
  }

  // 提取纯文本
  function getText(elems, idx) {
    var el = elems[idx];
    if (el.tag === '_text') return el.text;
    var t = '';
    for (var i = 0; i < el.ch.length; i++) t += getText(elems, el.ch[i]);
    return t;
  }

  // cheerio 对象构造
  function makeCheerio(elems, indices) {
    var arr = indices || [];
    var obj = {
      length: arr.length,
      each: function(fn) { for (var i = 0; i < arr.length; i++) fn.call(makeCheerio(elems, [arr[i]]), i); return obj; },
      map: function(fn) { var r = []; for (var i = 0; i < arr.length; i++) r.push(fn.call(makeCheerio(elems, [arr[i]]), i)); return r; },
      eq: function(i) { return i >= 0 && i < arr.length ? makeCheerio(elems, [arr[i]]) : makeCheerio(elems, []); },
      first: function() { return obj.eq(0); },
      last: function() { return obj.eq(arr.length - 1); },
      text: function() { var t = ''; for (var i = 0; i < arr.length; i++) t += getText(elems, arr[i]); return t.replace(/\s+/g, ' ').trim(); },
      html: function() { return arr.length > 0 ? getInnerHtml(elems, arr[0]) : null; },
      attr: function(name) {
        if (arr.length === 0) return undefined;
        var attrs = parseAttrs(elems[arr[0]].attrStr);
        return attrs[name.toLowerCase()];
      },
      find: function(sel) {
        var res = [];
        var sParts = parseSel(sel.trim());
        var hasChild = false;
        for (var si = 0; si < sParts.length; si++) { if (sParts[si].t === 'tag' || sParts[si].t === 'cls' || sParts[si].t === 'id' || sParts[si].t === 'attr') { hasChild = true; break; } }
        if (!hasChild) return makeCheerio(elems, []);
        for (var i = 0; i < arr.length; i++) {
          findIn(elems, arr[i], res, function(e, idx) { return matchSel(e, idx, sParts); });
        }
        return makeCheerio(elems, res);
      },
      closest: function(sel) {
        var sParts = parseSel(sel.trim());
        for (var i = 0; i < arr.length; i++) {
          var p = elems[arr[i]].par;
          while (p > 0) {
            if (matchSel(elems, p, sParts)) return makeCheerio(elems, [p]);
            p = elems[p].par;
          }
        }
        return makeCheerio(elems, []);
      },
      parent: function() {
        var res = [];
        for (var i = 0; i < arr.length; i++) {
          var p = elems[arr[i]].par;
          if (p > 0 && res.indexOf(p) < 0) res.push(p);
        }
        return makeCheerio(elems, res);
      },
      children: function(sel) {
        var res = [];
        var sParts = sel ? parseSel(sel.trim()) : null;
        for (var i = 0; i < arr.length; i++) {
          var ch = elems[arr[i]].ch;
          for (var j = 0; j < ch.length; j++) {
            if (!sParts || matchSel(elems, ch[j], sParts)) res.push(ch[j]);
          }
        }
        return makeCheerio(elems, res);
      },
      contents: function() { return obj.children(); },
      next: function() {
        var res = [];
        for (var i = 0; i < arr.length; i++) {
          var par = elems[arr[i]].par;
          if (par < 0) continue;
          var sibs = elems[par].ch;
          var myIdx = sibs.indexOf(arr[i]);
          if (myIdx >= 0 && myIdx + 1 < sibs.length) res.push(sibs[myIdx + 1]);
        }
        return makeCheerio(elems, res);
      },
      prev: function() {
        var res = [];
        for (var i = 0; i < arr.length; i++) {
          var par = elems[arr[i]].par;
          if (par < 0) continue;
          var sibs = elems[par].ch;
          var myIdx = sibs.indexOf(arr[i]);
          if (myIdx > 0) res.push(sibs[myIdx - 1]);
        }
        return makeCheerio(elems, res);
      },
      siblings: function() {
        var res = [];
        for (var i = 0; i < arr.length; i++) {
          var par = elems[arr[i]].par;
          if (par < 0) continue;
          var sibs = elems[par].ch;
          for (var j = 0; j < sibs.length; j++) {
            if (sibs[j] !== arr[i] && res.indexOf(sibs[j]) < 0) res.push(sibs[j]);
          }
        }
        return makeCheerio(elems, res);
      },
      get: function(i) { return i >= 0 ? arr[i] : arr[arr.length + i]; },
      toArray: function() { return arr.slice(); },
      val: function() { return obj.attr('value') || ''; },
      prop: function(name) { return obj.attr(name); },
      hasClass: function(cls) {
        if (arr.length === 0) return false;
        var a = parseAttrs(elems[arr[0]].attrStr);
        return (' '+(a['class']||'')+' ').indexOf(' '+cls+' ') >= 0;
      }
    };
    return obj;
  }

  return {
    load: function(html) {
      var elems = parseHtml(html || '');
      var $ = function(sel) {
        if (!sel) return makeCheerio(elems, []);
        if (typeof sel === 'string') {
          // 简单 CSS 选择器：支持逗号分隔的多选择器
          var parts = sel.split(',');
          var allRes = [];
          for (var pi = 0; pi < parts.length; pi++) {
            var trimmed = parts[pi].trim();
            if (!trimmed) continue;

            // 处理 "parent > child" 直接子选择器
            var gtParts = trimmed.split('>');
            if (gtParts.length === 2) {
              var parentSel = gtParts[0].trim();
              var childSel = gtParts[1].trim();
              var parentParts = parseSel(parentSel);
              var childParts = parseSel(childSel);
              var parentRes = [];
              findIn(elems, 0, parentRes, function(e, idx) { return matchSel(e, idx, parentParts); });
              for (var pri = 0; pri < parentRes.length; pri++) {
                var chs = elems[parentRes[pri]].ch;
                for (var ci = 0; ci < chs.length; ci++) {
                  if (matchSel(elems, chs[ci], childParts) && allRes.indexOf(chs[ci]) < 0) allRes.push(chs[ci]);
                }
              }
              continue;
            }

            // 处理 "ancestor descendant" 后代选择器
            var spaceParts = trimmed.split(/\s+/);
            if (spaceParts.length >= 2) {
              // 先找最右边的
              var lastSel = parseSel(spaceParts[spaceParts.length - 1]);
              var candidates = [];
              findIn(elems, 0, candidates, function(e, idx) { return matchSel(e, idx, lastSel); });
              // 逐级向上验证祖先
              for (var si = spaceParts.length - 2; si >= 0; si--) {
                var ancParts = parseSel(spaceParts[si]);
                var filtered = [];
                for (var ci2 = 0; ci2 < candidates.length; ci2++) {
                  var p2 = elems[candidates[ci2]].par;
                  while (p2 > 0) {
                    if (matchSel(elems, p2, ancParts)) { filtered.push(candidates[ci2]); break; }
                    p2 = elems[p2].par;
                  }
                }
                candidates = filtered;
              }
              for (var ri = 0; ri < candidates.length; ri++) {
                if (allRes.indexOf(candidates[ri]) < 0) allRes.push(candidates[ri]);
              }
              continue;
            }

            // 简单选择器
            var sParts = parseSel(trimmed);
            var res = [];
            findIn(elems, 0, res, function(e, idx) { return matchSel(e, idx, sParts); });
            for (var ri2 = 0; ri2 < res.length; ri2++) {
              if (allRes.indexOf(res[ri2]) < 0) allRes.push(res[ri2]);
            }
          }
          return makeCheerio(elems, allRes);
        }
        return makeCheerio(elems, []);
      };
      $.root = function() { return makeCheerio(elems, [0]); };
      $.html = function() { return getInnerHtml(elems, 0); };
      $.text = function() { return getText(elems, 0).replace(/\s+/g, ' ').trim(); };
      return $;
    }
  };
})();

// ===================== MF dayjs 简化版 =====================
var __mf_dayjs__ = function(date) {
  var d = date ? new Date(date) : new Date();
  return {
    format: function(fmt) {
      if (!fmt) return d.toISOString();
      var pad = function(n) { return n < 10 ? '0' + n : '' + n; };
      return fmt
        .replace('YYYY', d.getFullYear())
        .replace('MM', pad(d.getMonth() + 1))
        .replace('DD', pad(d.getDate()))
        .replace('HH', pad(d.getHours()))
        .replace('mm', pad(d.getMinutes()))
        .replace('ss', pad(d.getSeconds()));
    },
    valueOf: function() { return d.getTime(); },
    unix: function() { return Math.floor(d.getTime() / 1000); },
  };
};

// ===================== MF big-integer 简化版 =====================
var __mf_biginteger__ = function(n) {
  var val = BigInt(n || 0);
  var _zero = BigInt(0);
  return {
    value: val,
    toString: function(radix) { return val.toString(radix || 10); },
    add: function(x) { return __mf_biginteger__(val + BigInt(x.value || x)); },
    subtract: function(x) { return __mf_biginteger__(val - BigInt(x.value || x)); },
    multiply: function(x) { return __mf_biginteger__(val * BigInt(x.value || x)); },
    divide: function(x) { return __mf_biginteger__(val / BigInt(x.value || x)); },
    mod: function(x) { return __mf_biginteger__(val % BigInt(x.value || x)); },
    compareTo: function(x) { var b = BigInt(x.value || x); return val < b ? -1 : val > b ? 1 : 0; },
    equals: function(x) { return val === BigInt(x.value || x); },
    isNegative: function() { return val < _zero; },
    isZero: function() { return val === _zero; },
    abs: function() { return __mf_biginteger__(val < _zero ? -val : val); },
  };
};

// ===================== MF require 函数 =====================
var __mf_packages__ = {
  'axios': __mf_axios__,
  'crypto-js': __mf_CryptoJS__,
  'qs': __mf_qs__,
  'he': __mf_he__,
  'cheerio': __mf_cheerio__,
  'dayjs': __mf_dayjs__,
  'big-integer': __mf_biginteger__,
};

function __mf_require__(packageName) {
  var pkg = __mf_packages__[packageName];
  if (!pkg) throw new Error('Cannot find module: ' + packageName);
  // 支持 function 和 object 两种类型的 default（axios 是 function）
  if (typeof pkg === 'object' || typeof pkg === 'function') pkg.default = pkg;
  return pkg;
}

// ===================== MF URL Polyfill =====================
var URL = (function() {
  function URL(url, base) {
    if (base) {
      // 简单的 base + relative 合并
      if (url.indexOf('://') > 0) {
        this._parse(url);
        return;
      }
      var b = new URL(base);
      if (url.charAt(0) === '/') {
        this._parse(b.protocol + '//' + b.host + url);
      } else {
        var basePath = b.pathname.replace(/\/[^\/]*$/, '');
        this._parse(b.protocol + '//' + b.host + basePath + '/' + url);
      }
    } else {
      this._parse(url);
    }
  }
  URL.prototype._parse = function(href) {
    this.href = href;
    var m = href.match(/^([a-z][a-z0-9+.-]*:)?(\/\/([^\/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?$/i);
    this.protocol = (m && m[1]) || '';
    this.host = (m && m[3]) || '';
    this.hostname = this.host.replace(/:\d+$/, '');
    this.port = (this.host.match(/:(\d+)$/) || [])[1] || '';
    this.pathname = (m && m[4]) || '/';
    this.search = (m && m[5]) || '';
    this.hash = (m && m[7]) || '';
    this.origin = this.protocol + '//' + this.host;
  };
  URL.prototype.toString = function() { return this.href; };
  URL.createObjectURL = function() { return ''; };
  URL.revokeObjectURL = function() {};
  return URL;
})();

var URLSearchParams = (function() {
  function URLSearchParams(init) {
    this._params = [];
    if (typeof init === 'string') {
      init = init.replace(/^\?/, '');
      var pairs = init.split('&');
      for (var i = 0; i < pairs.length; i++) {
        var kv = pairs[i].split('=');
        if (kv[0]) this._params.push([decodeURIComponent(kv[0]), decodeURIComponent(kv[1] || '')]);
      }
    }
  }
  URLSearchParams.prototype.get = function(k) {
    for (var i = 0; i < this._params.length; i++) {
      if (this._params[i][0] === k) return this._params[i][1];
    }
    return null;
  };
  URLSearchParams.prototype.getAll = function(k) {
    var r = [];
    for (var i = 0; i < this._params.length; i++) {
      if (this._params[i][0] === k) r.push(this._params[i][1]);
    }
    return r;
  };
  URLSearchParams.prototype.has = function(k) { return this.get(k) !== null; };
  URLSearchParams.prototype.toString = function() {
    return this._params.map(function(p) { return encodeURIComponent(p[0]) + '=' + encodeURIComponent(p[1]); }).join('&');
  };
  return URLSearchParams;
})();

// ===================== MF console 桥接 =====================
var __mf_console__ = {
  log: function() {
    var msg = Array.prototype.slice.call(arguments).map(function(a) {
      return typeof a === 'object' ? JSON.stringify(a) : String(a);
    }).join(' ');
    __mf_push_event__('__log__', {msg: '[MF] ' + msg});
  },
  error: function() { this.log.apply(this, arguments); },
  warn: function() { this.log.apply(this, arguments); },
  info: function() { this.log.apply(this, arguments); },
};

// ===================== MF 插件执行 =====================
// 执行 MusicFree 格式的插件代码，返回 module.exports 对象
function executeMfPlugin(funcCode, env) {
  var _module = { exports: {} };
  var _process = {
    platform: 'android',
    version: env && env.appVersion ? env.appVersion : '1.0.0',
    env: env || { appVersion: '1.0.0', os: 'android', lang: 'zh-CN' }
  };

  try {
    var wrapper = new Function(
      'require', '__musicfree_require', 'module', 'exports', 'console', 'env', 'URL', 'process',
      "'use strict';\n" + funcCode
    );
    var result = wrapper(
      __mf_require__,
      __mf_require__,
      _module,
      _module.exports,
      __mf_console__,
      _process.env,
      URL,
      _process
    );

    var instance = _module.exports.default || _module.exports || result;
    return { success: true, instance: instance };
  } catch (e) {
    return { success: false, error: e.message || String(e) };
  }
}
''';
