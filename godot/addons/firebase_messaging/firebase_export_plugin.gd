@tool
extends EditorExportPlugin

# Firebase BOM keeps the messaging artifact's transitive dependency versions
# (firebase-iid, play-services-tasks, etc.) in sync with each other.
const FIREBASE_BOM := "com.google.firebase:firebase-bom:33.5.1"
const FIREBASE_MESSAGING := "com.google.firebase:firebase-messaging"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform.get_class() == "EditorExportPlatformAndroid"

func _get_name() -> String:
	return "Firebase Messaging"

func _get_android_dependencies(_p_preset: EditorExportPreset, _p_debug: bool) -> PackedStringArray:
	# The BOM line is `platform(...)` in gradle. Godot's wrapper passes the
	# raw coordinate; firebase-messaging without a version picks it up from
	# the BOM which we declare separately at the project level — but since
	# we can't add a `platform(...)` here, pin firebase-messaging directly.
	return PackedStringArray([
		"com.google.firebase:firebase-messaging:24.0.3",
	])

func _get_android_dependencies_maven_repos(_p_preset: EditorExportPreset, _p_debug: bool) -> PackedStringArray:
	# google() and mavenCentral() are already declared by Godot's stock template.
	return PackedStringArray()

func _get_android_manifest_application_element_contents(_p_preset: EditorExportPreset, _p_debug: bool) -> String:
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
""".strip_edges()

func _get_android_manifest_element_contents(_p_preset: EditorExportPreset, _p_debug: bool) -> String:
	return """<uses-permission android:name=\"android.permission.POST_NOTIFICATIONS\" />""".strip_edges()
