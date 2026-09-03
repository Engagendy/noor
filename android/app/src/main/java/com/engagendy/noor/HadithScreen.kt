package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// One page of the detail pager, whatever the hadith's source.
private data class HadithPage(val arabic: String, val reference: String)

/// What the detail screen shows: the tapped hadith plus its neighbours,
/// swipeable like iOS's TabView page style (HadithDetailView.swift).
private data class HadithDetail(val pages: List<HadithPage>, val initialIndex: Int) {
    constructor(arabic: String, reference: String) :
        this(listOf(HadithPage(arabic, reference)), 0)
}

/// Forty-collection title: Arabic from the bundled data, English forms
/// (as on iOS) in the en locale.
private fun fortyTitle(context: android.content.Context, key: String, arabic: String): String =
    if (isArabicLocale()) arabic
    else when (key) {
        "nawawi" -> context.getString(R.string.g2_forty_nawawi)
        "qudsi" -> context.getString(R.string.g2_forty_qudsi)
        else -> arabic
    }

@Composable
fun HadithScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current

    var forty by remember { mutableStateOf<List<BundledHadith>>(emptyList()) }
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<HadithSearchHit>>(emptyList()) }

    var openForty by remember { mutableStateOf<String?>(null) }
    var openSahih by remember { mutableStateOf<HadithCollection?>(null) }
    var openBook by remember { mutableStateOf<HadithBook?>(null) }
    var detail by remember { mutableStateOf<HadithDetail?>(null) }

    LaunchedEffect(Unit) {
        // Big files parse off the main thread. Pack states live in
        // HadithLibrary so an in-flight download survives leaving the tab.
        val loaded = withContext(Dispatchers.IO) {
            val items = HadithStore.load(context)
            val states = HadithCollection.entries.associateWith {
                if (HadithLibrary.isDownloaded(context, it)) PackState.READY
                else PackState.NOT_DOWNLOADED
            }
            items to states
        }
        forty = loaded.first
        // Disk is the truth except while a download is still running.
        loaded.second.forEach { (collection, state) ->
            if (HadithLibrary.packStates[collection] != PackState.DOWNLOADING) {
                HadithLibrary.packStates[collection] = state
            }
        }
    }
    LaunchedEffect(query) {
        delay(350)
        results = withContext(Dispatchers.IO) { HadithLibrary.search(context, query) }
    }

    // System back pops one level of the drill-down, mirroring each header's
    // back button: detail → book → collection books → collections root.
    androidx.activity.compose.BackHandler(
        enabled = detail != null || openBook != null || openSahih != null || openForty != null
    ) {
        when {
            detail != null -> detail = null
            openBook != null -> openBook = null
            openSahih != null -> openSahih = null
            else -> openForty = null
        }
    }

    val currentDetail = detail
    if (currentDetail != null) {
        HadithDetailScreen(currentDetail, onBack = { detail = null }, modifier = modifier)
        return
    }
    val sahih = openSahih
    val book = openBook
    if (sahih != null && book != null) {
        BookHadithsScreen(sahih, book, onBack = { openBook = null },
                          openDetail = { detail = it }, modifier = modifier)
        return
    }
    if (sahih != null) {
        SahihBooksScreen(sahih, onBack = { openSahih = null },
                         openBook = { openBook = it }, modifier = modifier)
        return
    }
    val fortyKey = openForty
    if (fortyKey != null) {
        val items = forty.filter { it.collection == fortyKey }.sortedBy { it.number }
        FortyListScreen(items, onBack = { openForty = null },
                        openDetail = { detail = it }, modifier = modifier)
        return
    }

    // nawawi before qudsi, like iOS.
    val fortyGroups = forty.groupBy { it.collection }
        .entries.sortedByDescending { it.key }

    LazyColumn(modifier.fillMaxSize()) {
        item {
            Text(stringResource(R.string.g2_hadith_title), fontSize = 28.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp))
        }
        item {
            HadithSearchField(query, onChange = { query = it })
        }
        if (query.isNotBlank()) {
            if (results.isEmpty()) {
                item {
                    Text(stringResource(R.string.g2_no_results_download), fontSize = 14.sp,
                         color = NoorColor.inkSecondary,
                         modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp))
                }
            }
            items(results) { hit ->
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clickable {
                            detail = HadithDetail(
                                hit.hadith.arabic,
                                "${hit.collection.localizedName} · ${hit.hadith.number} · ${hit.bookTitle}")
                        }
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                ) {
                    Text(hit.hadith.arabic, fontSize = 15.sp, maxLines = 2,
                         color = NoorColor.inkPrimary)
                    Text("${hit.collection.localizedName} · ${hit.bookTitle} · ${hit.hadith.number}",
                         fontSize = 12.sp, color = NoorColor.accentGold,
                         modifier = Modifier.padding(top = 3.dp))
                }
                HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            }
        } else {
            item { HadithSectionHeader(stringResource(R.string.g2_sahihain)) }
            items(HadithCollection.entries) { collection ->
                val state = HadithLibrary.packStates[collection] ?: PackState.NOT_DOWNLOADED
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 6.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                        .clickable(enabled = state == PackState.READY) { openSahih = collection }
                        .padding(horizontal = 18.dp, vertical = 16.dp)
                ) {
                    Column {
                        Text(collection.localizedName, fontSize = 16.sp,
                             fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                        if (state != PackState.READY) {
                            Text(stringResource(R.string.g2_size_mb, collection.sizeMb.localizedDigits()),
                                 fontSize = 12.sp,
                                 color = NoorColor.inkSecondary,
                                 modifier = Modifier.padding(top = 2.dp))
                        }
                    }
                    when (state) {
                        // Disclosure points LEFT in the forced-RTL app.
                        PackState.READY -> Icon(
                            painterResource(R.drawable.ic_chevron_left),
                            contentDescription = null,
                            tint = NoorColor.accentPrimary,
                            modifier = Modifier.size(16.dp))
                        PackState.DOWNLOADING -> CircularProgressIndicator(
                            color = NoorColor.accentPrimary, strokeWidth = 2.dp,
                            modifier = Modifier.size(22.dp))
                        PackState.NOT_DOWNLOADED, PackState.FAILED -> Text(
                            stringResource(
                                if (state == PackState.FAILED) R.string.g2_retry
                                else R.string.g2_download),
                            fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                            color = NoorColor.accentPrimary,
                            modifier = Modifier
                                .clickable { HadithLibrary.startDownload(context, collection) }
                                .padding(8.dp))
                    }
                }
            }
            item { HadithSectionHeader(stringResource(R.string.g2_forty_section)) }
            items(fortyGroups) { group ->
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { openForty = group.key }
                        .padding(horizontal = 20.dp, vertical = 14.dp)
                ) {
                    Column {
                        Text(fortyTitle(context, group.key, group.value[0].collectionArabic),
                             fontSize = 16.sp,
                             fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                        Text(stringResource(R.string.g2_hadith_count, group.value.size.localizedDigits()),
                             fontSize = 12.sp,
                             color = NoorColor.inkSecondary,
                             modifier = Modifier.padding(top = 2.dp))
                    }
                    // Disclosure points LEFT in the forced-RTL app.
                    Icon(painterResource(R.drawable.ic_chevron_left),
                         contentDescription = null,
                         tint = NoorColor.accentPrimary,
                         modifier = Modifier.size(16.dp))
                }
                HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            }
        }
    }
}

@Composable
private fun HadithSectionHeader(title: String) {
    Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
         color = NoorColor.accentPrimary,
         modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp))
}

@Composable
private fun HadithSearchField(query: String, onChange: (String) -> Unit,
                              placeholder: String = stringResource(R.string.g2_search_all_hadith)) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp)
            .background(NoorColor.bgElevated, RoundedCornerShape(12.dp))
            // 48dp tall so the clear button can carry a full touch target
            // without the field growing when a query is typed.
            .heightIn(min = 48.dp)
            .padding(horizontal = 14.dp, vertical = 2.dp)
    ) {
        BasicTextField(
            value = query,
            onValueChange = onChange,
            singleLine = true,
            textStyle = TextStyle(fontSize = 15.sp, color = NoorColor.inkPrimary),
            cursorBrush = SolidColor(NoorColor.accentPrimary),
            modifier = Modifier.fillMaxWidth(if (query.isEmpty()) 1f else 0.88f),
            decorationBox = { inner ->
                if (query.isEmpty()) {
                    Text(placeholder, fontSize = 15.sp, color = NoorColor.inkSecondary)
                }
                inner()
            }
        )
        if (query.isNotEmpty()) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .clickable { onChange("") }
            ) {
                Icon(painterResource(R.drawable.ic_close),
                     contentDescription = stringResource(R.string.g2_clear_search),
                     tint = NoorColor.inkSecondary, modifier = Modifier.size(15.dp))
            }
        }
    }
}

@Composable
private fun HadithHeaderBar(title: String, onBack: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Text(title, fontSize = 18.sp, fontWeight = FontWeight.Bold,
             color = NoorColor.inkPrimary, modifier = Modifier.fillMaxWidth(0.8f))
        Text(stringResource(R.string.g2_back), color = NoorColor.accentPrimary, fontWeight = FontWeight.SemiBold,
             modifier = Modifier.clickable(onClick = onBack).padding(8.dp))
    }
}

/// One Forty collection: numbered rows → detail.
@Composable
private fun FortyListScreen(items: List<BundledHadith>, onBack: () -> Unit,
                            openDetail: (HadithDetail) -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val title = items.firstOrNull()
        ?.let { fortyTitle(context, it.collection, it.collectionArabic) } ?: ""
    Column(modifier.fillMaxSize()) {
        HadithHeaderBar(title, onBack)
        LazyColumn(Modifier.fillMaxSize()) {
            items(items) { hadith ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            // Whole collection is swipeable from the tapped hadith, like iOS.
                            openDetail(HadithDetail(
                                pages = items.map {
                                    HadithPage(
                                        it.arabic,
                                        fortyTitle(context, it.collection, it.collectionArabic) +
                                            " · " + context.getString(
                                                R.string.g2_hadith_n, it.number.localizedDigits()))
                                },
                                initialIndex = items.indexOf(hadith).coerceAtLeast(0)))
                        }
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                ) {
                    Text(hadith.number.localizedDigits(), fontSize = 13.sp,
                         fontWeight = FontWeight.SemiBold, color = NoorColor.accentGold,
                         modifier = Modifier.padding(end = 12.dp))
                    Text(hadith.arabic, fontSize = 15.sp, maxLines = 2,
                         color = NoorColor.inkPrimary)
                }
                HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            }
        }
    }
}

/// The books (كتب) of one Sahih, searchable by title.
@Composable
private fun SahihBooksScreen(collection: HadithCollection, onBack: () -> Unit,
                             openBook: (HadithBook) -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var books by remember { mutableStateOf<List<HadithBook>>(emptyList()) }
    var query by remember { mutableStateOf("") }
    LaunchedEffect(collection) {
        books = withContext(Dispatchers.IO) { HadithLibrary.books(context, collection) }
    }
    val filtered = if (query.isBlank()) books
        else books.filter { it.arabicTitle.contains(query.trim()) }

    Column(modifier.fillMaxSize()) {
        HadithHeaderBar(collection.localizedName, onBack)
        HadithSearchField(query, onChange = { query = it }, placeholder = stringResource(R.string.g2_search_books))
        LazyColumn(Modifier.fillMaxSize()) {
            items(filtered) { book ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { openBook(book) }
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                ) {
                    Text(book.index.localizedDigits(), fontSize = 13.sp,
                         fontWeight = FontWeight.Bold, color = NoorColor.accentGold,
                         modifier = Modifier.padding(end = 12.dp))
                    Column {
                        Text(book.arabicTitle, fontSize = 15.sp,
                             fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                        Text(stringResource(R.string.g2_hadith_count, book.count.localizedDigits()),
                             fontSize = 12.sp,
                             color = NoorColor.inkSecondary)
                    }
                }
                HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            }
        }
    }
}

/// The hadiths of one book, searchable within.
@Composable
private fun BookHadithsScreen(collection: HadithCollection, book: HadithBook, onBack: () -> Unit,
                              openDetail: (HadithDetail) -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var hadithList by remember { mutableStateOf<List<LibraryHadith>>(emptyList()) }
    var query by remember { mutableStateOf("") }
    LaunchedEffect(collection, book.index) {
        hadithList = withContext(Dispatchers.IO) {
            HadithLibrary.hadiths(context, collection, book.index)
        }
    }
    val trimmed = query.trim()
    val filtered = if (trimmed.isEmpty()) hadithList
        else hadithList.filter { it.arabic.contains(trimmed) || it.number == trimmed }

    Column(modifier.fillMaxSize()) {
        HadithHeaderBar(book.arabicTitle, onBack)
        HadithSearchField(query, onChange = { query = it }, placeholder = stringResource(R.string.g2_search_hadiths))
        LazyColumn(Modifier.fillMaxSize()) {
            items(filtered) { hadith ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            // iOS pages over the full book list even when tapped
                            // from a filtered search within the book.
                            openDetail(HadithDetail(
                                pages = hadithList.map {
                                    HadithPage(
                                        it.arabic,
                                        "${collection.localizedName} · ${it.number} · ${book.arabicTitle}")
                                },
                                initialIndex = hadithList.indexOf(hadith).coerceAtLeast(0)))
                        }
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                ) {
                    Text(hadith.number, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.accentGold,
                         modifier = Modifier.padding(end = 12.dp))
                    Text(hadith.arabic, fontSize = 15.sp, maxLines = 3,
                         color = NoorColor.inkPrimary)
                }
                HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            }
        }
    }
}

/// Full hadith text + gold reference + share-as-image.
/// Swiping pages to the previous/next hadith in the same list, like iOS's
/// TabView(.page) in HadithDetailView.swift / LibraryHadithDetail. Under the
/// app's forced RTL the pager already advances in reading direction.
@Composable
private fun HadithDetailScreen(detail: HadithDetail, onBack: () -> Unit,
                               modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val pagerState = rememberPagerState(initialPage = detail.initialIndex) { detail.pages.size }
    Column(modifier.fillMaxSize()) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text(stringResource(R.string.g2_share), color = NoorColor.accentPrimary, fontWeight = FontWeight.SemiBold,
                 modifier = Modifier
                     .clickable {
                         // Share the page currently in view, not the tapped one.
                         val page = detail.pages[pagerState.currentPage]
                         scope.launch {
                             val bitmap = withContext(Dispatchers.IO) {
                                 ShareCard.render(context, page.arabic, page.reference)
                             }
                             ShareCard.share(context, bitmap, text = page.reference)
                         }
                     }
                     .padding(8.dp))
            Text(stringResource(R.string.g2_back), color = NoorColor.accentPrimary, fontWeight = FontWeight.SemiBold,
                 modifier = Modifier.clickable(onClick = onBack).padding(8.dp))
        }
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { i ->
            val page = detail.pages[i]
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
            ) {
                Text(page.arabic, fontSize = 18.sp, lineHeight = 34.sp,
                     color = NoorColor.inkPrimary)
                Text(page.reference, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.accentGold,
                     modifier = Modifier.padding(top = 16.dp, bottom = 24.dp))
            }
        }
    }
}
