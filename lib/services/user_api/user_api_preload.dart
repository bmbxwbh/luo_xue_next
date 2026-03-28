/// 用户 API 预加载脚本 — 纯 JS 实现工具函数，无需 Dart 桥接
const String kUserApiPreloadScript = '''
'use strict';

// === atob/btoa polyfill（QuickJS 不自带）===
var __lx_b64chars__ = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
function atob(input) {
  var str = String(input).replace(/=+\$/, '');
  if (str.length % 4 === 1) throw new Error("'atob' failed: invalid input");
  var output = '', buffer, idx = 0;
  for (var i = 0; i < str.length; i++) {
    buffer = (buffer << 6) | __lx_b64chars__.indexOf(str.charAt(i));
    if (++idx === 4) {
      output += String.fromCharCode((buffer >> 16) & 0xFF);
      if (str.charAt(i - 1) !== '=') output += String.fromCharCode((buffer >> 8) & 0xFF);
      if (str.charAt(i) !== '=') output += String.fromCharCode(buffer & 0xFF);
      buffer = idx = 0;
    }
  }
  return output;
}
function btoa(input) {
  var str = String(input), output = '';
  for (var i = 0; i < str.length; i += 3) {
    var a = str.charCodeAt(i), b = i + 1 < str.length ? str.charCodeAt(i + 1) : 0, c = i + 2 < str.length ? str.charCodeAt(i + 2) : 0;
    var bitmap = (a << 16) | (b << 8) | c;
    output += __lx_b64chars__.charAt((bitmap >> 18) & 63) + __lx_b64chars__.charAt((bitmap >> 12) & 63);
    output += (i + 1 < str.length ? __lx_b64chars__.charAt((bitmap >> 6) & 63) : '=');
    output += (i + 2 < str.length ? __lx_b64chars__.charAt(bitmap & 63) : '=');
  }
  return output;
}

// === 纯 JS MD5 实现（RFC 1321 标准）===
var __lx_md5__ = (function(){
  var S11=7,S12=12,S13=17,S14=22,S21=5,S22=9,S23=14,S24=20,S31=4,S32=11,S33=16,S34=23,S41=6,S42=10,S43=15,S44=21;
  var T=[];for(var i=0;i<64;i++)T[i]=Math.floor(4294967296*Math.abs(Math.sin(i+1)))>>>0;
  function F(x,y,z){return(x&y)|((~x)&z);}
  function G(x,y,z){return(x&z)|(y&(~z));}
  function H(x,y,z){return x^y^z;}
  function I(x,y,z){return y^(x|(~z));}
  function R(n,s){return(n<<s)|(n>>>(32-s));}
  function add(a,b){return(a+b)>>>0;}
  function FF(a,b,c,d,x,s,t){return add(R(add(add(a,F(b,c,d)),add(x,t)),s),b);}
  function GG(a,b,c,d,x,s,t){return add(R(add(add(a,G(b,c,d)),add(x,t)),s),b);}
  function HH(a,b,c,d,x,s,t){return add(R(add(add(a,H(b,c,d)),add(x,t)),s),b);}
  function II(a,b,c,d,x,s,t){return add(R(add(add(a,I(b,c,d)),add(x,t)),s),b);}
  function hash(s){
    var bytes=[];for(var i=0;i<s.length;i++)bytes.push(s.charCodeAt(i));
    var bLen=bytes.length*8;bytes.push(0x80);while(bytes.length%64!==56)bytes.push(0);
    var lo=bLen>>>0,hi=Math.floor(bLen/4294967296)>>>0;
    bytes.push(lo&0xFF,(lo>>8)&0xFF,(lo>>16)&0xFF,(lo>>24)&0xFF);
    bytes.push(hi&0xFF,(hi>>8)&0xFF,(hi>>16)&0xFF,(hi>>24)&0xFF);
    var a=0x67452301,b=0xefcdab89,c=0x98badcfe,d=0x10325476;
    for(var o=0;o<bytes.length;o+=64){
      var X=[];for(var i=0;i<16;i++){var j=o+i*4;X[i]=(bytes[j]|(bytes[j+1]<<8)|(bytes[j+2]<<16)|(bytes[j+3]<<24))>>>0;}
      var aa=a,bb=b,cc=c,dd=d;
      a=FF(a,b,c,d,X[0],S11,T[0]);d=FF(d,a,b,c,X[1],S12,T[1]);c=FF(c,d,a,b,X[2],S13,T[2]);b=FF(b,c,d,a,X[3],S14,T[3]);
      a=FF(a,b,c,d,X[4],S11,T[4]);d=FF(d,a,b,c,X[5],S12,T[5]);c=FF(c,d,a,b,X[6],S13,T[6]);b=FF(b,c,d,a,X[7],S14,T[7]);
      a=FF(a,b,c,d,X[8],S11,T[8]);d=FF(d,a,b,c,X[9],S12,T[9]);c=FF(c,d,a,b,X[10],S13,T[10]);b=FF(b,c,d,a,X[11],S14,T[11]);
      a=FF(a,b,c,d,X[12],S11,T[12]);d=FF(d,a,b,c,X[13],S12,T[13]);c=FF(c,d,a,b,X[14],S13,T[14]);b=FF(b,c,d,a,X[15],S14,T[15]);
      a=GG(a,b,c,d,X[1],S21,T[16]);d=GG(d,a,b,c,X[6],S22,T[17]);c=GG(c,d,a,b,X[11],S23,T[18]);b=GG(b,c,d,a,X[0],S24,T[19]);
      a=GG(a,b,c,d,X[5],S21,T[20]);d=GG(d,a,b,c,X[10],S22,T[21]);c=GG(c,d,a,b,X[15],S23,T[22]);b=GG(b,c,d,a,X[4],S24,T[23]);
      a=GG(a,b,c,d,X[9],S21,T[24]);d=GG(d,a,b,c,X[14],S22,T[25]);c=GG(c,d,a,b,X[3],S23,T[26]);b=GG(b,c,d,a,X[8],S24,T[27]);
      a=GG(a,b,c,d,X[13],S21,T[28]);d=GG(d,a,b,c,X[2],S22,T[29]);c=GG(c,d,a,b,X[7],S23,T[30]);b=GG(b,c,d,a,X[12],S24,T[31]);
      a=HH(a,b,c,d,X[5],S31,T[32]);d=HH(d,a,b,c,X[8],S32,T[33]);c=HH(c,d,a,b,X[11],S33,T[34]);b=HH(b,c,d,a,X[14],S34,T[35]);
      a=HH(a,b,c,d,X[1],S31,T[36]);d=HH(d,a,b,c,X[4],S32,T[37]);c=HH(c,d,a,b,X[7],S33,T[38]);b=HH(b,c,d,a,X[10],S34,T[39]);
      a=HH(a,b,c,d,X[13],S31,T[40]);d=HH(d,a,b,c,X[0],S32,T[41]);c=HH(c,d,a,b,X[3],S33,T[42]);b=HH(b,c,d,a,X[6],S34,T[43]);
      a=HH(a,b,c,d,X[9],S31,T[44]);d=HH(d,a,b,c,X[12],S32,T[45]);c=HH(c,d,a,b,X[15],S33,T[46]);b=HH(b,c,d,a,X[2],S34,T[47]);
      a=II(a,b,c,d,X[0],S41,T[48]);d=II(d,a,b,c,X[7],S42,T[49]);c=II(c,d,a,b,X[14],S43,T[50]);b=II(b,c,d,a,X[5],S44,T[51]);
      a=II(a,b,c,d,X[12],S41,T[52]);d=II(d,a,b,c,X[3],S42,T[53]);c=II(c,d,a,b,X[10],S43,T[54]);b=II(b,c,d,a,X[1],S44,T[55]);
      a=II(a,b,c,d,X[8],S41,T[56]);d=II(d,a,b,c,X[15],S42,T[57]);c=II(c,d,a,b,X[6],S43,T[58]);b=II(b,c,d,a,X[13],S44,T[59]);
      a=II(a,b,c,d,X[4],S41,T[60]);d=II(d,a,b,c,X[11],S42,T[61]);c=II(c,d,a,b,X[2],S43,T[62]);b=II(b,c,d,a,X[9],S44,T[63]);
      a=add(a,aa);b=add(b,bb);c=add(c,cc);d=add(d,dd);
    }
    function hex(n){return(((n>>>0)&0xFF).toString(16).padStart(2,'0'))+(((n>>>8)&0xFF).toString(16).padStart(2,'0'))+(((n>>>16)&0xFF).toString(16).padStart(2,'0'))+(((n>>>24)&0xFF).toString(16).padStart(2,'0'));}
    return hex(a)+hex(b)+hex(c)+hex(d);
  }
  return function(s){return hash(unescape(encodeURIComponent(s)));};
})();

// === 纯 JS SHA-256 实现（RFC 6234 标准）===
var __lx_sha256__ = (function(){
  var K=[1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,
    3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580,
    3835390401,4022224774,264347078,604807628,770255983,1249150122,1555081692,1996064986,
    2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,113926993,338241895,
    666307205,773529912,1294757372,1396182291,1695183700,1986661051,2177026350,2456956037,
    2730485921,2820302411,3259730800,3345764771,3516065817,3600352804,4094571909,275423344,
    430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,
    1955562222,2024104815,2227730452,2361852424,2428436474,2756734187,3204031479,3329325298];
  function R(n,x){return(x>>>n)|(x<<(32-n));}
  function Ch(x,y,z){return(x&y)^(~x&z);}
  function Maj(x,y,z){return(x&y)^(x&z)^(y&z);}
  function S0(x){return R(2,x)^R(13,x)^R(22,x);}
  function S1(x){return R(6,x)^R(11,x)^R(25,x);}
  function s0(x){return R(7,x)^R(18,x)^(x>>>3);}
  function s1(x){return R(17,x)^R(19,x)^(x>>>10);}
  function hash(bytes){
    var bl=bytes.length*8;bytes.push(0x80);while(bytes.length%64!==56)bytes.push(0);
    var lo=bl>>>0,hi=Math.floor(bl/4294967296)>>>0;
    bytes.push(hi>>>24&0xff,hi>>>16&0xff,hi>>>8&0xff,hi&0xff);
    bytes.push(lo>>>24&0xff,lo>>>16&0xff,lo>>>8&0xff,lo&0xff);
    var H=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19];
    var W=new Array(64);
    for(var o=0;o<bytes.length;o+=64){
      for(var i=0;i<16;i++){var j=o+i*4;W[i]=((bytes[j]<<24)|(bytes[j+1]<<16)|(bytes[j+2]<<8)|bytes[j+3])>>>0;}
      for(var i=16;i<64;i++)W[i]=(s1(W[i-2])+W[i-7]+s0(W[i-15])+W[i-16])>>>0;
      var a=H[0],b=H[1],c=H[2],d=H[3],e=H[4],f=H[5],g=H[6],h=H[7];
      for(var i=0;i<64;i++){
        var T1=(h+S1(e)+Ch(e,f,g)+K[i]+W[i])>>>0;
        var T2=(S0(a)+Maj(a,b,c))>>>0;
        h=g;g=f;f=e;e=(d+T1)>>>0;d=c;c=b;b=a;a=(T1+T2)>>>0;
      }
      H[0]=(H[0]+a)>>>0;H[1]=(H[1]+b)>>>0;H[2]=(H[2]+c)>>>0;H[3]=(H[3]+d)>>>0;
      H[4]=(H[4]+e)>>>0;H[5]=(H[5]+f)>>>0;H[6]=(H[6]+g)>>>0;H[7]=(H[7]+h)>>>0;
    }
    function hex(n){return(((n>>>24)&0xff).toString(16).padStart(2,'0'))+(((n>>>16)&0xff).toString(16).padStart(2,'0'))+(((n>>>8)&0xff).toString(16).padStart(2,'0'))+((n&0xff).toString(16).padStart(2,'0'));}
    return hex(H[0])+hex(H[1])+hex(H[2])+hex(H[3])+hex(H[4])+hex(H[5])+hex(H[6])+hex(H[7]);
  }
  return function(s){return hash(Array.from(unescape(encodeURIComponent(s))).map(function(c){return c.charCodeAt(0);}));};
})();

// 拦截 __pushEvent__，记录 sign 用于调试
var __origPushEvent__ = __pushEvent__;
__pushEvent__ = function(action, data) {
  if (action === 'request' && data && data.url) {
    var url = data.url;
    var signIdx = url.indexOf('sign=');
    if (signIdx > -1) {
      console.log('sign: ' + url.substring(signIdx + 5, signIdx + 69));
    }
  }
  __origPushEvent__(action, data);
};

// 暴露为全局 sha256 函数，供用户脚本使用
globalThis.sha256 = __lx_sha256__;

// === 纯 JS AES-128-CBC/ECB 实现 ===
var __lx_aesEncrypt__ = (function() {
  var SBOX=[0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16];
  var RCON=[0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36];
  function xtime(a){return((a<<1)^(((a>>7)&1)*0x1b))&0xFF;}
  function mul(a,b){var p=0;for(var i=0;i<8;i++){if(b&1)p^=a;a=xtime(a);b>>=1;}return p;}
  function keyExpansion(key){var nk=key.length/4,exp=[];for(var i=0;i<nk;i++)exp[i]=(key[4*i]|(key[4*i+1]<<8)|(key[4*i+2]<<16)|(key[4*i+3]<<24))>>>0;for(var j=nk;j<4*(nk+7);j++){var t=exp[j-1];if(j%nk===0)t=(SBOX[(t>>8)&0xFF]|(SBOX[(t>>16)&0xFF]<<8)|(SBOX[(t>>24)&0xFF]<<16)|(SBOX[t&0xFF]<<24))>>>0^(RCON[(j/nk)-1]||0);else if(nk>6&&j%nk===4)t=(SBOX[t&0xFF]|(SBOX[(t>>8)&0xFF]<<8)|(SBOX[(t>>16)&0xFF]<<16)|(SBOX[(t>>24)&0xFF]<<24))>>>0;exp[j]=exp[j-nk]^t;}return exp;}
  function subBytes(s){for(var i=0;i<4;i++)for(var j=0;j<4;j++)s[i][j]=SBOX[s[i][j]];}
  function shiftRows(s){var t;s[1]=[s[1][1],s[1][2],s[1][3],s[1][0]];s[2]=[s[2][2],s[2][3],s[2][0],s[2][1]];s[3]=[s[3][3],s[3][0],s[3][1],s[3][2]];}
  function mixColumns(s){for(var i=0;i<4;i++){var a=s[i],b=[];for(var j=0;j<4;j++)b[j]=mul(a[j],2)^mul(a[(j+1)%4],3)^a[(j+2)%4]^a[(j+3)%4];s[i]=b;}}
  function addRoundKey(s,k,r){for(var i=0;i<4;i++)for(var j=0;j<4;j++)s[i][j]^=(k[r*4+j]>>(i*8))&0xFF;}
  function encryptBlock(block,expanded){var s=[];for(var i=0;i<4;i++){s[i]=[];for(var j=0;j<4;j++)s[i][j]=block[i*4+j];}
  addRoundKey(s,expanded,0);for(var r=1;r<10;r++){subBytes(s);shiftRows(s);mixColumns(s);addRoundKey(s,expanded,r);}subBytes(s);shiftRows(s);addRoundKey(s,expanded,10);
  var out=[];for(var c=0;c<4;c++)for(var d=0;d<4;d++)out.push(s[d][c]);return out;}
  function padPKCS7(data){var pad=16-data.length%16,out=new Uint8Array(data.length+pad);out.set(data);for(var i=data.length;i<out.length;i++)out[i]=pad;return out;}
  return function(inputBytes,keyBytes,ivBytes,mode){
    var padded=padPKCS7(inputBytes);var expanded=keyExpansion(keyBytes);var out=new Uint8Array(padded.length);
    if(mode&&mode.indexOf('CBC')>=0){var prev=ivBytes||new Uint8Array(16);for(var i=0;i<padded.length;i+=16){var block=[];for(var j=0;j<16;j++)block.push(padded[i+j]^prev[j]);var enc=encryptBlock(block,expanded);out.set(enc,i);prev=enc;}}
    else{for(var i=0;i<padded.length;i+=16){var block2=[];for(var j2=0;j2<16;j2++)block2.push(padded[i+j2]);out.set(encryptBlock(block2,expanded),i);}}
    return out;
  };
})();

// === 在 lx_setup 之前暴露 lx 对象供用户脚本使用 ===
var __lx_handlers__ = {};
var __lx_inited__ = false;
var __lx_requestQueue__ = {};
var __lx_reqCounter__ = 0;

// 捕获 console.log 输出到事件队列（方便 Dart 侧查看）
var __origConsoleLog__ = console.log;
console.log = function() {
  var msg = Array.prototype.slice.call(arguments).map(function(a) {
    return typeof a === 'object' ? JSON.stringify(a) : String(a);
  }).join(' ');
  __origConsoleLog__(msg);
  __pushEvent__('__log__', {msg: msg});
};
console.error = console.log;

globalThis.lx = {
  EVENT_NAMES: { request: 'request', inited: 'inited', updateAlert: 'updateAlert' },
  on: function(eventName, handler) {
    if (eventName === 'request') __lx_handlers__.request = handler;
    return Promise.resolve();
  },
  send: function(eventName, data) {
    if (eventName === 'inited') {
      if (__lx_inited__) return Promise.reject(new Error('Script is inited'));
      __lx_inited__ = true;
      var sourceInfo = { sources: {} };
      try {
        var allSources = ['kw','kg','tx','wy','mg','local'];
        var supportQualitys = { kw:['128k','320k','flac','flac24bit'], kg:['128k','320k','flac','flac24bit'], tx:['128k','320k','flac','flac24bit'], wy:['128k','320k','flac','flac24bit'], mg:['128k','320k','flac','flac24bit'], local:[] };
        var supportActions = { kw:['musicUrl'], kg:['musicUrl'], tx:['musicUrl'], wy:['musicUrl'], mg:['musicUrl'], local:['musicUrl','lyric','pic'] };
        for (var i=0;i<allSources.length;i++) {
          var source=allSources[i], userSource=data&&data.sources?data.sources[source]:null;
          if (!userSource||userSource.type!=='music') continue;
          // 兼容两种格式：ikun.js 有 actions，Huibq 等只有 qualitys
          var userActions = userSource.actions || supportActions[source];
          var userQualitys = userSource.qualitys || supportQualitys[source];
          sourceInfo.sources[source] = { type:'music', actions:supportActions[source].filter(function(a){return userActions.indexOf(a)>=0;}), qualitys:supportQualitys[source].filter(function(q){return userQualitys.indexOf(q)>=0;}) };
        }
      } catch(e) { __pushEvent__('init', {info:null,status:false,errorMessage:e.message}); return Promise.resolve(); }
      __pushEvent__('init', {info:sourceInfo,status:true});
    }
    return Promise.resolve();
  },
  request: function(url, options, callback) {
    if (typeof options==='function'){callback=options;options={};} if(!options)options={};
    var id='http_'+(++__lx_reqCounter__);
    var requestInfo = { aborted: false, abort: function(){ this.aborted=true; } };
    __lx_requestQueue__[id] = { callback: callback, requestInfo: requestInfo };
    // 统一 options 格式（对齐原项目 request.js 的 handleRequestData）
    var method = (options.method || 'GET').toUpperCase();
    var headers = Object.assign({ 'Accept': 'application/json' }, options.headers || {});
    var body = options.body || null;
    if (options.form && !body) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      var formBody = [];
      var formKeys = Object.keys(options.form);
      for (var fi = 0; fi < formKeys.length; fi++) {
        formBody.push(encodeURIComponent(formKeys[fi]) + '=' + encodeURIComponent(options.form[formKeys[fi]]));
      }
      body = formBody.join('&');
    }
    if (options.formData && !body) {
      body = options.formData;
    }
    if (method === 'POST' && !headers['Content-Type'] && !options.formData) {
      headers['Content-Type'] = 'application/json';
    }
    if (headers['Content-Type'] === 'application/json' && body && typeof body !== 'string') {
      body = JSON.stringify(body);
    }
    __pushEvent__('request', { requestKey: id, url: url, options: {
      method: method, headers: headers, body: body, timeout: options.timeout || 13000
    }});
    return requestInfo;
  },
  utils: {
    crypto: {
      md5: function(str) { return __lx_md5__(str); },
      aesEncrypt: function(buffer, mode, key, iv) {
        var b = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
        var k = key instanceof Uint8Array ? key : new Uint8Array(key);
        var v = iv instanceof Uint8Array ? iv : (iv ? new Uint8Array(iv) : new Uint8Array(16));
        return __lx_aesEncrypt__(b, k, v, mode);
      },
      rsaEncrypt: function() { return new Uint8Array(0); },
      randomBytes: function(size) { var a=new Uint8Array(size); for(var i=0;i<size;i++)a[i]=Math.floor(Math.random()*256); return a; },
    },
    buffer: {
      from: function(input, encoding) {
        if (typeof input==='string') {
          if (encoding==='base64') { var bin=atob(input),a=new Uint8Array(bin.length); for(var i=0;i<bin.length;i++)a[i]=bin.charCodeAt(i); return a; }
          if (encoding==='hex') { var a2=new Uint8Array(input.length/2); for(var j=0;j<input.length;j+=2)a2[j/2]=parseInt(input.substr(j,2),16); return a2; }
          var a3=new Uint8Array(input.length); for(var k=0;k<input.length;k++)a3[k]=input.charCodeAt(k); return a3;
        }
        if (Array.isArray(input)) return new Uint8Array(input);
        if (input instanceof ArrayBuffer||input instanceof Uint8Array) return new Uint8Array(input);
        throw new Error('Unsupported input');
      },
      bufToString: function(buf, format) {
        var a=buf instanceof Uint8Array?buf:new Uint8Array(buf);
        if (format==='hex') return Array.from(a).map(function(b){return b.toString(16).padStart(2,'0');}).join('');
        if (format==='base64') { var bin=''; for(var i=0;i<a.length;i++)bin+=String.fromCharCode(a[i]); return btoa(bin); }
        var s=''; for(var j=0;j<a.length;j++)s+=String.fromCharCode(a[j]); return s;
      },
    },
  },
  currentScriptInfo: {},
  version: '2.0.0',
  env: 'mobile',
};

function __pushEvent__(action, data) {
  if (globalThis.__lx_event_queue__) globalThis.__lx_event_queue__.push({action:action, data:JSON.stringify(data)});
}

// 响应处理：对齐洛雪原版 handleNativeResponse
function handleNativeResponse(data) {
  var targetRequest = __lx_requestQueue__[data.requestKey];
  if (!targetRequest) return;
  delete __lx_requestQueue__[data.requestKey];
  targetRequest.requestInfo.aborted = true;
  if (data.error == null) {
    var resp = data.response;
    // body 可能已是对象（Dart 侧预解析），也可能是字符串
    if (typeof resp.body === 'string') {
      try { resp.body = JSON.parse(resp.body); } catch(e) {}
    }
    targetRequest.callback(null, resp);
  } else {
    targetRequest.callback(new Error(data.error), null);
  }
}

// 响应验证函数（对齐洛雪原版 handleRequest）
function __verifyLyric__(info) {
  if (typeof info !== 'object' || typeof info.lyric !== 'string') throw new Error('failed');
  if (info.lyric.length > 51200) throw new Error('failed');
  return {
    lyric: info.lyric,
    tlyric: (typeof info.tlyric === 'string' && info.tlyric.length < 5120) ? info.tlyric : null,
    rlyric: (typeof info.rlyric === 'string' && info.rlyric.length < 5120) ? info.rlyric : null,
    lxlyric: (typeof info.lxlyric === 'string' && info.lxlyric.length < 8192) ? info.lxlyric : null,
  };
}

function __verifyUrl__(url) {
  if (typeof url !== 'string' || url.length > 2048 || !/^https?:/.test(url)) throw new Error('failed');
  return url;
}

// lx_setup: 用户脚本加载后调用
globalThis.lx_setup = function(key, id, name, description, version, author, homepage, rawScript) {
  delete globalThis.lx_setup;
  globalThis.lx.currentScriptInfo = {name:name,description:description,version:version,author:author,homepage:homepage,rawScript:rawScript};

  // 自测 MD5
  try {
    var md5test = __lx_md5__('test');
    console.log('MD5 test: ' + md5test + ' (expect: 098f6bcd4621d373cade4e832627b4f6)');
    if (md5test !== '098f6bcd4621d373cade4e832627b4f6') {
      console.log('MD5 MISMATCH!');
    }
  } catch(e) { console.log('MD5 error: ' + e.message); }

  // setTimeout/clearTimeout 支持（对齐洛雪原版）
  var __timeoutCallbacks__ = {};
  var __timeoutId__ = 0;
  globalThis.setTimeout = function(callback, timeout) {
    if (typeof callback !== 'function') throw new Error('callback required a function');
    var id = __timeoutId__++;
    __timeoutCallbacks__[id] = callback;
    var ms = parseInt(timeout) || 0;
    // 使用 Dart 侧的定时器
    globalThis.__lx_event_queue__.push({action:'__setTimeout__', data:JSON.stringify({id:id, ms:ms})});
    return id;
  };
  globalThis.clearTimeout = function(id) { delete __timeoutCallbacks__[id]; };
  // Dart 调用此函数触发 setTimeout 回调
  globalThis.__lx_fireTimeout__ = function(id) {
    var cb = __timeoutCallbacks__[id];
    if (cb) { delete __timeoutCallbacks__[id]; cb(); }
  };

  Object.freeze(globalThis.lx);
  console.log('lx_setup done: ' + name);
};
''';
