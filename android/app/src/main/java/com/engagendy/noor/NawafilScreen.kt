package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// Reference guide to the voluntary prayers (النوافل) — a 1:1 port of the
/// iOS NawafilView (Modules/PrayerTimes/.../NawafilView.swift): what, how
/// many rak'ahs, when, and the evidence — purely informational.
data class NawafilItem(
    val icon: Int,
    val nameArabic: String,
    val nameEnglish: String,
    val rakahsArabic: String,
    val rakahsEnglish: String,
    val timeArabic: String,
    val timeEnglish: String,
    val noteArabic: String,
    val noteEnglish: String,
) {
    val name: String get() = if (isArabicLocale()) nameArabic else nameEnglish
    val rakahs: String get() = if (isArabicLocale()) rakahsArabic else rakahsEnglish
    val time: String get() = if (isArabicLocale()) timeArabic else timeEnglish
    val note: String get() = if (isArabicLocale()) noteArabic else noteEnglish
}

object Nawafil {
    val all = listOf(
        NawafilItem(R.drawable.ic_sun,
            nameArabic = "السنن الرواتب", nameEnglish = "Sunan ar-Rawatib",
            rakahsArabic = "١٢ ركعة", rakahsEnglish = "12 rak'ahs",
            timeArabic = "٢ قبل الفجر · ٤ قبل الظهر و٢ بعدها · ٢ بعد المغرب · ٢ بعد العشاء",
            timeEnglish = "2 before Fajr · 4 before and 2 after Dhuhr · 2 after Maghrib · 2 after Isha",
            noteArabic = "«من صلى اثنتي عشرة ركعة في يوم وليلة بُني له بهن بيت في الجنة» — رواه مسلم. وأوكدها ركعتا الفجر.",
            noteEnglish = "“Whoever prays twelve rak'ahs in a day and night, a house is built for him in Paradise” (Muslim). The two before Fajr are the most emphasized."),
        NawafilItem(R.drawable.ic_sun,
            nameArabic = "صلاة الضحى", nameEnglish = "Duha",
            rakahsArabic = "٢ إلى ٨ ركعات", rakahsEnglish = "2 to 8 rak'ahs",
            timeArabic = "من ارتفاع الشمس (بعد الشروق بربع ساعة تقريبًا) إلى قبيل الظهر",
            timeEnglish = "From when the sun has risen (about 15 minutes after sunrise) until shortly before Dhuhr",
            noteArabic = "أوصى بها النبي ﷺ أبا هريرة، وقال: «يصبح على كل سُلامى من أحدكم صدقة… ويجزئ من ذلك ركعتان يركعهما من الضحى» — رواه مسلم. وأفضل وقتها اشتداد الحر.",
            noteEnglish = "The Prophet ﷺ counseled Abu Hurayrah to keep it, saying two rak'ahs of Duha suffice as charity for every joint of the body (Muslim). Its best time is when the heat intensifies."),
        NawafilItem(R.drawable.ic_moon,
            nameArabic = "قيام الليل (التهجد)", nameEnglish = "Qiyam al-Layl (Tahajjud)",
            rakahsArabic = "مثنى مثنى، بلا حد", rakahsEnglish = "Two by two, no fixed limit",
            timeArabic = "بعد العشاء إلى الفجر، وأفضله الثلث الأخير من الليل",
            timeEnglish = "After Isha until Fajr — best in the last third of the night",
            noteArabic = "«أفضل الصلاة بعد الفريضة صلاة الليل» — رواه مسلم. وينزل ربنا في الثلث الأخير فيجيب الداعي ويعطي السائل ويغفر للمستغفر.",
            noteEnglish = "“The best prayer after the obligatory is the night prayer” (Muslim). In the last third of the night our Lord answers the supplicant, gives the asker, and forgives the one seeking forgiveness."),
        NawafilItem(R.drawable.ic_sparkle,
            nameArabic = "الوتر", nameEnglish = "Witr",
            rakahsArabic = "١ إلى ١١ ركعة (أقله واحدة)", rakahsEnglish = "1 to 11 rak'ahs (minimum one)",
            timeArabic = "بعد العشاء إلى طلوع الفجر، ويُجعل آخر صلاة الليل",
            timeEnglish = "After Isha until dawn — made the last prayer of the night",
            noteArabic = "«اجعلوا آخر صلاتكم بالليل وترًا» — متفق عليه. ومن خاف ألا يقوم آخر الليل أوتر أوله.",
            noteEnglish = "“Make the last of your night prayers Witr” (agreed upon). Whoever fears missing the end of the night prays it early."),
        NawafilItem(R.drawable.ic_book,
            nameArabic = "تحية المسجد", nameEnglish = "Tahiyyat al-Masjid",
            rakahsArabic = "ركعتان", rakahsEnglish = "2 rak'ahs",
            timeArabic = "عند دخول المسجد قبل الجلوس",
            timeEnglish = "Upon entering the mosque, before sitting",
            noteArabic = "«إذا دخل أحدكم المسجد فلا يجلس حتى يصلي ركعتين» — متفق عليه.",
            noteEnglish = "“When one of you enters the mosque, let him not sit until he prays two rak'ahs” (agreed upon)."),
        NawafilItem(R.drawable.ic_moon,
            nameArabic = "سنة الوضوء", nameEnglish = "After Wudu",
            rakahsArabic = "ركعتان", rakahsEnglish = "2 rak'ahs",
            timeArabic = "عقب الوضوء",
            timeEnglish = "Right after performing wudu",
            noteArabic = "شهد النبي ﷺ لبلال بمكانته في الجنة بسبب محافظته على ركعتين بعد كل وضوء — متفق عليه.",
            noteEnglish = "The Prophet ﷺ attested to Bilal's rank in Paradise for keeping two rak'ahs after every wudu (agreed upon)."),
    )

    val avoid: String get() = if (isArabicLocale()) avoidArabic else avoidEnglish

    const val avoidArabic =
        "أوقات النهي: بعد صلاة الفجر حتى ترتفع الشمس، وعند قيامها في كبد السماء حتى تزول، وبعد صلاة العصر حتى تغرب — إلا ذوات الأسباب."
    const val avoidEnglish =
        "Times to avoid voluntary prayer: after Fajr until the sun has risen, when it is at its zenith until it passes, and after Asr until sunset — except prayers with a specific cause."
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NawafilSheet(onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .heightIn(max = 620.dp)
                .padding(horizontal = 16.dp)
        ) {
            item {
                Text(stringResource(R.string.g1_nawafil), fontSize = 18.sp, fontWeight = FontWeight.Bold,
                     color = NoorColor.inkPrimary,
                     modifier = Modifier.padding(bottom = 2.dp))
            }
            items(Nawafil.all, key = { it.nameEnglish }) { item ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(NoorColor.bgElevated, RoundedCornerShape(16.dp))
                        .padding(16.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(painterResource(item.icon), contentDescription = null,
                             tint = NoorColor.accentGold,
                             modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(10.dp))
                        Text(item.name, fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                             color = NoorColor.inkPrimary, modifier = Modifier.weight(1f))
                        Text(item.rakahs, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                             color = NoorColor.accentPrimary)
                    }
                    Row {
                        Icon(painterResource(R.drawable.ic_clock), contentDescription = null,
                             tint = NoorColor.inkSecondary,
                             modifier = Modifier.size(14.dp).padding(top = 2.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(item.time, fontSize = 14.sp, color = NoorColor.inkSecondary,
                             lineHeight = 21.sp)
                    }
                    Text(item.note, fontSize = 14.5.sp,
                         color = NoorColor.inkPrimary.copy(alpha = 0.85f),
                         lineHeight = 24.sp)
                }
            }
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(NoorColor.accentGold.copy(alpha = 0.08f),
                                    RoundedCornerShape(12.dp))
                        .padding(14.dp)
                ) {
                    Text("⚠", fontSize = 13.sp, color = NoorColor.accentGold)
                    Spacer(Modifier.width(8.dp))
                    Text(Nawafil.avoid, fontSize = 13.5.sp,
                         color = NoorColor.inkSecondary, lineHeight = 21.sp)
                }
            }
            item { Spacer(Modifier.padding(bottom = 24.dp)) }
        }
    }
}
