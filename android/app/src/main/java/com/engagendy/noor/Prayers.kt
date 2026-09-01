package com.engagendy.noor

import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

data class CityPreset(
    val name: String,
    val nameArabic: String,
    val latitude: Double,
    val longitude: Double,
    val timeZone: String,
)

/// A starter subset of the iOS city list (full port in a later phase).
object Cities {
    val all = listOf(
        CityPreset("Makkah", "مكة المكرمة", 21.4225, 39.8262, "Asia/Riyadh"),
        CityPreset("Madinah", "المدينة المنورة", 24.4672, 39.6111, "Asia/Riyadh"),
        CityPreset("Riyadh", "الرياض", 24.7136, 46.6753, "Asia/Riyadh"),
        CityPreset("Jeddah", "جدة", 21.5433, 39.1728, "Asia/Riyadh"),
        CityPreset("Sharjah", "الشارقة", 25.3463, 55.4209, "Asia/Dubai"),
        CityPreset("Dubai", "دبي", 25.2048, 55.2708, "Asia/Dubai"),
        CityPreset("Abu Dhabi", "أبوظبي", 24.4539, 54.3773, "Asia/Dubai"),
        CityPreset("Cairo", "القاهرة", 30.0444, 31.2357, "Africa/Cairo"),
        CityPreset("Alexandria", "الإسكندرية", 31.2001, 29.9187, "Africa/Cairo"),
        CityPreset("Amman", "عمّان", 31.9539, 35.9106, "Asia/Amman"),
        CityPreset("Doha", "الدوحة", 25.2854, 51.5310, "Asia/Qatar"),
        CityPreset("Kuwait City", "مدينة الكويت", 29.3759, 47.9774, "Asia/Kuwait"),
        CityPreset("Istanbul", "إسطنبول", 41.0082, 28.9784, "Europe/Istanbul"),
        CityPreset("London", "لندن", 51.5074, -0.1278, "Europe/London"),
    )

    fun named(name: String): CityPreset = all.firstOrNull { it.name == name } ?: all[0]
}

data class PrayerEntry(val nameArabic: String, val nameEnglish: String, val time: Date)

object PrayerEngine {
    fun today(city: CityPreset, date: Date = Date()): List<PrayerEntry> {
        val zone = TimeZone.getTimeZone(city.timeZone)
        val calendar = Calendar.getInstance(zone).apply { time = date }
        val components = DateComponents(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH))
        val params = CalculationMethod.MOON_SIGHTING_COMMITTEE.parameters.apply {
            madhab = Madhab.SHAFI
        }
        val times = PrayerTimes(Coordinates(city.latitude, city.longitude), components, params)
        return listOf(
            PrayerEntry("الفجر", "Fajr", times.fajr),
            PrayerEntry("الظهر", "Dhuhr", times.dhuhr),
            PrayerEntry("العصر", "Asr", times.asr),
            PrayerEntry("المغرب", "Maghrib", times.maghrib),
            PrayerEntry("العشاء", "Isha", times.isha),
        )
    }

    fun next(entries: List<PrayerEntry>, now: Date = Date()): PrayerEntry? =
        entries.firstOrNull { it.time.after(now) }
}
