package com.shadaeiou.homebrewer;

import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.util.Log;

import androidx.core.content.FileProvider;

import java.io.File;

/**
 * Downloads a Homebrewer APK via DownloadManager and launches the system
 * install intent so the user can replace the running build without leaving
 * the app. Called from GDScript via JavaClassWrapper:
 *
 *     var Installer := JavaClassWrapper.wrap("com.shadaeiou.homebrewer.Installer")
 *     Installer.start(apk_url, version_name)
 *
 * Application context is captured by HomebrewerInit's onCreate (a manifest
 * ContentProvider runs before any Activity), so we don't need an Activity
 * reference at call time.
 */
public final class Installer {

    private static final String TAG = "Installer";
    private static final String AUTHORITY_SUFFIX = ".fileprovider";

    private static Context appCtx;
    private static long activeDownloadId = -1;
    private static BroadcastReceiver receiver;

    public static void init(Context ctx) {
        appCtx = ctx.getApplicationContext();
    }

    public static void start(String apkUrl, String versionName) {
        if (appCtx == null) {
            Log.w(TAG, "Installer not initialized");
            return;
        }
        if (apkUrl == null || apkUrl.isEmpty()) {
            Log.w(TAG, "empty apkUrl");
            return;
        }
        DownloadManager dm = (DownloadManager) appCtx.getSystemService(Context.DOWNLOAD_SERVICE);
        if (dm == null) {
            Log.w(TAG, "DownloadManager unavailable");
            return;
        }

        File outDir = new File(appCtx.getExternalFilesDir(null), "apks");
        if (!outDir.exists() && !outDir.mkdirs()) {
            Log.w(TAG, "could not create " + outDir);
            return;
        }
        File outFile = new File(outDir, "homebrewer-" + sanitize(versionName) + ".apk");
        if (outFile.exists()) {
            outFile.delete();
        }

        DownloadManager.Request req = new DownloadManager.Request(Uri.parse(apkUrl));
        req.setTitle("Homebrewer " + (versionName == null ? "" : versionName));
        req.setDescription("Downloading update...");
        req.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
        req.setDestinationUri(Uri.fromFile(outFile));
        req.setMimeType("application/vnd.android.package-archive");

        ensureReceiver();
        activeDownloadId = dm.enqueue(req);
        Log.i(TAG, "started download " + activeDownloadId + " -> " + outFile);
    }

    private static String sanitize(String s) {
        if (s == null) return "latest";
        return s.replaceAll("[^A-Za-z0-9._+-]", "_");
    }

    private static synchronized void ensureReceiver() {
        if (receiver != null) {
            return;
        }
        receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context ctx, Intent intent) {
                long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
                if (id != activeDownloadId) {
                    return;
                }
                DownloadManager dm = (DownloadManager) appCtx.getSystemService(Context.DOWNLOAD_SERVICE);
                if (dm == null) {
                    return;
                }
                DownloadManager.Query q = new DownloadManager.Query().setFilterById(id);
                Cursor c = dm.query(q);
                if (c == null) {
                    return;
                }
                try {
                    if (!c.moveToFirst()) {
                        return;
                    }
                    int statusIdx = c.getColumnIndex(DownloadManager.COLUMN_STATUS);
                    int uriIdx = c.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI);
                    int status = c.getInt(statusIdx);
                    String localUri = c.getString(uriIdx);
                    if (status != DownloadManager.STATUS_SUCCESSFUL) {
                        Log.w(TAG, "download failed: status=" + status);
                        return;
                    }
                    if (localUri == null) {
                        return;
                    }
                    File apk = new File(Uri.parse(localUri).getPath());
                    launchInstall(apk);
                } finally {
                    c.close();
                }
            }
        };
        IntentFilter filter = new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE);
        if (Build.VERSION.SDK_INT >= 33) {
            appCtx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            appCtx.registerReceiver(receiver, filter);
        }
    }

    private static void launchInstall(File apk) {
        try {
            Uri uri = FileProvider.getUriForFile(
                appCtx,
                appCtx.getPackageName() + AUTHORITY_SUFFIX,
                apk
            );
            Intent install = new Intent(Intent.ACTION_VIEW);
            install.setDataAndType(uri, "application/vnd.android.package-archive");
            install.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_GRANT_READ_URI_PERMISSION
            );
            appCtx.startActivity(install);
        } catch (Exception e) {
            Log.w(TAG, "could not launch install intent", e);
        }
    }
}
