package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

// MARK: - Shared header

@Composable
fun ExtraHeader(title: String, onBack: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Text(title, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = NoorColor.inkPrimary)
        Text("رجوع", color = NoorColor.accentPrimary, fontWeight = FontWeight.SemiBold,
             modifier = Modifier.clickable(onClick = onBack).padding(8.dp))
    }
}

// MARK: - الرقية الشرعية

/// The Quranic ayat are LOADED from the verified database by reference
/// (never typed — CLAUDE.md rule 1); the prophetic formulas are hadith
/// texts. 1:1 with iOS RuqyahView.swift.
private data class RuqyahPassage(val surahId: Int, val first: Int, val last: Int)

private val ruqyahPassages = listOf(
    RuqyahPassage(1, 1, 7),
    RuqyahPassage(2, 1, 5),
    RuqyahPassage(2, 102, 102),
    RuqyahPassage(2, 163, 164),
    RuqyahPassage(2, 255, 257),
    RuqyahPassage(2, 285, 286),
    RuqyahPassage(3, 18, 19),
    RuqyahPassage(7, 117, 122),
    RuqyahPassage(10, 81, 82),
    RuqyahPassage(20, 69, 69),
    RuqyahPassage(23, 115, 118),
    RuqyahPassage(37, 1, 10),
    RuqyahPassage(59, 21, 24),
    RuqyahPassage(112, 1, 4),
    RuqyahPassage(113, 1, 5),
    RuqyahPassage(114, 1, 6),
)

private data class RuqyahProphetic(val text: String, val source: String)

private val ruqyahProphetic = listOf(
    RuqyahProphetic(
        "بِسْمِ اللهِ أَرْقِيكَ، مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنِ حَاسِدٍ، اللهُ يَشْفِيكَ، بِسْمِ اللهِ أَرْقِيكَ.",
        "رواه مسلم"),
    RuqyahProphetic(
        "اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِ وَأَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا.",
        "متفق عليه"),
    RuqyahProphetic(
        "أَعُوذُ بِكَلِمَاتِ اللهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.",
        "رواه مسلم"),
    RuqyahProphetic(
        "أَعُوذُ بِكَلِمَاتِ اللهِ التَّامَّةِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ، وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ.",
        "رواه البخاري"),
    RuqyahProphetic(
        "أَسْأَلُ اللهَ الْعَظِيمَ رَبَّ الْعَرْشِ الْعَظِيمِ أَنْ يَشْفِيَكَ. (سبع مرات)",
        "رواه أبو داود والترمذي"),
)

private data class LoadedPassage(val reference: String, val text: String)

/// Joins a verse range into a flow with ayah markers — same form the
/// reader uses; the text comes straight from quran.sqlite.
private fun joinVerses(verses: List<Verse>): String =
    verses.joinToString(" ") { "${it.text} ⁧﴿${it.ayah.arabicIndic()}﴾⁩" }

@Composable
fun RuqyahScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    // Parsing/queries off the main thread.
    val passages by produceState<List<LoadedPassage>>(initialValue = emptyList()) {
        value = withContext(Dispatchers.IO) {
            val db = QuranDb.get(context)
            val surahs = db.surahs()
            ruqyahPassages.mapNotNull { passage ->
                val slice = db.verses(passage.surahId)
                    .filter { it.ayah in passage.first..passage.last }
                if (slice.isEmpty()) return@mapNotNull null
                val name = surahs.firstOrNull { it.id == passage.surahId }?.nameArabic ?: ""
                val reference = if (passage.first == passage.last)
                    "$name · ${passage.first.arabicIndic()}"
                else
                    "$name · ${passage.first.arabicIndic()}–${passage.last.arabicIndic()}"
                LoadedPassage(reference, joinVerses(slice))
            }
        }
    }

    Column(modifier.fillMaxSize()) {
        ExtraHeader("الرقية الشرعية", onBack)
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
            item {
                Text(
                    "آيات الرقية تُقرأ بتدبر مع النفث، ثلاثًا أو أكثر. النصوص من المصحف المعتمد.",
                    fontSize = 13.sp,
                    color = NoorColor.inkSecondary,
                    modifier = Modifier.padding(bottom = 10.dp)
                )
            }
            items(passages) { item ->
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp)
                        .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                        .padding(16.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(item.reference, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                             color = NoorColor.accentGold, modifier = Modifier.weight(1f))
                        ShareIconButton {
                            shareRendered(context, item.text, item.reference, useQuranFont = true,
                                          attribution = "نور Noor · Quran text: Tanzil.net")
                        }
                    }
                    Text(item.text, fontFamily = QuranFont, fontSize = 20.sp, lineHeight = 44.sp,
                         color = NoorColor.inkPrimary, modifier = Modifier.padding(top = 8.dp))
                }
            }
            item {
                Text("الأدعية النبوية", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.accentPrimary,
                     modifier = Modifier.padding(top = 10.dp, bottom = 4.dp))
            }
            items(ruqyahProphetic) { dua ->
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp)
                        .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                        .padding(16.dp)
                ) {
                    Text(dua.text, fontSize = 17.sp, lineHeight = 30.sp,
                         color = NoorColor.inkPrimary)
                    Row(verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                        Text(dua.source, fontSize = 12.sp, color = NoorColor.accentGold,
                             modifier = Modifier.weight(1f))
                        ShareIconButton { shareRendered(context, dua.text, dua.source) }
                    }
                }
            }
            item { Spacer(Modifier.padding(bottom = 24.dp)) }
        }
    }
}

// MARK: - أدعية مختارة

/// Curated duas: Quranic ones LOADED from the mushaf DB by reference
/// (rule 1); prophetic ones are hadith texts with sources — 1:1 with
/// iOS SelectedDuasView.swift.
private data class QuranicDuaRef(val surahId: Int, val first: Int, val last: Int)

private val quranicDuas = listOf(
    QuranicDuaRef(2, 201, 201),
    QuranicDuaRef(2, 286, 286),
    QuranicDuaRef(3, 8, 8),
    QuranicDuaRef(3, 16, 16),
    QuranicDuaRef(3, 193, 194),
    QuranicDuaRef(14, 40, 41),
    QuranicDuaRef(18, 10, 10),
    QuranicDuaRef(20, 25, 28),
    QuranicDuaRef(21, 87, 87),
    QuranicDuaRef(23, 97, 98),
    QuranicDuaRef(25, 74, 74),
    QuranicDuaRef(59, 10, 10),
    QuranicDuaRef(66, 8, 8),
)

private data class PropheticDua(val title: String, val text: String, val source: String)

private val propheticDuas = listOf(
    PropheticDua(
        "دعاء الاستخارة",
        "اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ، فَإِنَّكَ تَقْدِرُ وَلَا أَقْدِرُ، وَتَعْلَمُ وَلَا أَعْلَمُ، وَأَنْتَ عَلَّامُ الْغُيُوبِ. اللَّهُمَّ إِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ خَيْرٌ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاقْدُرْهُ لِي وَيَسِّرْهُ لِي ثُمَّ بَارِكْ لِي فِيهِ، وَإِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ شَرٌّ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاصْرِفْهُ عَنِّي وَاصْرِفْنِي عَنْهُ، وَاقْدُرْ لِيَ الْخَيْرَ حَيْثُ كَانَ ثُمَّ أَرْضِنِي بِهِ. (ويسمي حاجته)",
        "رواه البخاري"),
    PropheticDua(
        "دعاء الكرب",
        "لَا إِلَهَ إِلَّا اللهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَهَ إِلَّا اللهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ.",
        "متفق عليه"),
    PropheticDua(
        "دعاء الهم والحزن",
        "اللَّهُمَّ إِنِّي عَبْدُكَ، ابْنُ عَبْدِكَ، ابْنُ أَمَتِكَ، نَاصِيَتِي بِيَدِكَ، مَاضٍ فِيَّ حُكْمُكَ، عَدْلٌ فِيَّ قَضَاؤُكَ، أَسْأَلُكَ بِكُلِّ اسْمٍ هُوَ لَكَ سَمَّيْتَ بِهِ نَفْسَكَ أَنْ تَجْعَلَ الْقُرْآنَ رَبِيعَ قَلْبِي، وَنُورَ صَدْرِي، وَجَلَاءَ حُزْنِي، وَذَهَابَ هَمِّي.",
        "رواه أحمد"),
    PropheticDua(
        "دعاء السفر",
        "اللهُ أَكْبَرُ، اللهُ أَكْبَرُ، اللهُ أَكْبَرُ، سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ. اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى، وَمِنَ الْعَمَلِ مَا تَرْضَى.",
        "رواه مسلم"),
    PropheticDua(
        "دعاء نزول المطر",
        "اللَّهُمَّ صَيِّبًا نَافِعًا.",
        "رواه البخاري"),
    PropheticDua(
        "جوامع الدعاء",
        "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ. يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ. اللَّهُمَّ أَصْلِحْ لِي دِينِيَ الَّذِي هُوَ عِصْمَةُ أَمْرِي، وَأَصْلِحْ لِي دُنْيَايَ الَّتِي فِيهَا مَعَاشِي، وَأَصْلِحْ لِي آخِرَتِيَ الَّتِي فِيهَا مَعَادِي.",
        "رواه مسلم والترمذي"),
)

@Composable
fun SelectedDuasScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val quranic by produceState<List<LoadedPassage>>(initialValue = emptyList()) {
        value = withContext(Dispatchers.IO) {
            val db = QuranDb.get(context)
            val surahs = db.surahs()
            quranicDuas.mapNotNull { dua ->
                val slice = db.verses(dua.surahId).filter { it.ayah in dua.first..dua.last }
                if (slice.isEmpty()) return@mapNotNull null
                val name = surahs.firstOrNull { it.id == dua.surahId }?.nameArabic ?: ""
                LoadedPassage("$name · ${dua.first.arabicIndic()}", joinVerses(slice))
            }
        }
    }

    Column(modifier.fillMaxSize()) {
        ExtraHeader("أدعية مختارة", onBack)
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
            item {
                Text("أدعية من القرآن", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.accentPrimary, modifier = Modifier.padding(bottom = 4.dp))
            }
            items(quranic) { item ->
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp)
                        .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                        .padding(16.dp)
                ) {
                    Text(item.text, fontFamily = QuranFont, fontSize = 19.sp, lineHeight = 40.sp,
                         color = NoorColor.inkPrimary)
                    Row(verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                        Text(item.reference, fontSize = 12.sp, color = NoorColor.accentGold,
                             modifier = Modifier.weight(1f))
                        ShareIconButton {
                            shareRendered(context, item.text, item.reference, useQuranFont = true,
                                          attribution = "نور Noor · Quran text: Tanzil.net")
                        }
                    }
                }
            }
            item {
                Text("أدعية من السنة", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.accentPrimary,
                     modifier = Modifier.padding(top = 10.dp, bottom = 4.dp))
            }
            items(propheticDuas) { dua ->
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp)
                        .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                        .padding(16.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(dua.title, fontSize = 15.sp, fontWeight = FontWeight.Bold,
                             color = NoorColor.accentGold, modifier = Modifier.weight(1f))
                        ShareIconButton {
                            shareRendered(context, dua.text, "${dua.title} · ${dua.source}")
                        }
                    }
                    Text(dua.text, fontSize = 17.sp, lineHeight = 30.sp,
                         color = NoorColor.inkPrimary, modifier = Modifier.padding(top = 6.dp))
                    Text(dua.source, fontSize = 12.sp, color = NoorColor.inkSecondary,
                         modifier = Modifier.padding(top = 8.dp))
                }
            }
            item { Spacer(Modifier.padding(bottom = 24.dp)) }
        }
    }
}

// MARK: - أسماء الله الحسنى

/// The 99 Beautiful Names with meanings — data ported 1:1 from the iOS
/// AsmaulHusnaView.swift.
data class DivineName(
    val number: Int,
    val arabic: String,
    val transliteration: String,
    val meaningArabic: String,
)

val divineNames: List<DivineName> = listOf(
    Triple("الرحمن", "Ar-Rahman", "ذو الرحمة الواسعة لجميع الخلق"),
    Triple("الرحيم", "Ar-Raheem", "الموصل رحمته لعباده المؤمنين"),
    Triple("الملك", "Al-Malik", "المالك المتصرف في ملكه"),
    Triple("القدوس", "Al-Quddus", "المنزّه عن كل نقص"),
    Triple("السلام", "As-Salam", "السالم من كل عيب، ومسلّم عباده"),
    Triple("المؤمن", "Al-Mu'min", "المصدّق رسله والمؤمّن خلقه"),
    Triple("المهيمن", "Al-Muhaymin", "الرقيب الحافظ على كل شيء"),
    Triple("العزيز", "Al-Aziz", "الغالب الذي لا يُقهر"),
    Triple("الجبار", "Al-Jabbar", "القاهر لخلقه، الجابر للكسير"),
    Triple("المتكبر", "Al-Mutakabbir", "المتعالي عن صفات الخلق"),
    Triple("الخالق", "Al-Khaliq", "الموجد للأشياء من العدم"),
    Triple("البارئ", "Al-Bari", "المبدع الخلق بلا مثال"),
    Triple("المصور", "Al-Musawwir", "المعطي كل مخلوق صورته"),
    Triple("الغفار", "Al-Ghaffar", "الساتر لذنوب عباده مرة بعد مرة"),
    Triple("القهار", "Al-Qahhar", "الغالب الذي خضع له كل شيء"),
    Triple("الوهاب", "Al-Wahhab", "المعطي بلا عوض"),
    Triple("الرزاق", "Ar-Razzaq", "المتكفل بأرزاق العباد"),
    Triple("الفتاح", "Al-Fattah", "الحاكم الفاتح لأبواب الرحمة"),
    Triple("العليم", "Al-Aleem", "المحيط علمه بكل شيء"),
    Triple("القابض", "Al-Qabid", "يقبض الرزق والأرواح بحكمته"),
    Triple("الباسط", "Al-Basit", "يبسط الرزق لمن يشاء"),
    Triple("الخافض", "Al-Khafid", "يخفض أهل الباطل والمتكبرين"),
    Triple("الرافع", "Ar-Rafi", "يرفع أولياءه بالطاعة"),
    Triple("المعز", "Al-Mu'izz", "يهب العز لمن يشاء"),
    Triple("المذل", "Al-Mudhill", "يذل من يشاء بعدله"),
    Triple("السميع", "As-Samee", "المدرك للأصوات كلها"),
    Triple("البصير", "Al-Baseer", "المدرك للمرئيات كلها"),
    Triple("الحكم", "Al-Hakam", "الفاصل بين عباده بالحق"),
    Triple("العدل", "Al-Adl", "المنزّه عن الظلم"),
    Triple("اللطيف", "Al-Lateef", "البَرّ بعباده الخبير بدقائق الأمور"),
    Triple("الخبير", "Al-Khabeer", "العالم ببواطن الأمور"),
    Triple("الحليم", "Al-Haleem", "لا يعاجل العصاة بالعقوبة"),
    Triple("العظيم", "Al-Azeem", "ذو العظمة في كل شيء"),
    Triple("الغفور", "Al-Ghafoor", "الكثير المغفرة"),
    Triple("الشكور", "Ash-Shakoor", "يجزي على القليل بالكثير"),
    Triple("العلي", "Al-Ali", "العالي فوق خلقه قدرًا وقهرًا"),
    Triple("الكبير", "Al-Kabeer", "الأكبر من كل شيء"),
    Triple("الحفيظ", "Al-Hafeedh", "الحافظ لكل شيء عن الزوال"),
    Triple("المقيت", "Al-Muqeet", "المتكفل بالأقوات، المقتدر"),
    Triple("الحسيب", "Al-Haseeb", "الكافي عباده، المحاسب"),
    Triple("الجليل", "Al-Jaleel", "ذو الجلال والصفات العظيمة"),
    Triple("الكريم", "Al-Kareem", "الكثير الخير والعطاء"),
    Triple("الرقيب", "Ar-Raqeeb", "المطلع الذي لا يغيب عنه شيء"),
    Triple("المجيب", "Al-Mujeeb", "يجيب دعاء من دعاه"),
    Triple("الواسع", "Al-Wasi", "وسع كل شيء رحمة وعلمًا"),
    Triple("الحكيم", "Al-Hakeem", "يضع الأمور في مواضعها"),
    Triple("الودود", "Al-Wadood", "المحب لعباده الصالحين المحبوب"),
    Triple("المجيد", "Al-Majeed", "العظيم الكريم الجميل الأفعال"),
    Triple("الباعث", "Al-Ba'ith", "يبعث الخلق يوم القيامة"),
    Triple("الشهيد", "Ash-Shaheed", "المطلع على كل شيء شهادةً"),
    Triple("الحق", "Al-Haqq", "الثابت الذي لا يزول"),
    Triple("الوكيل", "Al-Wakeel", "المتكفل بأمور من توكل عليه"),
    Triple("القوي", "Al-Qawiyy", "كامل القوة لا يعجزه شيء"),
    Triple("المتين", "Al-Mateen", "الشديد القوة الذي لا يمسه لغوب"),
    Triple("الولي", "Al-Waliyy", "الناصر المتولي أمور عباده"),
    Triple("الحميد", "Al-Hameed", "المستحق للحمد في ذاته وأفعاله"),
    Triple("المحصي", "Al-Muhsi", "أحاط بكل شيء عددًا"),
    Triple("المبدئ", "Al-Mubdi", "بدأ الخلق أول مرة"),
    Triple("المعيد", "Al-Mu'eed", "يعيد الخلق بعد الموت"),
    Triple("المحيي", "Al-Muhyi", "يهب الحياة لمن يشاء"),
    Triple("المميت", "Al-Mumeet", "المقدّر للموت على خلقه"),
    Triple("الحي", "Al-Hayy", "له الحياة الكاملة الدائمة"),
    Triple("القيوم", "Al-Qayyum", "القائم بنفسه المقيم لغيره"),
    Triple("الواجد", "Al-Wajid", "الذي لا يعوزه شيء"),
    Triple("الماجد", "Al-Majid", "ذو المجد والسعة في الكرم"),
    Triple("الواحد", "Al-Wahid", "المنفرد بلا شريك"),
    Triple("الأحد", "Al-Ahad", "المتوحد في ذاته وصفاته"),
    Triple("الصمد", "As-Samad", "المقصود في الحوائج الغني عن الكل"),
    Triple("القادر", "Al-Qadir", "ذو القدرة التامة"),
    Triple("المقتدر", "Al-Muqtadir", "البالغ القدرة لا يمتنع عليه شيء"),
    Triple("المقدم", "Al-Muqaddim", "يقدّم من يشاء بحكمته"),
    Triple("المؤخر", "Al-Mu'akhkhir", "يؤخر من يشاء بحكمته"),
    Triple("الأول", "Al-Awwal", "الذي ليس قبله شيء"),
    Triple("الآخر", "Al-Akhir", "الذي ليس بعده شيء"),
    Triple("الظاهر", "Adh-Dhahir", "الذي ليس فوقه شيء"),
    Triple("الباطن", "Al-Batin", "الذي ليس دونه شيء، العالم بالخفايا"),
    Triple("الوالي", "Al-Wali", "المتولي تدبير الأمور"),
    Triple("المتعالي", "Al-Muta'ali", "المرتفع عن كل نقص"),
    Triple("البر", "Al-Barr", "الواسع البر والإحسان"),
    Triple("التواب", "At-Tawwab", "يقبل التوبة ويوفق إليها"),
    Triple("المنتقم", "Al-Muntaqim", "ينتقم من المصرّين على العناد بعدله"),
    Triple("العفو", "Al-Afuww", "الكثير العفو والمحو للذنوب"),
    Triple("الرؤوف", "Ar-Ra'oof", "شديد الرحمة والرأفة"),
    Triple("مالك الملك", "Malik-ul-Mulk", "يؤتي الملك من يشاء وينزعه"),
    Triple("ذو الجلال والإكرام", "Dhul-Jalali wal-Ikram", "المستحق للتعظيم والإكرام"),
    Triple("المقسط", "Al-Muqsit", "العادل في حكمه"),
    Triple("الجامع", "Al-Jami", "يجمع الخلق ليوم لا ريب فيه"),
    Triple("الغني", "Al-Ghaniyy", "المستغني عن كل ما سواه"),
    Triple("المغني", "Al-Mughni", "يغني من يشاء من عباده"),
    Triple("المانع", "Al-Mani", "يمنع العطاء والبلاء بحكمته"),
    Triple("الضار", "Ad-Darr", "يقدّر الضر بحكمته وعدله"),
    Triple("النافع", "An-Nafi", "يوصل النفع لمن يشاء"),
    Triple("النور", "An-Noor", "نور السماوات والأرض، الهادي"),
    Triple("الهادي", "Al-Hadi", "يهدي من يشاء إلى الحق"),
    Triple("البديع", "Al-Badee", "المبدع للخلق بلا مثال سابق"),
    Triple("الباقي", "Al-Baqi", "الدائم الذي لا يفنى"),
    Triple("الوارث", "Al-Warith", "الباقي بعد فناء الخلق"),
    Triple("الرشيد", "Ar-Rasheed", "المرشد لعباده إلى مصالحهم"),
    Triple("الصبور", "As-Saboor", "لا يعاجل العصاة بالعقوبة"),
).mapIndexed { index, entry ->
    DivineName(index + 1, entry.first, entry.second, entry.third)
}

/// The 99 Names screen: calm two-column grid, tap → detail sheet.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AsmaulHusnaScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var selected by remember { mutableStateOf<DivineName?>(null) }

    Column(modifier.fillMaxSize()) {
        ExtraHeader("أسماء الله الحسنى", onBack)
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxSize().padding(16.dp)
        ) {
            items(divineNames) { name ->
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .clip(RoundedCornerShape(14.dp))
                        .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                        .clickable { selected = name }
                        .padding(vertical = 14.dp)
                        .fillMaxWidth()
                ) {
                    Text(name.arabic, fontFamily = QuranFont, fontSize = 21.sp, maxLines = 1,
                         color = NoorColor.inkPrimary)
                    Text(name.number.arabicIndic(), fontSize = 12.sp,
                         color = NoorColor.inkSecondary, modifier = Modifier.padding(top = 4.dp))
                }
            }
        }
    }

    val name = selected
    if (name != null) {
        ModalBottomSheet(onDismissRequest = { selected = null },
                         containerColor = NoorColor.bgPrimary) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 28.dp, vertical = 24.dp)
            ) {
                Text(name.arabic, fontFamily = QuranFont, fontSize = 42.sp,
                     color = NoorColor.accentPrimary)
                Text(name.transliteration, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.accentGold, modifier = Modifier.padding(top = 8.dp))
                Text(name.meaningArabic, fontSize = 17.sp, lineHeight = 28.sp,
                     textAlign = TextAlign.Center, color = NoorColor.inkPrimary,
                     modifier = Modifier.padding(top = 12.dp, bottom = 12.dp))
                // Branded card share, like the iOS AsmaulHusnaView sheet.
                ShareIconButton {
                    shareRendered(context, name.arabic, "من أسماء الله الحسنى",
                                  translation = name.meaningArabic)
                }
                Spacer(Modifier.padding(bottom = 8.dp))
            }
        }
    }
}

// MARK: - المسبحة (tasbih counter)

private val tasbihPhrases = listOf(
    "سُبْحَانَ اللهِ",
    "الْحَمْدُ لِلَّهِ",
    "اللهُ أَكْبَرُ",
    "لَا إِلَهَ إِلَّا اللهُ",
    "أَسْتَغْفِرُ اللهَ",
    "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ",
    "سُبْحَانَ اللهِ وَبِحَمْدِهِ",
    "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ",
)

/// Tasbih counter: phrase chips + a big tap circle. Counts persist per
/// phrase; prefs are written only from tap handlers (never observers).
@Composable
fun TasbihScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val prefs = remember { KhatmahPlan.prefs(context) }
    var phraseIndex by remember { mutableIntStateOf(prefs.getInt("tasbih.phrase", 0)) }
    var count by remember {
        mutableIntStateOf(prefs.getInt("tasbih.count.${prefs.getInt("tasbih.phrase", 0)}", 0))
    }

    fun selectPhrase(index: Int) {
        phraseIndex = index
        count = prefs.getInt("tasbih.count.$index", 0)
        prefs.edit().putInt("tasbih.phrase", index).apply()
    }

    Column(modifier.fillMaxSize()) {
        ExtraHeader("المسبحة", onBack)
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp)
        ) {
            // Phrase chips — flow over two lines.
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp)
                    .horizontalScroll(rememberScrollState())
            ) {
                tasbihPhrases.forEachIndexed { index, phrase ->
                    val on = index == phraseIndex
                    Text(
                        phrase,
                        fontSize = 14.sp,
                        maxLines = 1,
                        fontWeight = FontWeight.SemiBold,
                        color = if (on) NoorColor.bgPrimary else NoorColor.inkPrimary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(
                                if (on) NoorColor.accentPrimary else NoorColor.bgElevated,
                                RoundedCornerShape(50)
                            )
                            .clickable { selectPhrase(index) }
                            .padding(horizontal = 14.dp, vertical = 9.dp)
                    )
                }
            }

            Spacer(Modifier.weight(1f))
            Text(tasbihPhrases[phraseIndex], fontSize = 22.sp, fontWeight = FontWeight.Bold,
                 textAlign = TextAlign.Center, color = NoorColor.inkPrimary)
            // The big counter circle: tap anywhere to count.
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .padding(top = 24.dp)
                    .size(220.dp)
                    .border(3.dp, NoorColor.accentGold, CircleShape)
                    .clip(CircleShape)
                    .background(NoorColor.bgElevated, CircleShape)
                    .clickable {
                        count += 1
                        prefs.edit().putInt("tasbih.count.$phraseIndex", count).apply()
                    }
            ) {
                Text(count.arabicIndic(), fontSize = 64.sp, fontWeight = FontWeight.Bold,
                     color = NoorColor.accentPrimary)
            }
            Text(
                "تصفير",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = NoorColor.inkSecondary,
                modifier = Modifier
                    .padding(top = 20.dp)
                    .clickable {
                        count = 0
                        prefs.edit().putInt("tasbih.count.$phraseIndex", 0).apply()
                    }
                    .padding(10.dp)
            )
            Spacer(Modifier.weight(1.4f))
        }
    }
}
