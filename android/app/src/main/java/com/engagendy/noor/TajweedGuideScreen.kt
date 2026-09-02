package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// Reference guide: mushaf pause marks (علامات الوقف), other mushaf symbols,
/// and the core tajweed letter rules — 1:1 port of the iOS TajweedGuideView
/// (Modules/QuranReader). Educational content; the symbols are standalone
/// orthographic marks, not Quranic text.
private data class TajweedMark(
    val symbol: String,
    val name: String,
    val meaning: String,
    val quranFont: Boolean,
)

private val pauseMarks = listOf(
    TajweedMark("ـۘ", "مـ — الوقف اللازم",
                "يجب الوقوف هنا؛ الوصل قد يغيّر المعنى.", true),
    TajweedMark("ـۙ", "لا — لا تقف",
                "لا يصح الوقوف هنا؛ صِلْ القراءة.", true),
    TajweedMark("ـۚ", "ج — الوقف الجائز",
                "يجوز الوقف والوصل على السواء.", true),
    TajweedMark("ـۖ", "صلى — الوصل أولى",
                "يجوز الوقف، والوصل أفضل.", true),
    TajweedMark("ـۗ", "قلى — الوقف أولى",
                "يجوز الوصل، والوقف أفضل.", true),
    TajweedMark("ـۛ ـۛ", "المعانقة",
                "قف عند إحدى العلامتين لا كلتيهما.", true),
    TajweedMark("ـۜ", "س — السكتة",
                "سكتة لطيفة دون تنفّس.", true),
)

private val otherMarks = listOf(
    TajweedMark("۩", "السجدة", "موضع سجود التلاوة.", true),
    TajweedMark("۞", "ربع الحزب", "بداية ربع الحزب من أحزاب القرآن.", true),
    TajweedMark("ـٓ", "علامة المد",
                "إطالة الصوت بالحرف ست حركات غالبًا.", true),
    TajweedMark("ـۢ", "ميم الإقلاب الصغيرة",
                "تُقلب النون الساكنة أو التنوين ميمًا قبل الباء.", true),
)

private val tajweedRules = listOf(
    TajweedMark("ء هـ ع ح غ خ", "الإظهار الحلقي",
                "تُنطق النون الساكنة والتنوين بوضوح قبل حروف الحلق الستة.", false),
    TajweedMark("ي ن م و", "الإدغام بغنة",
                "تُدغم النون في هذه الحروف مع غنة مقدارها حركتان.", false),
    TajweedMark("ل ر", "الإدغام بغير غنة",
                "تُدغم النون في اللام والراء دون غنة.", false),
    TajweedMark("ب", "الإقلاب",
                "تُقلب النون الساكنة والتنوين ميمًا مخفاة قبل الباء.", false),
    TajweedMark("باقي الحروف", "الإخفاء الحقيقي",
                "تُخفى النون مع غنة قبل الحروف الخمسة عشر الباقية.", false),
    TajweedMark("ق ط ب ج د", "القلقلة",
                "اهتزاز الصوت عند سكون هذه الحروف الخمسة.", false),
)

@Composable
fun TajweedGuideScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        item {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp)
            ) {
                Text(stringResource(R.string.g1_tajweed_guide), fontSize = 22.sp, fontWeight = FontWeight.Bold,
                     color = NoorColor.inkPrimary)
                Text(stringResource(R.string.g1_back), fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.accentPrimary,
                     modifier = Modifier
                         .clickable(onClick = onBack)
                         .padding(horizontal = 10.dp, vertical = 6.dp))
            }
        }
        tajweedSection(R.string.g1_pause_marks, pauseMarks)
        tajweedSection(R.string.g1_mushaf_symbols, otherMarks)
        tajweedSection(R.string.g1_tajweed_rules, tajweedRules)
        item { Spacer(Modifier.padding(bottom = 24.dp)) }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.tajweedSection(
    title: Int,
    marks: List<TajweedMark>,
) {
    item {
        Text(stringResource(title), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
             color = NoorColor.inkSecondary,
             modifier = Modifier.padding(top = 18.dp, bottom = 8.dp))
    }
    items(marks, key = { it.symbol + it.name }) { mark ->
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 2.dp)
                .background(NoorColor.bgElevated, RoundedCornerShape(12.dp))
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Text(
                mark.symbol,
                fontFamily = if (mark.quranFont) QuranFont else null,
                fontSize = if (mark.quranFont) 24.sp else 16.sp,
                fontWeight = if (mark.quranFont) FontWeight.Normal else FontWeight.SemiBold,
                textAlign = TextAlign.Center,
                color = NoorColor.accentGold,
                modifier = Modifier.widthIn(min = 56.dp))
            Column(Modifier.weight(1f)) {
                Text(mark.name, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.inkPrimary)
                Text(mark.meaning, fontSize = 13.sp, lineHeight = 19.sp,
                     color = NoorColor.inkSecondary)
            }
        }
    }
}
