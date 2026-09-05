package com.engagendy.noor

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// "Share as video" flow state. Lives ABOVE the AyahActionsSheet (which
/// dismisses itself before firing its action): download the current
/// reciter's recitation → compose the MP4 → system share sheet. One small
/// progress dialog reports the stage; errors are one short toast.
class AyahVideoShare(private val context: Context, private val scope: CoroutineScope) {

    enum class Stage { DOWNLOADING, COMPOSING }

    var stage by mutableStateOf<Stage?>(null)
        private set
    private var job: Job? = null

    fun start(verse: Verse, surah: Surah) {
        job?.cancel()
        stage = Stage.DOWNLOADING
        job = scope.launch {
            try {
                val audio = NoorPlayer.ensureAyahFile(surah.id, verse.ayah)
                if (audio == null) {
                    toast(if (isOnline()) R.string.feat_video_failed else R.string.feat_video_offline)
                    return@launch
                }
                stage = Stage.COMPOSING
                val card = withContext(Dispatchers.IO) {
                    ShareCard.render(
                        context,
                        "${verse.text} ⁧﴿${verse.ayah.arabicIndic()}﴾⁩",
                        context.getString(R.string.g2_surah_prefix, surah.nameArabic) +
                            " · ${surah.id.localizedDigits()}:${verse.ayah.localizedDigits()}",
                        useQuranFont = true)
                }
                val video = AyahVideoComposer.compose(context, card, audio)
                card.recycle()
                ShareCard.shareVideo(context, video)
            } catch (e: CancellationException) {
                throw e
            } catch (e: AyahVideoException) {
                Log.w("AyahVideoShare", "compose failed: ${e.kind}", e)
                toast(if (e.kind == AyahVideoException.Kind.AUDIO_UNREADABLE && !isOnline())
                    R.string.feat_video_offline else R.string.feat_video_failed)
            } catch (e: Exception) {
                Log.w("AyahVideoShare", "share failed", e)
                toast(R.string.feat_video_failed)
            } finally {
                stage = null
            }
        }
    }

    fun cancel() {
        job?.cancel()
        job = null
        stage = null
    }

    private fun toast(res: Int) {
        Toast.makeText(context, res, Toast.LENGTH_SHORT).show()
    }

    private fun isOnline(): Boolean {
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return false
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
}

@Composable
fun rememberAyahVideoShare(scope: CoroutineScope): AyahVideoShare {
    // The Activity context: the share chooser is started from it (an
    // application context would need NEW_TASK and lose the caller's task).
    val context = LocalContext.current
    return remember(scope, context) { AyahVideoShare(context, scope) }
}

/// Progress for the video share: spinner + stage line + cancel.
@Composable
fun AyahVideoProgressDialog(share: AyahVideoShare) {
    val stage = share.stage ?: return
    Dialog(
        onDismissRequest = { share.cancel() },
        properties = DialogProperties(dismissOnBackPress = true, dismissOnClickOutside = false),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(NoorColor.bgElevated)
                .padding(horizontal = 24.dp, vertical = 20.dp)
                .fillMaxWidth()
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(
                    color = NoorColor.accentPrimary,
                    strokeWidth = 3.dp,
                    modifier = Modifier.size(28.dp))
                Text(
                    stringResource(
                        when (stage) {
                            AyahVideoShare.Stage.DOWNLOADING -> R.string.feat_video_downloading
                            AyahVideoShare.Stage.COMPOSING -> R.string.feat_video_composing
                        }),
                    fontSize = 16.sp,
                    color = NoorColor.inkPrimary,
                    modifier = Modifier.padding(start = 16.dp))
            }
            TextButton(onClick = { share.cancel() }) {
                Text(stringResource(R.string.g2_cancel), color = NoorColor.accentPrimary, fontSize = 15.sp)
            }
        }
    }
}
