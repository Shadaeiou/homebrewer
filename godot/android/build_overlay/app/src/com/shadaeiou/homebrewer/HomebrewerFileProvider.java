package com.shadaeiou.homebrewer;

import androidx.core.content.FileProvider;

/**
 * Empty subclass of androidx.core.content.FileProvider so we can register a
 * second FileProvider next to the one Godot's library AAR already declares.
 *
 * Without this, the manifest merger treats two providers with the same
 * android:name as a single entity and complains about conflicting
 * android.support.FILE_PROVIDER_PATHS meta-data values.
 */
public class HomebrewerFileProvider extends FileProvider {
}
