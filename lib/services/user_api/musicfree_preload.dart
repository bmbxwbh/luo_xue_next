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
    return { _sha256_async: true, _input: str, words: [], sigBytes: 0 };
  },
  HmacSHA256: function(msg, key) {
    var m = (typeof msg === 'object' && msg !== null) ? __mf_utf8_to_str__(msg) : String(msg);
    var k = (typeof key === 'object' && key !== null) ? __mf_utf8_to_str__(key) : String(key);
    return { _hmac_sha256_async: true, _msg: m, _key: k, words: [], sigBytes: 0 };
  },
  AES: {
    encrypt: function(msg, key) {
      var m = (typeof msg === 'object' && msg !== null) ? __mf_utf8_to_str__(msg) : String(msg);
      var k = (typeof key === 'object' && key !== null) ? __mf_hex_from_words__(key) : String(key);
      return { _aes_encrypt_async: true, _msg: m, _key: k, toString: function() { return this._ciphertext || ''; } };
    },
    decrypt: function(ciphertext, key) {
      var c = typeof ciphertext === 'string' ? ciphertext : (ciphertext.ciphertext || '');
      var k = (typeof key === 'object' && key !== null) ? __mf_hex_from_words__(key) : String(key);
      return { _aes_decrypt_async: true, _ciphertext: c, _key: k, toString: function() { return this._plaintext || ''; } };
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

// ===================== MF cheerio stub =====================
var __mf_cheerio__ = {
  load: function(html) {
    // stub：返回空的 $ 函数
    var $ = function(selector) {
      return {
        text: function() { return ''; },
        attr: function(name) { return null; },
        html: function() { return ''; },
        find: function(sel) { return $(sel); },
        each: function(fn) { return this; },
        map: function(fn) { return []; },
        length: 0,
        eq: function(i) { return $(selector); },
        first: function() { return $(selector); },
        last: function() { return $(selector); },
      };
    };
    return $;
  }
};

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
    isNegative: function() { return val < 0n; },
    isZero: function() { return val === 0n; },
    abs: function() { return __mf_biginteger__(val < 0n ? -val : val); },
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
  if (typeof pkg === 'object') pkg.default = pkg;
  return pkg;
}

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
