# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Razorpay ProGuard rules
-keep class com.razorpay.** {*;}
-keep class com.olacabs.** {*;}
-keep class com.ola.** {*;}
-dontwarn com.razorpay.**
-dontwarn com.olacabs.**
-dontwarn com.ola.**

# Keep all annotations
-keepattributes *Annotation*

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Maps rules
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }

# Retrofit/OkHttp (if used)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all public classes with main methods
-keepclasseswithmembers public class * {
    public static void main(java.lang.String[]);
}

# Keep all Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**