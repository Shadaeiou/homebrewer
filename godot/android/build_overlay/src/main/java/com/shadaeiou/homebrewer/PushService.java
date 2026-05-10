package com.shadaeiou.homebrewer;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import androidx.core.app.NotificationCompat;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

/**
 * Receives FCM messages on the "app-updates" topic and surfaces them as a
 * heads-up notification. Tapping fires InstallReceiver, which kicks off
 * DownloadManager + the install intent so the user updates without leaving
 * the app.
 */
public class PushService extends FirebaseMessagingService {

    private static final String CHANNEL_ID = "app-updates";
    private static final int NOTIFICATION_ID = 1;
    private static final String DEFAULT_RELEASE_URL =
        "https://github.com/Shadaeiou/homebrewer/releases/latest";

    @Override
    public void onMessageReceived(RemoteMessage message) {
        Context ctx = getApplicationContext();
        ensureChannel();

        String title = "Homebrewer update available";
        String body = "Tap to install the new build.";
        String releaseUrl = DEFAULT_RELEASE_URL;
        String apkUrl = null;
        String versionName = null;

        if (message.getNotification() != null) {
            if (message.getNotification().getTitle() != null) {
                title = message.getNotification().getTitle();
            }
            if (message.getNotification().getBody() != null) {
                body = message.getNotification().getBody();
            }
        }
        if (message.getData() != null) {
            String t = message.getData().get("title");
            String b = message.getData().get("body");
            String u = message.getData().get("release_url");
            if (t != null && !t.isEmpty()) title = t;
            if (b != null && !b.isEmpty()) body = b;
            if (u != null && !u.isEmpty()) releaseUrl = u;
            apkUrl = message.getData().get("apk_url");
            versionName = message.getData().get("version_name");
        }

        // Tap target: our InstallReceiver, which calls Installer.start to
        // run DownloadManager + the install intent. Falls back to opening
        // the release page in a browser if the message lacks an apk_url
        // (e.g. an older CI sender that didn't include it).
        Intent broadcast = new Intent(ctx, InstallReceiver.class);
        broadcast.setAction(InstallReceiver.ACTION);
        if (apkUrl != null) broadcast.putExtra(InstallReceiver.EXTRA_APK_URL, apkUrl);
        if (versionName != null) broadcast.putExtra(InstallReceiver.EXTRA_VERSION_NAME, versionName);
        broadcast.putExtra(InstallReceiver.EXTRA_RELEASE_URL, releaseUrl);
        PendingIntent pi = PendingIntent.getBroadcast(
            ctx,
            0,
            broadcast,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_HIGH);

        NotificationManager nm = (NotificationManager)
            ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) {
            nm.notify(NOTIFICATION_ID, builder.build());
        }
    }

    private void ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }
        NotificationManager nm = (NotificationManager)
            getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null || nm.getNotificationChannel(CHANNEL_ID) != null) {
            return;
        }
        NotificationChannel channel = new NotificationChannel(
            CHANNEL_ID,
            "App updates",
            NotificationManager.IMPORTANCE_HIGH
        );
        channel.setDescription("Notifies you when a new Homebrewer build is available.");
        nm.createNotificationChannel(channel);
    }
}
