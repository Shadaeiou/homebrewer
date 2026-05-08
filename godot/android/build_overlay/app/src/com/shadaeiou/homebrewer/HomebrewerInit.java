package com.shadaeiou.homebrewer;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.util.Log;

import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;

/**
 * Bootstraps Firebase + subscribes to the "app-updates" topic on app start.
 *
 * Manifest-declared ContentProviders run before any Activity/Application code.
 * We use one here so we don't have to override the gradle template's
 * Application class (which Godot owns) just to call FirebaseApp.initializeApp.
 *
 * Values are baked from google-services.json (Firebase project homebrewer-6a67c).
 * They aren't secret — they're embedded in any client built against this Firebase
 * project — so hardcoding here avoids needing the google-services gradle plugin.
 */
public class HomebrewerInit extends ContentProvider {

    private static final String TAG = "HomebrewerInit";
    private static final String FCM_TOPIC = "app-updates";

    @Override
    public boolean onCreate() {
        Context ctx = getContext();
        if (ctx == null) {
            return false;
        }
        FirebaseOptions options = new FirebaseOptions.Builder()
            .setApplicationId("1:59818402120:android:50794c9950a6fcc33f937d")
            .setApiKey("AIzaSyADEm6rjTFs7-Un2h534SOmpEegnrlIbQ8")
            .setProjectId("homebrewer-6a67c")
            .setStorageBucket("homebrewer-6a67c.firebasestorage.app")
            .setGcmSenderId("59818402120")
            .build();
        try {
            FirebaseApp.initializeApp(ctx.getApplicationContext(), options);
        } catch (IllegalStateException ignored) {
            // Default app already initialized — fine.
        }
        FirebaseMessaging.getInstance()
            .subscribeToTopic(FCM_TOPIC)
            .addOnCompleteListener(task -> {
                if (task.isSuccessful()) {
                    Log.i(TAG, "Subscribed to FCM topic: " + FCM_TOPIC);
                } else {
                    Log.w(TAG, "FCM subscription failed", task.getException());
                }
            });
        return true;
    }

    @Override public Cursor query(Uri u, String[] p, String s, String[] a, String o) { return null; }
    @Override public String getType(Uri u) { return null; }
    @Override public Uri insert(Uri u, ContentValues v) { return null; }
    @Override public int delete(Uri u, String s, String[] a) { return 0; }
    @Override public int update(Uri u, ContentValues v, String s, String[] a) { return 0; }
}
