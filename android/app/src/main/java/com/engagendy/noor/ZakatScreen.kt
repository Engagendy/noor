package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale

/// Offline zakat calculator — 1:1 with iOS App/ZakatView.swift. Nothing
/// leaves the device; the gold price is entered by hand (offline-first —
/// no market API). Nisab = value of 85g of gold.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ZakatScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val prefs = remember { KhatmahPlan.prefs(context) }
    var goldPrice by remember {
        mutableStateOf(prefs.getFloat("zakat.goldPrice", 0f)
            .takeIf { it > 0f }?.toString().orEmpty())
    }
    var cash by remember { mutableStateOf("") }
    var goldGrams by remember { mutableStateOf("") }
    var silverGrams by remember { mutableStateOf("") }
    var investments by remember { mutableStateOf("") }
    var businessGoods by remember { mutableStateOf("") }
    var moneyOwed by remember { mutableStateOf("") }
    var debtsDue by remember { mutableStateOf("") }

    fun value(text: String): Double =
        text.replace("،", ".").replace(",", ".")
            .map { c -> if (c in '٠'..'٩') '0' + (c - '٠') else c }
            .joinToString("")
            .toDoubleOrNull() ?: 0.0

    val gold = value(goldPrice)
    val nisab = 85 * gold
    val totalAssets = value(cash) + value(goldGrams) * gold +
        value(silverGrams) * (gold / 90) +  // rough silver ≈ gold/90 if unknown
        value(investments) + value(businessGoods) + value(moneyOwed)
    val zakatBase = (totalAssets - value(debtsDue)).coerceAtLeast(0.0)
    val isDue = gold > 0 && zakatBase >= nisab
    val zakatAmount = zakatBase * 0.025

    fun format(amount: Double): String = String.format(Locale("ar"), "%,.2f", amount)

    @Composable
    fun moneyField(title: String, text: String, onChange: (String) -> Unit) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
        ) {
            Text(title, fontSize = 15.sp, color = NoorColor.inkPrimary,
                 modifier = Modifier.weight(1f))
            OutlinedTextField(
                value = text,
                onValueChange = onChange,
                placeholder = { Text("٠", color = NoorColor.inkSecondary) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = NoorColor.accentPrimary,
                    unfocusedBorderColor = NoorColor.inkPrimary.copy(alpha = 0.15f),
                ),
                modifier = Modifier.width(130.dp)
            )
        }
    }

    Column(modifier.fillMaxSize()) {
        ExtraHeader("حاسبة الزكاة", onBack)
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
        ) {
            Text("عملتك المحلية", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentPrimary)
            moneyField("سعر جرام الذهب اليوم", goldPrice) {
                goldPrice = it
                // User-typed value — persisted from the input handler.
                prefs.edit().putFloat("zakat.goldPrice", value(it).toFloat()).apply()
            }
            Text(
                "أدخل سعر الذهب المحلي اليوم — النصاب هو قيمة ٨٥ جرامًا من الذهب.",
                fontSize = 12.sp, color = NoorColor.inkSecondary,
                modifier = Modifier.padding(bottom = 14.dp)
            )

            Text("الأموال الزكوية", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentPrimary)
            moneyField("النقد (في اليد والبنك)", cash) { cash = it }
            moneyField("الذهب (جرامات)", goldGrams) { goldGrams = it }
            moneyField("الفضة (جرامات)", silverGrams) { silverGrams = it }
            moneyField("استثمارات / أسهم", investments) { investments = it }
            moneyField("عروض التجارة", businessGoods) { businessGoods = it }
            moneyField("ديون لك عند الغير", moneyOwed) { moneyOwed = it }
            moneyField("ديون حالّة عليك (تُخصم)", debtsDue) { debtsDue = it }

            // Result card.
            Column(
                Modifier
                    .padding(vertical = 16.dp)
                    .fillMaxWidth()
                    .background(NoorColor.bgElevated, RoundedCornerShape(16.dp))
                    .padding(16.dp)
            ) {
                if (gold <= 0) {
                    Text("أدخل سعر الذهب لحساب النصاب.", fontSize = 14.sp,
                         color = NoorColor.inkSecondary)
                } else {
                    Row(horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()) {
                        Text("النصاب", fontSize = 15.sp, color = NoorColor.inkPrimary)
                        Text(format(nisab), fontSize = 15.sp, color = NoorColor.inkSecondary)
                    }
                    Row(horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth().padding(top = 6.dp)) {
                        Text("صافي الثروة", fontSize = 15.sp, color = NoorColor.inkPrimary)
                        Text(format(zakatBase), fontSize = 15.sp, color = NoorColor.inkSecondary)
                    }
                    if (isDue) {
                        Row(horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth().padding(top = 10.dp)) {
                            Text("الزكاة المستحقة (٢٫٥٪)", fontSize = 16.sp,
                                 fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                            Text(format(zakatAmount), fontSize = 17.sp,
                                 fontWeight = FontWeight.Bold, color = NoorColor.accentPrimary)
                        }
                    } else {
                        Text("دون النصاب — لا زكاة مستحقة.", fontSize = 14.sp,
                             color = NoorColor.inkSecondary,
                             modifier = Modifier.padding(top = 10.dp))
                    }
                }
            }
            Text(
                "تجب الزكاة إذا بلغ صافي المال النصاب وحال عليه الحول الهجري. هذه الحاسبة استئناس — استشر أهل العلم في الحالات المركّبة. جميع الأرقام تبقى على جهازك.",
                fontSize = 12.sp, color = NoorColor.inkSecondary,
                modifier = Modifier.padding(bottom = 32.dp)
            )
        }
    }
}
