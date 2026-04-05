# Flutter ProGuard Rules

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core（Flutter deferred components，我们不用但引擎引用了）
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# cached_network_image / flutter_cache_manager
-keep class com.baseflow.flutter_cached_network_image.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.**

# sqflite (flutter_cache_manager 依赖)
-keep class com.tekartik.sqflite.** { *; }

# path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# just_audio
-keep class com.ryanheise.just_audio.** { *; }

# OkHttp / HTTP
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Gson (可能被其他依赖使用)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
