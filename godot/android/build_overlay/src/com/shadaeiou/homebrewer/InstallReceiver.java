package com.shadaeiou.homebrewer;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

/**
 * Triggered when the user taps the FCM "update available" notification.
 * Hands the apk URL to the Installer so the download + install dialog
 * happens in-app, instead of the notification opening a browser.
 *
 * If the broadcast lacks an apk_url (e.g. an older CI run that didn't
 * include it), falls back to launching the release page in a browser
 * so the user can still grab the APK manually.
 */
public class InstallReceiver extends BroadcastReceiver {

    public static final String ACTION = "com.shadaeiou.homebrewer.INSTALL_FROM_NOTIFICATION";
    public static final String EXTRA_APK_URL = "apk_url";
    public static final String EXTRA_VERSION_NAME = "version_name";
    public static final String EXTRA_RELEASE_URL = "release_url";

    @Override
    public void onReceive(Context context, Intent intent) {
        String apkUrl = intent.getStringExtra(EXTRA_APK_URL);
        String versionName = intent.getStringExtra(EXTRA_VERSION_NAME);
        String releaseUrl = intent.getStringExtra(EXTRA_RELEASE_URL);

        // The ContentProvider that normally calls Installer.init runs at
        // process start; if our process was just spun up to handle this
        // broadcast it has already run. But we re-init defensively so a
        // direct broadcast from a tool also works.
        Installer.init(context.getApplicationContext());

        if (apkUrl != null && !apkUrl.isEmpty()) {
            Installer.start(apkUrl, versionName != null ? versionName : "latest");
            return;
        }

        if (releaseUrl != null && !releaseUrl.isEmpty()) {
            Intent view = new Intent(Intent.ACTION_VIEW, Uri.parse(releaseUrl));
            view.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(view);
        }
    }
}
