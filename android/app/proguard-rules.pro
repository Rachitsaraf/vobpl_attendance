# OTA Update & FileProvider
-dontwarn sk.samer.ota_update.**
-keep class sk.samer.ota_update.** { *; }
-keep class androidx.core.** { *; }

# Flutter Core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Play Core (Required by Flutter engine when minification is enabled)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep model classes, serialization, and annotations
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn sun.misc.**
