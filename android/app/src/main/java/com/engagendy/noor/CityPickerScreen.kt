package com.engagendy.noor

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.util.Locale

/// Full-screen offline city picker over the bundled GeoNames table — the
/// Android counterpart of the iOS CityPickerView. Search on top; with an
/// empty query: Nearby (last device fix), Popular (the curated presets)
/// and Browse by country → country → cities. Selection is reported to the
/// caller, which writes prefs inside its click handler.
@Composable
fun CityPickerScreen(
    selectedCityId: Int,
    onPick: (City) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxSize().background(NoorColor.bgPrimary)) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)
        ) {
            Text(stringResource(R.string.feat_choose_city), fontSize = 22.sp,
                 fontWeight = FontWeight.Bold, color = NoorColor.inkPrimary)
            Icon(painterResource(R.drawable.ic_close),
                 contentDescription = stringResource(R.string.feat_close),
                 tint = NoorColor.accentPrimary,
                 modifier = Modifier
                     .size(44.dp)
                     .clip(CircleShape)
                     .clickable(onClick = onClose)
                     .padding(12.dp))
        }
        CityPickerContent(
            selectedCityId = selectedCityId,
            onPick = onPick,
            onBackAtRoot = onClose,
            autoFocus = true,
            modifier = Modifier.weight(1f))
    }
}

private sealed interface PickerLevel {
    data object Root : PickerLevel
    data object Countries : PickerLevel
    data class InCountry(val country: Country) : PickerLevel
}

/// The picker body without a title bar — embedded by the onboarding city
/// step and wrapped by CityPickerScreen in Prayer Settings.
@Composable
fun CityPickerContent(
    selectedCityId: Int,
    onPick: (City) -> Unit,
    onBackAtRoot: (() -> Unit)? = null,
    autoFocus: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    // Both from one source: on API <33 the AppCompat per-app locale can leave
    // resources and Locale.getDefault() disagreeing.
    val locale = androidx.compose.ui.platform.LocalConfiguration.current.locales[0]
    val arabicUi = locale.language == "ar"
    var query by rememberSaveable { mutableStateOf("") }
    var level by remember { mutableStateOf<PickerLevel>(PickerLevel.Root) }
    val keyboard = LocalSoftwareKeyboardController.current
    val focusRequester = remember { FocusRequester() }

    // System back walks the country drill-down up before leaving.
    BackHandler(enabled = level != PickerLevel.Root || onBackAtRoot != null) {
        when (level) {
            is PickerLevel.InCountry -> level = PickerLevel.Countries
            PickerLevel.Countries -> level = PickerLevel.Root
            PickerLevel.Root -> onBackAtRoot?.invoke()
        }
    }

    if (autoFocus) {
        LaunchedEffect(Unit) { focusRequester.requestFocus() }
    }

    // Root sections, loaded once off-main.
    var nearby by remember { mutableStateOf<List<City>>(emptyList()) }
    var popular by remember { mutableStateOf<List<City>>(emptyList()) }
    LaunchedEffect(Unit) {
        val prefs = PrayerPrefs(context)
        val fix = if (prefs.hasCustomFix) prefs.customLat to prefs.customLon else null
        val loaded = withContext(Dispatchers.IO) {
            val db = CityDb.get(context)
            val near = fix?.let { (lat, lon) -> db.nearest(lat, lon, 5) } ?: emptyList()
            val pop = db.popular()
            near to pop
        }
        nearby = loaded.first
        popular = loaded.second
    }

    // Search results, debounced a touch so fast typing does not queue queries.
    var results by remember { mutableStateOf<List<City>>(emptyList()) }
    LaunchedEffect(query) {
        val q = query.trim()
        if (q.isEmpty()) { results = emptyList(); return@LaunchedEffect }
        delay(120)
        results = withContext(Dispatchers.IO) { CityDb.get(context).search(q) }
    }

    var countries by remember { mutableStateOf<List<Country>>(emptyList()) }
    LaunchedEffect(level == PickerLevel.Countries) {
        if (level == PickerLevel.Countries && countries.isEmpty()) {
            countries = withContext(Dispatchers.IO) { CityDb.get(context).countries(locale) }
        }
    }
    var countryCities by remember { mutableStateOf<List<City>>(emptyList()) }
    val inCountry = (level as? PickerLevel.InCountry)?.country
    LaunchedEffect(inCountry) {
        countryCities = if (inCountry == null) emptyList()
            else withContext(Dispatchers.IO) { CityDb.get(context).citiesIn(inCountry.code) }
    }

    Column(modifier.fillMaxSize()) {
        TextField(
            value = query,
            // Typing never throws the user out of where they are: inside a
            // country it filters that country, in the country list it filters
            // countries, at the root it searches everywhere.
            onValueChange = { query = it },
            placeholder = {
                Text(stringResource(R.string.g1_search_city),
                     color = NoorColor.inkSecondary.copy(alpha = 0.7f))
            },
            trailingIcon = if (query.isNotEmpty()) {
                {
                    Icon(painterResource(R.drawable.ic_close),
                         contentDescription = stringResource(R.string.feat_clear_search),
                         tint = NoorColor.inkSecondary,
                         modifier = Modifier
                             .size(44.dp)
                             .clip(CircleShape)
                             .clickable { query = "" }
                             .padding(13.dp))
                }
            } else null,
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { keyboard?.hide() }),
            shape = RoundedCornerShape(12.dp),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = NoorColor.bgElevated,
                unfocusedContainerColor = NoorColor.bgElevated,
                focusedTextColor = NoorColor.inkPrimary,
                unfocusedTextColor = NoorColor.inkPrimary,
                cursorColor = NoorColor.accentPrimary,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .focusRequester(focusRequester))

        val searching = query.isNotBlank()
        val q = query.trim()
        val qNorm = CityDb.normalize(q)
        val qArabic = q.any { it in '\u0600'..'\u06FF' }
        fun matches(c: City) = if (qArabic) c.nameArabic?.contains(q) == true
            else CityDb.normalize(c.name).contains(qNorm)
        LazyColumn(Modifier.fillMaxSize().padding(top = 8.dp)) {
            when {
                level is PickerLevel.InCountry -> {
                    val country = (level as PickerLevel.InCountry).country
                    item { PickerHeader(country.name, onBack = { level = PickerLevel.Countries }) }
                    val shown = if (searching) countryCities.filter(::matches) else countryCities
                    if (searching && shown.isEmpty()) {
                        item {
                            Text(stringResource(R.string.feat_no_results), fontSize = 14.sp,
                                 color = NoorColor.inkSecondary,
                                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp))
                        }
                    }
                    cityRows(shown, selectedCityId, arabicUi, locale, onPick, showCountry = false)
                }
                level == PickerLevel.Countries -> {
                    item { PickerHeader(stringResource(R.string.feat_countries),
                                        onBack = { level = PickerLevel.Root }) }
                    val shown = if (searching) countries.filter {
                        CityDb.normalize(it.name).contains(qNorm) || it.name.contains(q)
                    } else countries
                    items(shown, key = { it.code }) { country ->
                        NavPickerRow(country.name) { level = PickerLevel.InCountry(country) }
                    }
                }
                searching -> {
                    if (results.isEmpty()) {
                        item {
                            Text(stringResource(R.string.feat_no_results), fontSize = 14.sp,
                                 color = NoorColor.inkSecondary,
                                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp))
                        }
                    }
                    cityRows(results, selectedCityId, arabicUi, locale, onPick)
                }
                else -> {
                    if (nearby.isNotEmpty()) {
                        item { PickerSection(stringResource(R.string.feat_nearby)) }
                        cityRows(nearby, selectedCityId, arabicUi, locale, onPick)
                    }
                    item { PickerSection(stringResource(R.string.feat_popular)) }
                    cityRows(popular, selectedCityId, arabicUi, locale, onPick)
                    item {
                        Spacer(Modifier.padding(top = 6.dp))
                        NavPickerRow(stringResource(R.string.feat_browse_by_country)) {
                            level = PickerLevel.Countries
                        }
                        Spacer(Modifier.padding(bottom = 24.dp))
                    }
                }
            }
        }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.cityRows(
    cities: List<City>,
    selectedCityId: Int,
    arabicUi: Boolean,
    locale: Locale,
    onPick: (City) -> Unit,
    showCountry: Boolean = true,
) {
    // Same primary name twice in one list (Springfield…) → show the region.
    val duplicated = cities.groupingBy { it.displayName(arabicUi) }.eachCount()
        .filterValues { it > 1 }.keys
    items(cities, key = { it.id }) { city ->
        val primary = city.displayName(arabicUi)
        val secondary = buildList {
            city.secondaryName(arabicUi)?.let { add(it) }
            if (showCountry) add(city.countryName(locale))
            if (primary in duplicated) city.admin1?.let { add(it) }
        }.joinToString(" · ")
        CityRow(
            primary = primary,
            secondary = secondary.takeIf { it.isNotBlank() },
            selected = city.id == selectedCityId,
            onClick = { onPick(city) })
    }
}

@Composable
private fun CityRow(primary: String, secondary: String?, selected: Boolean, onClick: () -> Unit) {
    val selectedLabel = stringResource(R.string.feat_selected)
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 2.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (selected) NoorColor.stateReciting else NoorColor.bgElevated,
                RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .heightIn(min = 48.dp)
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .semantics {
                if (selected) contentDescription = "$primary, $selectedLabel"
            }
    ) {
        Column(Modifier.weight(1f)) {
            Text(primary, fontSize = 15.sp,
                 fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                 color = if (selected) NoorColor.accentPrimary else NoorColor.inkPrimary)
            if (secondary != null) {
                Text(secondary, fontSize = 12.sp, color = NoorColor.inkSecondary)
            }
        }
        if (selected) {
            Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                 tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun NavPickerRow(title: String, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 2.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(NoorColor.bgElevated, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .heightIn(min = 48.dp)
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Text(title, fontSize = 15.sp, color = NoorColor.inkPrimary)
        // Disclosure points forward: LEFT in RTL, RIGHT in LTR.
        Icon(painterResource(NoorIcons.chevronForward()), contentDescription = null,
             tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun PickerSection(title: String) {
    Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
         color = NoorColor.inkSecondary,
         modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 6.dp))
}

/// Drill-down header with a back arrow (points backward per direction).
@Composable
private fun PickerHeader(title: String, onBack: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp)
    ) {
        Icon(painterResource(NoorIcons.back()),
             contentDescription = stringResource(R.string.g2_back),
             tint = NoorColor.accentPrimary,
             modifier = Modifier
                 .size(44.dp)
                 .clip(CircleShape)
                 .clickable(onClick = onBack)
                 .padding(12.dp))
        Spacer(Modifier.width(4.dp))
        Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
             color = NoorColor.inkPrimary)
    }
}
