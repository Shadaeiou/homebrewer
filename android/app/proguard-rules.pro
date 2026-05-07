# Compose, Kotlin metadata, and Firebase rules are bundled by their respective
# AARs. Add project-specific keep rules here as the app grows.

# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}
