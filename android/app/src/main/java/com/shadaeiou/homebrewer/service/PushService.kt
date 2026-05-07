package com.shadaeiou.homebrewer.service

import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.shadaeiou.homebrewer.BuildConfig
import com.shadaeiou.homebrewer.MainActivity
import com.shadaeiou.homebrewer.R
import com.shadaeiou.homebrewer.HomebrewerApp
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class PushService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        if (data["type"] == "update") {
            val versionCode = data["versionCode"]?.toIntOrNull() ?: return
            val versionName = data["versionName"].orEmpty()
            // Race protection: the freshly-installed APK can receive the same
            // update push that triggered its install. Don't re-prompt.
            if (versionCode <= BuildConfig.VERSION_CODE) return
            showUpdateNotification(versionName, versionCode)
            return
        }

        message.notification?.let { notif ->
            val builder = NotificationCompat.Builder(this, HomebrewerApp.CHANNEL_UPDATES)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(notif.title.orEmpty())
                .setContentText(notif.body.orEmpty())
                .setAutoCancel(true)
            NotificationManagerCompat.from(this).notify(GENERIC_NOTIFICATION_ID, builder.build())
        }
    }

    override fun onNewToken(token: String) {
        // Topic subscription handles fan-out; no backend registration required.
        Log.i(TAG, "FCM token refreshed")
    }

    private fun showUpdateNotification(versionName: String, versionCode: Int) {
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_AUTO_UPDATE, true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, HomebrewerApp.CHANNEL_UPDATES)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("App update available")
            .setContentText("Tap to update to v$versionName (build $versionCode).")
            .setContentIntent(pendingIntent)
            .addAction(0, "Update now", pendingIntent)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(this).notify(UPDATE_NOTIFICATION_ID, notification)
    }

    companion object {
        private const val TAG = "PushService"
        private const val UPDATE_NOTIFICATION_ID = 9001
        private const val GENERIC_NOTIFICATION_ID = 9000
    }
}
