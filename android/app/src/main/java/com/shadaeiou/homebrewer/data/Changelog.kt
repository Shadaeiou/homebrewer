package com.shadaeiou.homebrewer.data

data class ReleaseNote(
    val version: String,
    val date: String,
    val bullets: List<String>,
)

val CHANGELOG: List<ReleaseNote> = listOf(
    ReleaseNote(
        version = "0.1.0",
        date = "2026-05-07",
        bullets = listOf(
            "Bootstrapped Homebrewer from android-template",
            "Signed release pipeline publishing APKs to GitHub Releases",
            "In-app updater pulling latest signed APK on demand",
            "FCM push notifies installed clients when a new build ships",
        ),
    ),
)
