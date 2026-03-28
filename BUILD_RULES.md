# 构建规则
- Gradle JVM 堆内存上限: **2GB** (服务器只有 3.8GB 内存)
- MaxMetaspaceSize: 512m
- ReservedCodeCacheSize: 256m
- 关闭并行构建 (org.gradle.parallel=false)
- 使用国内镜像 (pub.flutter-io.cn)
