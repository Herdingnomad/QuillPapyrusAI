# Flutter & llama_flutter_android keep rules
-keep class com.write4me.llama_flutter_android.** { *; }
-keep class kotlin.jvm.functions.Function1
-keepclassmembers class * implements kotlin.jvm.functions.Function1 { public java.lang.Object invoke(java.lang.Object); }
-keepclasseswithmembernames class * { native <methods>; }

# ML Kit Document Scanner & Google Play Services keep rules
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
-keep class com.google.mlkit.common.internal.** { *; }
-keep class com.google.mlkit.vision.common.internal.** { *; }
-keep class com.google.mlkit.vision.documentscanner.** { *; }
-keep class com.google.android.gms.internal.mlkit_document_scanner.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_document_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
