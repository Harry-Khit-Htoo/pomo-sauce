# flutter_local_notifications keeps its scheduled-notification payloads as
# Gson-serialised models; R8 must not strip or rename them or a pending alert
# fails to deserialise after the app is killed.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.dexterous.flutterlocalnotifications.**

# The foreground service and its receivers are referenced only from the
# manifest, so give R8 explicit anchors.
-keep class com.pravera.flutter_foreground_task.** { *; }

# Gson type tokens used by the notification payloads.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
