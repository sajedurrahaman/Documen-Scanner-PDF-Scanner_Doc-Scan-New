# App-specific R8 rules for Doc Scan.
# Release shrinking/optimization is enabled in build.gradle. SDKs (Firebase,
# Play Services, ML Kit, Facebook, AndroidX, Gson and OkHttp) supply consumer
# rules that Gradle merges automatically. Do not keep their entire packages:
# doing so prevents DEX shrinking, optimization and obfuscation.

# Preserve metadata for reflection and readable retraced crash reports.
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

# Optional compile-time annotations, absent from the Android runtime.
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.**
-dontwarn javax.lang.model.**

# Flutter's optional deferred-component integration references Play Core.
# This app does not use deferred components.
-dontwarn com.google.android.play.core.**

# OCR uses TextRecognitionScript.latin only. The Flutter plugin also references
# these optional recognizers, whose language dependencies are not included.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder

# Preserve Java serialization hooks accessed reflectively.
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Flutter marks JNI entry points and its reflective plugin registrant @Keep;
# AndroidX consumer rules preserve these annotations. Native method names
# are also protected by proguard-android-optimize.txt.

# Notification models are persisted as JSON using Gson reflection. Preserve
# their fields, constructors and enum names so scheduled notifications saved
# by earlier app versions can still be read after an update. Keep only models,
# rather than the entire notification plugin or Gson implementation.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
