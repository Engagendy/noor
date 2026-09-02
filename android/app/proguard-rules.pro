# Noor release keep rules.

# Adhan prayer-time library uses reflection-free plain Java, but keep the
# public API surface to be safe across minification updates.
-keep class com.batoulapps.adhan.** { *; }
-dontwarn com.batoulapps.adhan.**

# org.json is part of the Android platform, but keep rules guard against
# library-shaded usages in content parsers (athkar/hadith JSON).
-keep class org.json.** { *; }
-dontwarn org.json.**

# Keep app entry points referenced from the manifest.
-keep class com.engagendy.noor.MainActivity { *; }
-keep class com.engagendy.noor.NoorAudioService { *; }
-keep class com.engagendy.noor.AdhanAlarmReceiver { *; }
-keep class com.engagendy.noor.BootReceiver { *; }
