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
    val name: String,
    val rakahs: String,
    val time: String,
    val note: String,
)

object Nawafil {
    val all = listOf(
        NawafilItem(R.drawable.ic_sun, "السنن الرواتب", "١٢ ركعة",
            "٢ قبل الفجر · ٤ قبل الظهر و٢ بعدها · ٢ بعد المغرب · ٢ بعد العشاء",
            "«من صلى اثنتي عشرة ركعة في يوم وليلة بُني له بهن بيت في الجنة» — رواه مسلم. وأوكدها ركعتا الفجر."),
        NawafilItem(R.drawable.ic_sun, "صلاة الضحى", "٢ إلى ٨ ركعات",
            "من ارتفاع الشمس (بعد الشروق بربع ساعة تقريبًا) إلى قبيل الظهر",
            "أوصى بها النبي ﷺ أبا هريرة، وقال: «يصبح على كل سُلامى من أحدكم صدقة… ويجزئ من ذلك ركعتان يركعهما من الضحى» — رواه مسلم. وأفضل وقتها اشتداد الحر."),
        NawafilItem(R.drawable.ic_moon, "قيام الليل (التهجد)", "مثنى مثنى، بلا حد",
            "بعد العشاء إلى الفجر، وأفضله الثلث الأخير من الليل",
            "«أفضل الصلاة بعد الفريضة صلاة الليل» — رواه مسلم. وينزل ربنا في الثلث الأخير فيجيب الداعي ويعطي السائل ويغفر للمستغفر."),
        NawafilItem(R.drawable.ic_sparkle, "الوتر", "١ إلى ١١ ركعة (أقله واحدة)",
            "بعد العشاء إلى طلوع الفجر، ويُجعل آخر صلاة الليل",
            "«اجعلوا آخر صلاتكم بالليل وترًا» — متفق عليه. ومن خاف ألا يقوم آخر الليل أوتر أوله."),
        NawafilItem(R.drawable.ic_book, "تحية المسجد", "ركعتان",
            "عند دخول المسجد قبل الجلوس",
            "«إذا دخل أحدكم المسجد فلا يجلس حتى يصلي ركعتين» — متفق عليه."),
        NawafilItem(R.drawable.ic_moon, "سنة الوضوء", "ركعتان",
            "عقب الوضوء",
            "شهد النبي ﷺ لبلال بمكانته في الجنة بسبب محافظته على ركعتين بعد كل وضوء — متفق عليه."),
    )

    const val AVOID =
        "أوقات النهي: بعد صلاة الفجر حتى ترتفع الشمس، وعند قيامها في كبد السماء حتى تزول، وبعد صلاة العصر حتى تغرب — إلا ذوات الأسباب."
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
            items(Nawafil.all, key = { it.name }) { item ->
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
                    Text(Nawafil.AVOID, fontSize = 13.5.sp,
                         color = NoorColor.inkSecondary, lineHeight = 21.sp)
                }
            }
            item { Spacer(Modifier.padding(bottom = 24.dp)) }
        }
    }
}
