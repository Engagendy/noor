package com.engagendy.noor

import android.content.Context
import android.graphics.Bitmap
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
import java.io.File

/// "Share as video" flow state, shared by the Quran reader and the athkar
/// list. Lives ABOVE the sheet that triggers it (AyahActionsSheet and
/// DhikrShareSheet both dismiss themselves BEFORE firing their action):
/// fetch the recitation (cache → download) → compose the MP4 → system share
/// sheet. One small progress dialog reports the stage; errors are one short
/// toast. The composer itself is content-agnostic (card bitmap + audio
/// file), exactly like iOS Core/ShareVideo — only the resolvers below know
/// what an ayah or a dhikr is.
class ShareVideoShare(private val context: Context, private val scope: CoroutineScope) {

    enum class Stage { DOWNLOADING, COMPOSING }

    var stage by mutableStateOf<Stage?>(null)
        private set
    private var job: Job? = null

    /// The current reciter's recitation of one ayah, on the ayah share card.
    fun start(verse: Verse, surah: Surah) {
        start(
            offlineRes = R.string.feat_video_offline,
            audio = { NoorPlayer.ensureAyahFile(surah.id, verse.ayah) },
            card = {
                ShareCard.render(
                    context,
                    "${verse.text} ⁧﴿${verse.ayah.arabicIndic()}﴾⁩",
                    context.getString(R.string.g2_surah_prefix, surah.nameArabic) +
                        " · ${surah.id.localizedDigits()}:${verse.ayah.localizedDigits()}",
                    useQuranFont = true)
            })
    }

    /// One dhikr with its own Hisn al-Muslim recording (Hamad Al-Duraihim).
    /// Per-item audio only — the chapter recordings run to 6+ minutes and are
    /// deliberately not shareable (mirrors the iOS DhikrVideoComposer). The
    /// whole recording is used, never a trimmed clip.
    fun start(dhikr: Dhikr, chapterTitle: String) {
        val file = dhikr.audio ?: return
        start(
            offlineRes = R.string.feat_video_offline_dhikr,
            audio = { AthkarAudio.ensureLocal(context, file) },
            card = {
                ShareCard.render(
                    context, dhikr.text, chapterTitle,
                    attribution = "نور Noor · حصن المسلم")
            })
    }

    /// The shared flow: [audio] resolves the local MP3 (downloading if it is
    /// not cached — the spinner covers that), [card] draws the still. Both run
    /// off-main; [card] is only called once the audio is in hand.
    private fun start(offlineRes: Int, audio: suspend () -> File?, card: () -> Bitmap) {
        job?.cancel()
        stage = Stage.DOWNLOADING
        job = scope.launch {
            try {
                val file = audio()
                if (file == null) {
                    toast(if (isOnline()) R.string.feat_video_failed else offlineRes)
                    return@launch
                }
                stage = Stage.COMPOSING
                val bitmap = withContext(Dispatchers.IO) { card() }
                val video = ShareVideoComposer.compose(context, bitmap, file)
                bitmap.recycle()
                ShareCard.shareVideo(context, video)
            } catch (e: CancellationException) {
                throw e
            } catch (e: ShareVideoException) {
                Log.w("ShareVideoShare", "compose failed: ${e.kind}", e)
                toast(if (e.kind == ShareVideoException.Kind.AUDIO_UNREADABLE && !isOnline())
                    offlineRes else R.string.feat_video_failed)
            } catch (e: Exception) {
                Log.w("ShareVideoShare", "share failed", e)
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
fun rememberShareVideoShare(scope: CoroutineScope): ShareVideoShare {
    // The Activity context: the share chooser is started from it (an
    // application context would need NEW_TASK and lose the caller's task).
    val context = LocalContext.current
    return remember(scope, context) { ShareVideoShare(context, scope) }
}

/// Progress for the video share: spinner + stage line + cancel.
@Composable
fun ShareVideoProgressDialog(share: ShareVideoShare) {
    val stage = share.stage ?: return
    Dialog(
        onDismissRequest = { share.cancel() },
        properties = DialogProperties(dismissOnBackPress = true, dismissOnClickOutside = false),
    ) {
      // Own window → no app language (see AyahActionsSheet).
      NoorLocaleProvider {
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
                            ShareVideoShare.Stage.DOWNLOADING -> R.string.feat_video_downloading
                            ShareVideoShare.Stage.COMPOSING -> R.string.feat_video_composing
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
}
