package com.shadaeiou.homebrewer.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.shadaeiou.homebrewer.BuildConfig
import com.shadaeiou.homebrewer.data.CHANGELOG
import com.shadaeiou.homebrewer.data.DownloadResult
import com.shadaeiou.homebrewer.data.ReleaseNote
import com.shadaeiou.homebrewer.data.UpdateInfo
import com.shadaeiou.homebrewer.data.Updater
import kotlinx.coroutines.launch

sealed class UpdateUiState {
    data object Idle : UpdateUiState()
    data object Checking : UpdateUiState()
    data class Available(val info: UpdateInfo) : UpdateUiState()
    data object Downloading : UpdateUiState()
    data object UpToDate : UpdateUiState()
    data class Error(val message: String) : UpdateUiState()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val updater = remember { Updater(context.applicationContext) }
    var state by remember { mutableStateOf<UpdateUiState>(UpdateUiState.Idle) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            Text("Updates", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))

            val canCheck = state is UpdateUiState.Idle ||
                state is UpdateUiState.UpToDate ||
                state is UpdateUiState.Error
            Button(
                onClick = {
                    if (!canCheck) return@Button
                    state = UpdateUiState.Checking
                    scope.launch {
                        val info = runCatching {
                            updater.checkForUpdate(BuildConfig.VERSION_CODE)
                        }.getOrElse {
                            state = UpdateUiState.Error(it.message ?: "Update check failed")
                            return@launch
                        }
                        state = if (info != null) UpdateUiState.Available(info)
                        else UpdateUiState.UpToDate
                    }
                },
                enabled = canCheck,
                modifier = Modifier.fillMaxWidth(),
            ) {
                val label = when (state) {
                    is UpdateUiState.Checking -> "Checking..."
                    is UpdateUiState.Downloading -> "Downloading..."
                    else -> "Check for updates"
                }
                Text(label)
            }

            when (val s = state) {
                is UpdateUiState.UpToDate -> {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = "You're on the latest build (${BuildConfig.VERSION_NAME}).",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                is UpdateUiState.Error -> {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = s.message,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
                else -> Unit
            }

            (state as? UpdateUiState.Available)?.let { available ->
                AlertDialog(
                    onDismissRequest = { state = UpdateUiState.Idle },
                    title = { Text("Update available") },
                    text = {
                        Column {
                            Text("Version ${available.info.versionName} is ready to install.")
                            available.info.notes?.takeIf { it.isNotBlank() }?.let { notes ->
                                Spacer(Modifier.height(8.dp))
                                Text(
                                    text = notes,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    },
                    confirmButton = {
                        TextButton(onClick = {
                            state = UpdateUiState.Downloading
                            scope.launch {
                                val downloadId = updater.startDownload(available.info)
                                when (val result = updater.awaitDownload(downloadId)) {
                                    DownloadResult.Success -> {
                                        updater.launchInstall(downloadId)
                                        state = UpdateUiState.Idle
                                    }
                                    is DownloadResult.Failure -> {
                                        state = UpdateUiState.Error("Update failed: ${result.reason}")
                                    }
                                }
                            }
                        }) { Text("Update") }
                    },
                    dismissButton = {
                        TextButton(onClick = { state = UpdateUiState.Idle }) { Text("Later") }
                    },
                )
            }

            Spacer(Modifier.height(16.dp))
            HorizontalDivider()
            Spacer(Modifier.height(16.dp))

            Text(
                text = "Version ${BuildConfig.VERSION_NAME} (build ${BuildConfig.VERSION_CODE})",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            ChangelogSection()
        }
    }
}

@Composable
private fun ChangelogSection() {
    if (CHANGELOG.isEmpty()) return
    Column {
        Text("What's new", style = MaterialTheme.typography.titleSmall)
        Spacer(Modifier.height(8.dp))
        ReleaseNoteEntry(CHANGELOG.first())

        if (CHANGELOG.size > 1) {
            var expanded by rememberSaveable { mutableStateOf(false) }
            TextButton(onClick = { expanded = !expanded }) {
                Text(if (expanded) "Hide older updates" else "Show all updates")
            }
            if (expanded) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    CHANGELOG.drop(1).forEach { ReleaseNoteEntry(it) }
                }
            }
        }
    }
}

@Composable
private fun ReleaseNoteEntry(entry: ReleaseNote) {
    Column {
        Text(
            text = "${entry.version} . ${entry.date}",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(Modifier.height(4.dp))
        entry.bullets.forEach { line ->
            Text(
                text = "• $line",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
