package com.shadaeiou.homebrewer;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;

import androidx.core.app.NotificationCompat;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

/**
 * Receives FCM messages on the "app-updates" topic and surfaces them as a
 * heads-up notification. Tapping the notification opens the latest GitHub
 * release page so the user can grab the APK.
 *
 * Phase 2C will replace the browser hand-off with an in-app DownloadManager +
 * install intent flow once the rest of the build pipeline is verified stable.
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
        String body = "Tap to download the latest build.";
        String releaseUrl = DEFAULT_RELEASE_URL;

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
        }

        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(releaseUrl));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        PendingIntent pi = PendingIntent.getActivity(
            ctx,
            0,
            intent,
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
