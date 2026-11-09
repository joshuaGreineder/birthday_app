# flutter_local_notifications stores scheduled reminders as JSON through Gson and reads
# them back after reboot or update. Keep Gson's generic type info and the plugin's model
# classes so R8 does not rename or strip what Gson reflects on.

# Gson (from google/gson examples/android-proguard-example)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod,InnerClasses
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# flutter_local_notifications models serialized by Gson
-keep class com.dexterous.** { *; }
