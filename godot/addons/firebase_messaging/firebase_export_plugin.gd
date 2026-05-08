@tool
extends EditorExportPlugin

# Note: parameter types intentionally untyped. Earlier versions used
# `EditorExportPreset` / `EditorExportPlatform` annotations and the script
# failed to compile during headless export ("Could not find type
# EditorExportPreset in the current scope"), which silently disabled the
# whole plugin and left the APK without Firebase deps or our manifest
# entries.

func _supports_platform(platform) -> bool:
	return platform.get_class() == "EditorExportPlatformAndroid"

func _get_name() -> String:
	return "Firebase Messaging"

func _get_android_dependencies(_p_preset, _p_debug) -> PackedStringArray:
	return PackedStringArray([
		"com.google.firebase:firebase-messaging:24.0.3",
	])

func _get_android_dependencies_maven_repos(_p_preset, _p_debug) -> PackedStringArray:
	# google() and mavenCentral() are already declared by Godot's stock template.
	return PackedStringArray()

func _get_android_manifest_application_element_contents(_p_preset, _p_debug) -> String:
	return """
<service
    android:name=\"com.shadaeiou.homebrewer.PushService\"
    android:exported=\"false\">
    <intent-filter>
        <action android:name=\"com.google.firebase.MESSAGING_EVENT\" />
    </intent-filter>
</service>

<provider
    android:name=\"com.shadaeiou.homebrewer.HomebrewerInit\"
    android:authorities=\"com.shadaeiou.homebrewer.init\"
    android:exported=\"false\"
    android:initOrder=\"100\" />

<provider
    android:name=\"androidx.core.content.FileProvider\"
    android:authorities=\"com.shadaeiou.homebrewer.fileprovider\"
    android:exported=\"false\"
    android:grantUriPermissions=\"true\">
    <meta-data
        android:name=\"android.support.FILE_PROVIDER_PATHS\"
        android:resource=\"@xml/file_paths\" />
</provider>
""".strip_edges()

func _get_android_manifest_element_contents(_p_preset, _p_debug) -> String:
	return """
<uses-permission android:name=\"android.permission.POST_NOTIFICATIONS\" />
<uses-permission android:name=\"android.permission.REQUEST_INSTALL_PACKAGES\" />
""".strip_edges()
