package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class PackState { NOT_DOWNLOADED, DOWNLOADING, READY, FAILED }

/// What the detail screen shows, whatever the hadith's source.
private data class HadithDetail(val arabic: String, val reference: String)

@Composable
fun HadithScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var forty by remember { mutableStateOf<List<BundledHadith>>(emptyList()) }
    val packStates = remember { mutableStateMapOf<HadithCollection, PackState>() }
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<HadithSearchHit>>(emptyList()) }

    var openForty by remember { mutableStateOf<String?>(null) }
    var openSahih by remember { mutableStateOf<HadithCollection?>(null) }
    var openBook by remember { mutableStateOf<HadithBook?>(null) }
    var detail by remember { mutableStateOf<HadithDetail?>(null) }

    LaunchedEffect(Unit) {
        // Big files parse off the main thread.
        val loaded = withContext(Dispatchers.IO) {
            val items = HadithStore.load(context)
            val states = HadithCollection.entries.associateWith {
                if (HadithLibrary.isDownloaded(context, it)) PackState.READY
                else PackState.NOT_DOWNLOADED
            }
            items to states
        }
        forty = loaded.first
        loaded.second.forEach { (collection, state) ->
            if (packStates[collection] != PackState.DOWNLOADING) packStates[collection] = state
        }
    }
    LaunchedEffect(query) {
        delay(350)
        results = withContext(Dispatchers.IO) { HadithLibrary.search(context, query) }
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
            Text("الحديث", fontSize = 28.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp))
        }
        item {
            HadithSearchField(query, onChange = { query = it })
        }
        if (query.isNotBlank()) {
            if (results.isEmpty()) {
                item {
                    Text("لا نتائج — نزّل الصحيحين للبحث فيهما", fontSize = 14.sp,
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
                                "${hit.collection.nameArabic} · ${hit.hadith.number} · ${hit.bookTitle}")
                        }
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                ) {
                    Text(hit.hadith.arabic, fontSize = 15.sp, maxLines = 2,
                         color = NoorColor.inkPrimary)
                    Text("${hit.collection.nameArabic} · ${hit.bookTitle} · ${hit.hadith.number}",
                         fontSize = 12.sp, color = NoorColor.accentGold,
                         modifier = Modifier.padding(top = 3.dp))
                }
                HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            }
        } else {
            item { HadithSectionHeader("الصحيحان") }
            items(HadithCollection.entries) { collection ->
                val state = packStates[collection] ?: PackState.NOT_DOWNLOADED
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 6.dp)
                        .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                        .clickable(enabled = state == PackState.READY) { openSahih = collection }
                        .padding(horizontal = 18.dp, vertical = 16.dp)
                ) {
                    Column {
                        Text(collection.nameArabic, fontSize = 16.sp,
                             fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                        if (state != PackState.READY) {
                            Text(collection.sizeLabel, fontSize = 12.sp,
                                 color = NoorColor.inkSecondary,
                                 modifier = Modifier.padding(top = 2.dp))
                        }
                    }
                    when (state) {
                        PackState.READY -> Text("←", color = NoorColor.accentPrimary)
                        PackState.DOWNLOADING -> CircularProgressIndicator(
                            color = NoorColor.accentPrimary, strokeWidth = 2.dp,
                            modifier = Modifier.size(22.dp))
                        PackState.NOT_DOWNLOADED, PackState.FAILED -> Text(
                            if (state == PackState.FAILED) "إعادة المحاولة" else "تنزيل",
                            fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                            color = NoorColor.accentPrimary,
                            modifier = Modifier
                                .clickable {
                                    packStates[collection] = PackState.DOWNLOADING
                                    scope.launch {
                                        val ok = withContext(Dispatchers.IO) {
                                            HadithLibrary.download(context, collection)
                                        }
                                        packStates[collection] =
                                            if (ok) PackState.READY else PackState.FAILED
                                    }
                                }
                                .padding(8.dp))
                    }
                }
            }
            item { HadithSectionHeader("الأربعينات") }
            items(fortyGroups) { group ->
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { openForty = group.key }
                        .padding(horizontal = 20.dp, vertical = 14.dp)
                ) {
                    Column {
                        Text(group.value[0].collectionArabic, fontSize = 16.sp,
                             fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                        Text("${group.value.size.arabicIndic()} حديثًا", fontSize = 12.sp,
                             color = NoorColor.inkSecondary,
                             modifier = Modifier.padding(top = 2.dp))
                    }
                    Text("←", color = NoorColor.accentPrimary)
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
                              placeholder: String = "ابحث في كل الأحاديث") {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp)
            .background(NoorColor.bgElevated, RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp)
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
            Text("✕", color = NoorColor.inkSecondary,
                 modifier = Modifier.clickable { onChange("") }.padding(4.dp))
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
        Text("رجوع", color = NoorColor.accentPrimary, fontWeight = FontWeight.SemiBold,
             modifier = Modifier.clickable(onClick = onBack).padding(8.dp))
    }
}

/// One Forty collection: numbered rows → detail.
@Composable
private fun FortyListScreen(items: List<BundledHadith>, onBack: () -> Unit,
                            openDetail: (HadithDetail) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxSize()) {
        HadithHeaderBar(items.firstOrNull()?.collectionArabic ?: "", onBack)
        LazyColumn(Modifier.fillMaxSize()) {
            items(items) { hadith ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            openDetail(HadithDetail(
                                hadith.arabic,
                                "${hadith.collectionArabic} · الحديث ${hadith.number.arabicIndic()}"))
                        }
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                ) {
                    Text(hadith.number.arabicIndic(), fontSize = 13.sp,
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
        HadithHeaderBar(collection.nameArabic, onBack)
        HadithSearchField(query, onChange = { query = it }, placeholder = "ابحث في الكتب")
        LazyColumn(Modifier.fillMaxSize()) {
            items(filtered) { book ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { openBook(book) }
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                ) {
                    Text(book.index.arabicIndic(), fontSize = 13.sp,
                         fontWeight = FontWeight.Bold, color = NoorColor.accentGold,
                         modifier = Modifier.padding(end = 12.dp))
                    Column {
                        Text(book.arabicTitle, fontSize = 15.sp,
                             fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                        Text("${book.count.arabicIndic()} حديثًا", fontSize = 12.sp,
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
        HadithSearchField(query, onChange = { query = it }, placeholder = "ابحث في الأحاديث")
        LazyColumn(Modifier.fillMaxSize()) {
            items(filtered) { hadith ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            openDetail(HadithDetail(
                                hadith.arabic,
                                "${collection.nameArabic} · ${hadith.number} · ${book.arabicTitle}"))
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
@Composable
private fun HadithDetailScreen(detail: HadithDetail, onBack: () -> Unit,
                               modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    Column(modifier.fillMaxSize()) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text("مشاركة", color = NoorColor.accentPrimary, fontWeight = FontWeight.SemiBold,
                 modifier = Modifier
                     .clickable {
                         scope.launch {
                             val bitmap = withContext(Dispatchers.IO) {
                                 ShareCard.render(context, detail.arabic, detail.reference)
                             }
                             ShareCard.share(context, bitmap, text = detail.reference)
                         }
                     }
                     .padding(8.dp))
            Text("رجوع", color = NoorColor.accentPrimary, fontWeight = FontWeight.SemiBold,
                 modifier = Modifier.clickable(onClick = onBack).padding(8.dp))
        }
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
        ) {
            Text(detail.arabic, fontSize = 18.sp, lineHeight = 34.sp,
                 color = NoorColor.inkPrimary)
            Text(detail.reference, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentGold,
                 modifier = Modifier.padding(top = 16.dp, bottom = 24.dp))
        }
    }
}
