package com.engagendy.noor

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/// The athkar a small child actually uses, by their Arabic title in the
/// bundled assets/athkar.json (Hisn al-Muslim). The dhikr TEXT is never
/// written here — only which existing chapters are surfaced.
private val KidsAthkarTitles = listOf(
    "أذكار الاستيقاظ من النوم",
    "أذكار النوم",
    "الدعاء قبل الطعام",
    "الدعاء عند الفراغ من الطعام",
    "الذكر عند الخروج من المنزل",
    "الذكر عند دخول المنزل",
    "دعاء دخول الخلاء",
    "دعاء الخروج من الخلاء",
    "دعاء الركوب",
    "دعاء السفر",
)

/// Kids mode shell — it REPLACES the normal tab bar while `kids.enabled`
/// is true (MainActivity picks one or the other), so nothing here can reach
/// Settings, search, share or the mushaf. Two tabs: اقرأ / أذكاري.
///
/// System back never escapes to the normal app: it closes whatever is open
/// inside the shell, and at the root it does nothing. The only way out is
/// the grown-up control in the header, behind the parental gate.
@Composable
fun KidsShell(onExit: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val age = KidsStore.age
    // rememberSaveable throughout: a configuration change (the language
    // switch below, or a rotation) recreates the activity, and the child
    // must come back to exactly where they were — still inside kids mode,
    // still on the same surah — not be dropped at the shell root.
    var tab by rememberSaveable { mutableStateOf("read") }
    var openSurahId by rememberSaveable { mutableStateOf(0) }
    var autoPlay by rememberSaveable { mutableStateOf(false) }
    var openCategoryTitle by rememberSaveable { mutableStateOf<String?>(null) }
    var showGate by rememberSaveable { mutableStateOf(false) }
    var showSound by rememberSaveable { mutableStateOf(false) }

    // Age-filtered surahs and the curated athkar, both read off-main once.
    val surahs by produceState(emptyList<Surah>(), age) {
        value = withContext(Dispatchers.IO) {
            val ids = KidsMode.surahIds(age).toSet()
            QuranDb.get(context).surahs().filter { it.id in ids }
        }
    }
    val categories by produceState(emptyList<DhikrCategory>()) {
        value = withContext(Dispatchers.IO) {
            val all = AthkarStore.load(context).associateBy { it.title }
            KidsAthkarTitles.mapNotNull { all[it] }
        }
    }

    /// Leaving the reader or the shell silences the recitation — kids mode
    /// has no audio pill to stop it from. (A configuration change does NOT
    /// go through here, so the recitation survives a language switch.)
    fun closeReader() {
        NoorPlayer.stop()
        openSurahId = 0
        autoPlay = false
    }

    // Root: back stays inside the shell. Composed FIRST, so the handlers
    // below (open reader / open chapter) win while they are on screen.
    BackHandler(enabled = true) { /* the shell is the root — nothing to pop */ }

    if (showSound) {
        // Child-facing, never gated: listen vs memorise, and who recites.
        KidsSoundSheet(age = age, onDismiss = { showSound = false })
    }
    if (showGate) {
        ParentalGate(
            onPass = {
                NoorPlayer.stop()
                KidsStore.disable(context)
                onExit()
            },
            onDismiss = { showGate = false })
    }

    val surah = surahs.firstOrNull { it.id == openSurahId }
    if (surah != null) {
        BackHandler(enabled = true) { closeReader() }
        KidsReader(
            surah = surah,
            age = age,
            autoPlay = autoPlay,
            onBack = ::closeReader,
            modifier = modifier)
        return
    }
    val category = categories.firstOrNull { it.title == openCategoryTitle }
    if (category != null) {
        BackHandler(enabled = true) { openCategoryTitle = null }
        // The grown-up athkar chapter screen, reused with the kid-friendly
        // presentation: bigger text and no share button.
        DhikrListScreen(
            category = category,
            onBack = { openCategoryTitle = null },
            textScale = KidsMode.textScale(age),
            showShare = false,
            modifier = modifier)
        return
    }

    Column(modifier.fillMaxSize().background(NoorColor.bgPrimary)) {
        KidsHeader(onSound = { showSound = true }, onGrownUp = { showGate = true })
        Box(Modifier.weight(1f)) {
            when (tab) {
                "athkar" -> KidsAthkarList(
                    categories = categories,
                    onOpen = { openCategoryTitle = it.title })
                else -> KidsSurahList(
                    surahs = surahs,
                    onOpen = { picked, play -> autoPlay = play; openSurahId = picked.id })
            }
        }
        KidsTabBar(tab = tab, onTab = { tab = it })
    }
}

/// Total stars + the grown-up door. No child-facing settings anywhere.
@Composable
private fun KidsHeader(onSound: () -> Unit, onGrownUp: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.weight(1f)
        ) {
            GoldStar(earned = true, size = 22.dp)
            Text(
                stringResource(R.string.kids_total_stars, KidsStore.totalStars.localizedDigits()),
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = NoorColor.inkPrimary)
        }
        // The child's own settings: language, listen/memorise, reciter (no gate).
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .heightIn(min = 48.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(NoorColor.bgElevated, RoundedCornerShape(16.dp))
                .clickable(onClick = onSound)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Icon(
                painterResource(R.drawable.ic_sliders),
                contentDescription = null,
                tint = NoorColor.accentPrimary,
                modifier = Modifier.size(20.dp))
            Text(
                stringResource(R.string.kids_settings),
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = NoorColor.inkPrimary)
        }
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .clickable(onClick = onGrownUp)
        ) {
            Icon(
                painterResource(R.drawable.ic_gear),
                contentDescription = stringResource(R.string.kids_grownup),
                tint = NoorColor.inkSecondary,
                modifier = Modifier.size(22.dp))
        }
    }
}

/// Large surah cards, filtered by the age band (`KidsMode.surahIds`).
@Composable
private fun KidsSurahList(surahs: List<Surah>, onOpen: (Surah, Boolean) -> Unit) {
    LazyColumn(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 16.dp, end = 16.dp, top = 4.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        items(surahs, key = { it.id }) { surah ->
            KidsSurahCard(
                surah = surah,
                stars = KidsStore.stars(surah.id),
                onOpen = { onOpen(surah, false) },
                onPlay = { onOpen(surah, true) })
        }
    }
}

@Composable
private fun KidsSurahCard(
    surah: Surah,
    stars: Int,
    onOpen: () -> Unit,
    onPlay: () -> Unit,
) {
    val shape = RoundedCornerShape(20.dp)
    Box(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(NoorColor.bgElevated, shape)
            .clickable(onClick = onOpen)
    ) {
        // A quiet star lattice behind the card — ornament, never noise.
        IslamicLattice(
            tint = NoorColor.accentPrimary.copy(alpha = 0.05f),
            tile = 48.dp,
            modifier = Modifier.matchParentSize())
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(NoorColor.stateReciting, CircleShape)
            ) {
                Text(
                    surah.id.localizedDigits(),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.accentPrimary)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    surah.nameArabic,
                    fontFamily = HafsFont,
                    fontSize = 28.sp,
                    color = NoorColor.inkPrimary,
                    style = arabicText(),
                    modifier = Modifier.fillMaxWidth())
                Text(
                    stringResource(R.string.kids_ayah_count, surah.ayahCount.localizedDigits()),
                    fontSize = 13.sp,
                    color = NoorColor.inkSecondary)
                StarRow(stars)
            }
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(NoorColor.accentPrimary, CircleShape)
                    .clickable(onClick = onPlay)
            ) {
                Icon(
                    painterResource(R.drawable.ic_play_fill),
                    contentDescription = stringResource(R.string.kids_listen),
                    tint = NoorColor.bgPrimary,
                    modifier = Modifier.size(24.dp))
            }
        }
    }
}

/// The curated athkar set, in the order a child's day runs.
@Composable
private fun KidsAthkarList(categories: List<DhikrCategory>, onOpen: (DhikrCategory) -> Unit) {
    LazyColumn(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 16.dp, end = 16.dp, top = 4.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        items(categories, key = { it.title }) { category ->
            val shape = RoundedCornerShape(20.dp)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(shape)
                    .background(NoorColor.bgElevated, shape)
                    .clickable { onOpen(category) }
                    .padding(horizontal = 18.dp, vertical = 20.dp)
            ) {
                Text(
                    category.displayTitle(),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NoorColor.inkPrimary,
                    modifier = Modifier.weight(1f))
                Icon(
                    painterResource(NoorIcons.chevronForward()),
                    contentDescription = null,
                    tint = NoorColor.accentPrimary,
                    modifier = Modifier.size(18.dp))
            }
        }
    }
}

/// Two big tabs — nothing else. 64dp targets, well past the 48dp minimum.
@Composable
private fun KidsTabBar(tab: String, onTab: (String) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        KidsTabButton(
            label = stringResource(R.string.kids_tab_read),
            icon = R.drawable.ic_book,
            selected = tab == "read",
            modifier = Modifier.weight(1f)) { onTab("read") }
        KidsTabButton(
            label = stringResource(R.string.kids_tab_athkar),
            icon = R.drawable.ic_sparkle,
            selected = tab == "athkar",
            modifier = Modifier.weight(1f)) { onTab("athkar") }
    }
}

@Composable
private fun KidsTabButton(
    label: String,
    icon: Int,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        modifier = modifier
            .clip(shape)
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgElevated, shape)
            .clickable(onClick = onClick)
            .padding(vertical = 18.dp)
    ) {
        Icon(
            painterResource(icon),
            contentDescription = null,
            tint = if (selected) NoorColor.bgPrimary else NoorColor.inkSecondary,
            modifier = Modifier.size(22.dp))
        Text(
            label,
            fontSize = 17.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary)
    }
}
