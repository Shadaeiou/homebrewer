package com.shadaeiou.homebrewer.data

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import androidx.core.content.getSystemService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request

class Updater(
    private val context: Context,
    private val owner: String = "Shadaeiou",
    private val repo: String = "homebrewer",
) {

    private val http: OkHttpClient by lazy { OkHttpClient() }
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun checkForUpdate(currentVersionCode: Int): UpdateInfo? = withContext(Dispatchers.IO) {
        runCatching {
            val request = Request.Builder()
                .url("https://api.github.com/repos/$owner/$repo/releases?per_page=10")
                .header("Accept", "application/vnd.github+json")
                .build()
            http.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext null
                val body = response.body?.string() ?: return@withContext null
                val releases = json.decodeFromString<List<GithubRelease>>(body)
                releases
                    .mapNotNull { it.toUpdateInfo() }
                    .filter { it.versionCode > currentVersionCode }
                    .maxByOrNull { it.versionCode }
            }
        }.getOrNull()
    }

    fun startDownload(info: UpdateInfo): Long {
        val dm = context.getSystemService<DownloadManager>()!!
        val request = DownloadManager.Request(Uri.parse(info.downloadUrl))
            .setTitle("App update ${info.versionName}")
            .setDescription("Downloading update...")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(
                context,
                Environment.DIRECTORY_DOWNLOADS,
                "app-${info.versionCode}.apk",
            )
        return dm.enqueue(request)
    }

    suspend fun awaitDownload(downloadId: Long): DownloadResult = withContext(Dispatchers.IO) {
        val dm = context.getSystemService<DownloadManager>()!!
        val query = DownloadManager.Query().setFilterById(downloadId)
        while (true) {
            dm.query(query).use { cursor ->
                if (cursor == null || !cursor.moveToFirst()) {
                    return@withContext DownloadResult.Failure("download row missing")
                }
                val statusCol = cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
                when (cursor.getInt(statusCol)) {
                    DownloadManager.STATUS_SUCCESSFUL -> return@withContext DownloadResult.Success
                    DownloadManager.STATUS_FAILED -> {
                        val reasonCol = cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)
                        return@withContext DownloadResult.Failure("reason ${cursor.getInt(reasonCol)}")
                    }
                }
            }
            delay(500)
        }
        @Suppress("UNREACHABLE_CODE")
        DownloadResult.Failure("unreachable")
    }

    fun launchInstall(downloadId: Long) {
        val dm = context.getSystemService<DownloadManager>()!!
        val uri = dm.getUriForDownloadedFile(downloadId) ?: return
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
    }

    @Serializable
    private data class GithubRelease(
        @SerialName("tag_name") val tagName: String,
        val name: String? = null,
        val body: String? = null,
        val assets: List<Asset> = emptyList(),
    )

    @Serializable
    private data class Asset(
        val name: String,
        @SerialName("browser_download_url") val browserDownloadUrl: String,
    )

    private fun GithubRelease.toUpdateInfo(): UpdateInfo? {
        val (versionName, versionCode) = parseTag(tagName) ?: return null
        val apk = assets.firstOrNull { it.name.endsWith(".apk", ignoreCase = true) } ?: return null
        return UpdateInfo(
            versionCode = versionCode,
            versionName = versionName,
            downloadUrl = apk.browserDownloadUrl,
            notes = body?.takeIf { it.isNotBlank() },
        )
    }

    private fun parseTag(tag: String): Pair<String, Int>? {
        val stripped = tag.removePrefix("v")
        val plus = stripped.lastIndexOf('+')
        if (plus <= 0 || plus == stripped.length - 1) return null
        val name = stripped.substring(0, plus)
        val code = stripped.substring(plus + 1).toIntOrNull() ?: return null
        return name to code
    }
}

data class UpdateInfo(
    val versionCode: Int,
    val versionName: String,
    val downloadUrl: String,
    val notes: String?,
)

sealed class DownloadResult {
    data object Success : DownloadResult()
    data class Failure(val reason: String) : DownloadResult()
}
