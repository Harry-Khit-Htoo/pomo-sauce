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

# Collapse every obfuscated class into the root package instead of leaving
# them spread across ~156 single-letter packages. Shortens the string pool in
# the dex and makes the class graph harder to read. Classes pinned by the
# -keep rules above are unaffected: a kept name keeps its package too, so the
# flutter_local_notifications / flutter_foreground_task / Gson anchors above
# still resolve at runtime.
#
# -allowaccessmodification is what makes it actually bite: without it R8 will
# not move a package-private class out of the package its siblings rely on,
# so most classes stay put. Safe here because R8 sees the whole app.
-repackageclasses ''
-allowaccessmodification
