# 洛雪音乐源系统详细设计文档

## 一、整体架构

洛雪音乐的源系统分为两部分：
1. **内置源** - 直接在 JS 中实现的各平台 API 调用
2. **用户 API 源** - 通过 QuickJS 引擎执行的外部 JavaScript 插件

本文档重点分析**用户 API 源系统**的实现。

---

## 二、核心文件结构

```
lx-music-mobile/
├── src/
│   ├── core/
│   │   ├── userApi.ts                    # 用户 API 核心业务逻辑
│   │   └── init/
│   │       └── userApi/
│   │           ├── index.ts              # 初始化和事件处理
│   │           └── request.js            # HTTP 请求封装
│   ├── store/
│   │   └── userApi/
│   │       ├── state.ts                  # 状态定义
│   │       ├── action.ts                 # 状态操作
│   │       ├── event.ts                  # 事件定义
│   │       └── hook.ts                   # React Hooks
│   ├── utils/
│   │   ├── nativeModules/
│   │   │   └── userApi.ts                # 原生模块桥接
│   │   └── data.ts                       # 数据存储（含 API 存储）
│   └── types/
│       └── user_api.d.ts                 # 类型定义
└── android/
    └── app/src/main/
        ├── assets/script/
        │   └── user-api-preload.js       # 预加载脚本（核心！）
        └── java/cn/toside/music/mobile/userApi/
            ├── QuickJS.java              # QuickJS 引擎封装
            ├── UserApiModule.java        # React Native 模块
            └── JsHandler.java            # JS 事件处理
```

---

## 三、数据类型定义

### 3.1 用户 API 信息 (UserApiInfo)

```typescript
interface UserApiInfo {
  id: string                    // 唯一标识，如 "user_api_123_1700000000000"
  name: string                  // 插件名称
  description: string           // 插件描述
  author: string                // 作者
  homepage: string              // 主页
  version: string               // 版本号
  allowShowUpdateAlert: boolean // 是否允许显示更新提示
  sources?: UserApiSources      // 注册的音源（初始化后填充）
}
```

### 3.2 音源信息 (UserApiSourceInfo)

```typescript
interface UserApiSourceInfo {
  name: string                          // 音源名称
  type: 'music'                         // 类型（目前只有 music）
  actions: ('musicUrl' | 'lyric' | 'pic')[]  // 支持的操作
  qualitys: Quality[]                   // 支持的音质
}

type UserApiSources = Record<Source, UserApiSourceInfo>
// Source: 'kw' | 'kg' | 'tx' | 'wy' | 'mg'
```

### 3.3 音质类型

```typescript
type Quality = '128k' | '320k' | 'flac' | 'flac24bit'
```

---

## 四、通信协议详解

### 4.1 整体流程

```
┌─────────────────────────────────────────────────────────────────┐
│                         Native 层 (Android)                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │ UserApiModule │───▶│   QuickJS    │───▶│ user-api-preload │  │
│  │  (RN Bridge)  │    │   (引擎)     │    │     .js          │  │
│  └──────────────┘    └──────────────┘    └──────────────────┘  │
│         │                    │                      │            │
│         │                    │                      ▼            │
│         │                    │             ┌──────────────────┐ │
│         │                    │             │   用户脚本       │ │
│         │                    │             │  (如 ikun.js)    │ │
│         │                    │             └──────────────────┘ │
│         │                    │                      │            │
└─────────┼────────────────────┼──────────────────────┼────────────┘
          │                    │                      │
          ▼                    ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                         JavaScript 层                            │
│                                                                  │
│  globalThis.lx_setup(key, id, name, ...)  ◀── 预加载脚本暴露   │
│         │                                                        │
│         ▼                                                        │
│  globalThis.lx = {                                               │
│    EVENT_NAMES,                                                  │
│    request(url, options, callback),   ◀── HTTP 请求             │
│    send(eventName, data),             ◀── 发送事件              │
│    on(eventName, handler),            ◀── 注册处理器            │
│    utils: { crypto, buffer },         ◀── 工具函数              │
│    currentScriptInfo,                                            │
│    version: '2.0.0',                                             │
│    env: 'mobile'                                                 │
│  }                                                               │
│         │                                                        │
│         ▼                                                        │
│  用户脚本调用:                                                    │
│  lx.send('inited', { sources: { kg: {...}, kw: {...} } })       │
│  lx.on('request', async (data) => { ... })                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 初始化流程

```
1. Native 层创建 QuickJS 实例
2. 注入原生函数桥接:
   - __lx_native_call__(key, action, data)
   - __lx_native_call__utils_str2b64(str)
   - __lx_native_call__utils_b642buf(b64)
   - __lx_native_call__utils_str2md5(str)
   - __lx_native_call__utils_aes_encrypt(data, key, iv, mode)
   - __lx_native_call__utils_rsa_encrypt(data, key, padding)
   - __lx_native_call__set_timeout(id, timeout)

3. 加载预加载脚本 (user-api-preload.js)
4. 预加载脚本创建 lx_setup 函数

5. Native 调用 lx_setup(key, id, name, desc, version, author, homepage, rawScript)
6. lx_setup 内部:
   - 保存原生函数引用
   - 创建 lx 全局对象
   - 冻结 lx 对象（防止篡改）
   - 禁用 eval 和 Function 构造器
   - 冻结所有对象属性

7. Native 加载用户脚本
8. 用户脚本执行，调用 lx.send('inited', { sources: {...} })
9. 预加载脚本的 handleInit 处理注册信息
10. 通过 __lx_native_call__(key, 'init', data) 通知 Native
11. Native 层触发 'init' 事件
12. 应用层接收事件，创建 API 处理器
```

### 4.3 请求流程

```
应用层需要获取音乐 URL:
  │
  ▼
apis('kg').getMusicUrl(songInfo, '320k')
  │
  ▼
sendUserApiRequest({ requestKey, data: { source, action, info } })
  │
  ▼
sendAction('request', { requestKey, url, options })  ◀── 发送到 Native
  │
  ▼
Native 层: UserApiModule.sendAction('request', JSON.stringify(data))
  │
  ▼
Native 层调用 JS: __lx_native__(key, 'request', data)
  │
  ▼
预加载脚本的 handleRequest({ requestKey, data })
  │
  ▼
events.request.call(globalThis.lx, { source, action, info })
  │  ◀── 这里调用用户注册的 handler
  ▼
用户脚本的 request handler:
  lx.request(url, { method, headers, body }, (err, resp, body) => {
    // 处理响应
    return url  // 返回播放链接
  })
  │
  ▼
lx.request 内部调用 sendNativeRequest(url, options, callback)
  │
  ▼
__lx_native_call__(key, 'request', { requestKey, url, options })
  │
  ▼
Native 层执行 HTTP 请求
  │
  ▼
Native 返回响应: __lx_native__(key, 'response', { requestKey, response })
  │
  ▼
handleNativeResponse 处理响应
  │
  ▼
callback(null, response) 调用用户脚本的回调
  │
  ▼
用户脚本返回 URL
  │
  ▼
nativeCall('response', { requestKey, status: true, result: { data: { url } } })
  │
  ▼
应用层接收响应，获取到播放链接
```

---

## 五、预加载脚本详解 (user-api-preload.js)

### 5.1 核心函数 lx_setup

```javascript
globalThis.lx_setup = (key, id, name, description, version, author, homepage, rawScript) => {
  // key: 通信密钥
  // id: 插件 ID
  // name: 插件名称
  // description: 描述
  // version: 版本
  // author: 作者
  // homepage: 主页
  // rawScript: 原始脚本内容

  delete globalThis.lx_setup  // 删除自身，防止重复调用
  const _nativeCall = globalThis.__lx_native_call__
  delete globalThis.__lx_native_call__

  // ... 创建 lx 对象
}
```

### 5.2 lx 对象结构

```javascript
globalThis.lx = {
  EVENT_NAMES: {
    request: 'request',
    inited: 'inited',
    updateAlert: 'updateAlert',
  },

  // HTTP 请求函数
  request(url, { method = 'get', timeout, headers, body, form, formData, binary }, callback) {
    // 返回 abort 函数
    return sendNativeRequest(url, { method, body, form, formData, headers, binary }, callback)
  },

  // 发送事件到 Native
  send(eventName, data) {
    return new Promise((resolve, reject) => {
      switch (eventName) {
        case 'inited':
          handleInit(data)  // 处理初始化
          resolve()
          break
        case 'updateAlert':
          handleShowUpdateAlert(data, resolve, reject)
          break
      }
    })
  },

  // 注册事件处理器
  on(eventName, handler) {
    switch (eventName) {
      case 'request':
        events.request = handler
        break
    }
    return Promise.resolve()
  },

  // 工具函数
  utils: {
    crypto: {
      aesEncrypt(buffer, mode, key, iv) { ... },
      rsaEncrypt(buffer, key) { ... },
      randomBytes(size) { ... },
      md5(str) { ... },
    },
    buffer: {
      from(input, encoding) { ... },
      bufToString(buf, format) { ... },
    },
  },

  // 当前脚本信息
  currentScriptInfo: { name, description, version, author, homepage, rawScript },

  version: '2.0.0',
  env: 'mobile',
}
```

### 5.3 支持的音源和音质

```javascript
const allSources = ['kw', 'kg', 'tx', 'wy', 'mg', 'local']

const supportQualitys = {
  kw: ['128k', '320k', 'flac', 'flac24bit'],
  kg: ['128k', '320k', 'flac', 'flac24bit'],
  tx: ['128k', '320k', 'flac', 'flac24bit'],
  wy: ['128k', '320k', 'flac', 'flac24bit'],
  mg: ['128k', '320k', 'flac', 'flac24bit'],
  local: [],
}

const supportActions = {
  kw: ['musicUrl'],
  kg: ['musicUrl'],
  tx: ['musicUrl'],
  wy: ['musicUrl'],
  mg: ['musicUrl'],
  xm: ['musicUrl'],
  local: ['musicUrl', 'lyric', 'pic'],
}
```

---

## 六、用户脚本编写规范

### 6.1 脚本头部（必须）

```javascript
/**
 * @name 示例音源
 * @description 这是一个示例音源插件
 * @version 1.0.0
 * @author YourName
 * @homepage https://github.com/yourname/plugin
 */

// 脚本内容...
```

### 6.2 注册音源

```javascript
// 方式1: 直接注册
lx.send('inited', {
  sources: {
    kg: {
      type: 'music',
      actions: ['musicUrl'],
      qualitys: ['128k', '320k', 'flac'],
    },
    kw: {
      type: 'music',
      actions: ['musicUrl', 'lyric', 'pic'],
      qualitys: ['128k', '320k', 'flac', 'flac24bit'],
    },
  },
})
```

### 6.3 注册请求处理器

```javascript
lx.on('request', async({ source, action, info }) => {
  // source: 'kg' | 'kw' | 'tx' | 'wy' | 'mg'
  // action: 'musicUrl' | 'lyric' | 'pic'
  // info: { type, musicInfo }

  switch (action) {
    case 'musicUrl':
      return await getMusicUrl(source, info)
    case 'lyric':
      return await getLyric(source, info)
    case 'pic':
      return await getPic(source, info)
  }
})
```

### 6.4 获取播放链接示例

```javascript
async function getMusicUrl(source, info) {
  const { type, musicInfo } = info
  // type: '128k' | '320k' | 'flac' | 'flac24bit'
  // musicInfo: { songmid, name, singer, ... }

  // 使用 lx.request 发起 HTTP 请求
  const resp = await new Promise((resolve, reject) => {
    lx.request(
      `https://api.example.com/url?source=${source}&songmid=${musicInfo.songmid}&quality=${type}`,
      { method: 'get' },
      (err, resp, body) => {
        if (err) reject(err)
        else resolve({ resp, body })
      }
    )
  })

  // 解析响应
  const data = JSON.parse(resp.body)
  if (data.code === 200) {
    return data.url  // 返回播放链接
  }
  throw new Error(data.msg || '获取失败')
}
```

### 6.5 加密工具使用

```javascript
// MD5
const hash = lx.utils.crypto.md5('hello')

// AES 加密
const encrypted = lx.utils.crypto.aesEncrypt(
  'plain text',
  'aes-128-cbc',
  'key1234567890123',
  'iv12345678901234'
)

// Buffer 操作
const buf = lx.utils.buffer.from('hello', 'utf8')
const base64 = lx.utils.buffer.bufToString(buf, 'base64')
const hex = lx.utils.buffer.bufToString(buf, 'hex')
```

---

## 七、Native 层实现要点

### 7.1 原生函数桥接

```java
// QuickJS.java

// 设置原生函数
jsContext.getGlobalObject().setProperty("__lx_native_call__", args -> {
  String key = (String) args[0];
  String action = (String) args[1];
  String data = (String) args[2];
  
  if (this.key.equals(key)) {
    callNative(action, data);  // 处理原生调用
  }
  return null;
});

// MD5 函数
jsContext.getGlobalObject().setProperty("__lx_native_call__utils_str2md5", args -> {
  String str = URLDecoder.decode((String) args[0], "UTF-8");
  MessageDigest md = MessageDigest.getInstance("MD5");
  byte[] md5Bytes = md.digest(str.getBytes(StandardCharsets.UTF_8));
  // 转换为十六进制字符串
  return md5String.toString();
});

// AES 加密
jsContext.getGlobalObject().setProperty("__lx_native_call__utils_aes_encrypt", args -> {
  return AES.encrypt(
    (String) args[0],  // data (base64)
    (String) args[1],  // key (base64)
    (String) args[2],  // iv (base64)
    (String) args[3]   // mode
  );
});
```

### 7.2 HTTP 请求处理

```java
// 在 init/userApi/index.ts 中

const sendScriptRequest = (requestKey, url, options) => {
  let req = fetchData(url, options)
  
  req.request.then(response => {
    sendAction('response', {
      error: null,
      requestKey,
      response: {
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        headers: response.headers,
        body: response.body,
      },
    })
  }).catch(err => {
    sendAction('response', {
      error: err.message,
      requestKey,
      response: null,
    })
  })
}
```

### 7.3 事件处理

```java
// 处理来自 JS 的事件
onScriptAction((event) => {
  switch (event.action) {
    case 'init':
      // 初始化完成，创建 API 处理器
      handleStateChange(event.data)
      break
    case 'response':
      // HTTP 响应
      handleUserApiResponse(event.data)
      break
    case 'request':
      // JS 请求 HTTP
      sendScriptRequest(event.data.requestKey, event.data.url, event.data.options)
      break
    case 'cancelRequest':
      // 取消请求
      cancelRequest(event.data, 'request canceled')
      break
    case 'showUpdateAlert':
      // 显示更新提示
      showUpdateAlert(event.data)
      break
  }
})
```

---

## 八、数据存储

### 8.1 存储结构

```
SharedPreferences / AsyncStorage:
  user_api_list: [
    {
      id: "user_api_123_1700000000000",
      name: "示例音源",
      description: "这是一个示例",
      author: "YourName",
      homepage: "https://github.com/...",
      version: "1.0.0",
      allowShowUpdateAlert: true
    },
    ...
  ]

  user_api_user_api_123_1700000000000: "/* 脚本内容 */..."
  user_api_user_api_456_1700000000000: "/* 脚本内容 */..."
```

### 8.2 元信息解析

```typescript
const INFO_NAMES = {
  name: 24,           // 名称最大长度
  description: 36,    // 描述最大长度
  author: 56,         // 作者最大长度
  homepage: 1024,     // 主页最大长度
  version: 36,        // 版本最大长度
}

const matchInfo = (scriptInfo: string) => {
  const infoArr = scriptInfo.split(/\r?\n/)
  const rxp = /^\s?\*\s?@(\w+)\s(.+)$/
  const infos = {}
  
  for (const info of infoArr) {
    const result = rxp.exec(info)
    if (!result) continue
    const key = result[1]
    if (INFO_NAMES[key] == null) continue
    infos[key] = result[2].trim()
  }
  
  // 截断超长字段
  for (const [key, len] of Object.entries(INFO_NAMES)) {
    if (infos[key]?.length > len) {
      infos[key] = infos[key].substring(0, len) + '...'
    }
  }
  
  return infos
}
```

---

## 九、安全机制

### 9.1 环境隔离

```javascript
// 禁用 eval
globalThis.eval = function() {
  throw new Error('eval is not available')
}

// 禁用 Function 构造器
const proxyFunctionConstructor = new Proxy(Function.prototype.constructor, {
  apply() { throw new Error('Dynamic code execution is not allowed.') },
  construct() { throw new Error('Dynamic code execution is not allowed.') },
})

Object.defineProperty(Function.prototype, 'constructor', {
  value: proxyFunctionConstructor,
  writable: false,
  configurable: false,
  enumerable: false,
})

globalThis.Function = proxyFunctionConstructor
```

### 9.2 对象冻结

```javascript
// 冻结 lx 对象
const freezeObject = (obj) => {
  if (typeof obj != 'object') return
  Object.freeze(obj)
  for (const subObj of Object.values(obj)) freezeObject(subObj)
}
freezeObject(globalThis.lx)

// 冻结所有对象属性
const freezeObjectProperty = (obj, freezedObj = new Set()) => {
  if (obj == null) return
  switch (typeof obj) {
    case 'object':
    case 'function':
      if (freezedObj.has(obj)) return
      freezedObj.add(obj)
      for (const [name, { ...config }] of Object.entries(Object.getOwnPropertyDescriptors(obj))) {
        if (config.writable) config.writable = false
        if (config.configurable) config.configurable = false
        Object.defineProperty(obj, name, config)
        freezeObjectProperty(config.value, freezedObj)
      }
  }
}
freezeObjectProperty(globalThis)
```

### 9.3 输入检查

```javascript
const checkLength = (str, length = 1048576) => {
  if (typeof str == 'string' && str.length > length) {
    throw new Error('Input too long')
  }
  return str
}

// 在调用原生函数前检查
nativeFuncs.utils_str2md5 = (...args) => {
  for (const arg of args) checkLength(arg)
  return nativeFunc(...args)
}
```

---

## 十、Flutter 适配要点

### 10.1 需要实现的组件

1. **QuickJS 引擎** - 使用 `flutter_js` 包
2. **预加载脚本** - 完整移植 `user-api-preload.js`
3. **原生函数桥接**:
   - HTTP 请求
   - MD5 哈希
   - AES 加密
   - RSA 加密
   - Base64 编解码
   - Buffer 操作
   - setTimeout

4. **事件系统** - JS ↔ Dart 通信
5. **状态管理** - 插件列表、启用状态
6. **数据存储** - 插件脚本和元信息

### 10.2 依赖包

```yaml
dependencies:
  flutter_js: ^0.8.1        # QuickJS 引擎
  crypto: ^3.0.3             # MD5 等哈希
  encrypt: ^5.0.1            # AES/RSA 加密
  shared_preferences: ^2.2.0 # 本地存储
  path_provider: ^2.1.0      # 文件路径
```

### 10.3 关键实现

```dart
// 1. 创建 JS 运行时
final runtime = getJavascriptRuntime();

// 2. 注入原生函数
runtime.onMessage('__lx_native_call__utils_str2md5', (data) {
  final bytes = utf8.encode(Uri.encodeComponent(data as String));
  final digest = md5.convert(bytes);
  return digest.toString();
});

// 3. 加载预加载脚本
await runtime.evaluateAsync(preloadScript);

// 4. 加载用户脚本
await runtime.evaluateAsync(userScript);

// 5. 调用 lx_setup
await runtime.evaluateAsync('''
  lx_setup('$key', '$id', '$name', '$desc', '$version', '$author', '$homepage', '');
''');

// 6. 等待初始化完成
// 通过事件监听等待 'init' 事件

// 7. 发起请求
final result = await runtime.evaluateAsync('''
  __lx_native__('$key', 'request', JSON.stringify({
    requestKey: '$requestKey',
    data: {
      source: 'kg',
      action: 'musicUrl',
      info: { type: '320k', musicInfo: { songmid: '123' } }
    }
  }));
''');
```

---

## 十一、完整示例：ikun.js 插件

```javascript
/**
 * @name 独家音源
 * @description ikun音乐 API 服务器
 * @version 4.0.0
 * @author ikun
 * @homepage https://github.com/lxmusics/lx-music-api-server
 */

// API 配置
const API_URL = 'https://api.example.com'
const API_KEY = 'your-api-key'

// 注册音源
lx.send('inited', {
  sources: {
    kg: {
      type: 'music',
      actions: ['musicUrl'],
      qualitys: ['128k', '320k', 'flac'],
    },
    kw: {
      type: 'music',
      actions: ['musicUrl'],
      qualitys: ['128k', '320k', 'flac'],
    },
  },
})

// 注册请求处理器
lx.on('request', async({ source, action, info }) => {
  if (action !== 'musicUrl') throw new Error('Unsupported action')
  
  const { type, musicInfo } = info
  const songId = musicInfo.songmid
  
  // 构建请求 URL
  const url = `${API_URL}/url?source=${source}&songId=${songId}&quality=${type}`
  
  // 发起请求
  const resp = await new Promise((resolve, reject) => {
    lx.request(url, {
      method: 'get',
      headers: {
        'X-Request-Key': API_KEY,
      },
    }, (err, resp, body) => {
      if (err) reject(err)
      else resolve({ resp, body })
    })
  })
  
  // 解析响应
  const data = typeof resp.body === 'string' ? JSON.parse(resp.body) : resp.body
  
  if (data.code === 200 && data.url) {
    return data.url
  }
  
  throw new Error(data.msg || '获取播放链接失败')
})
```

---

## 总结

洛雪音乐的源系统设计非常精巧：

1. **安全性**：通过环境隔离、代码冻结防止恶意脚本
2. **可扩展性**：支持多个音源，每个音源可支持多种操作
3. **标准化**：统一的 lx 对象接口，方便插件开发
4. **双向通信**：Native ↔ JS 完整的事件系统
5. **加密支持**：内置 MD5、AES、RSA 等加密工具
6. **HTTP 支持**：完整的 HTTP 请求功能

在 Flutter 中实现需要：
- QuickJS 引擎（flutter_js）
- 完整移植预加载脚本
- 实现所有原生函数桥接
- 事件通信系统
- 数据持久化
