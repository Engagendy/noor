package com.engagendy.noor

import android.content.Context
import android.content.SharedPreferences
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

/// Full city list — 1:1 with the iOS `CityPreset.all` in PrayerSettings.swift.
object Cities {
    val all = listOf(
        // Arabia & Gulf
        CityPreset("Makkah", "مكة المكرمة", 21.4225, 39.8262, "Asia/Riyadh"),
        CityPreset("Madinah", "المدينة المنورة", 24.4672, 39.6111, "Asia/Riyadh"),
        CityPreset("Riyadh", "الرياض", 24.7136, 46.6753, "Asia/Riyadh"),
        CityPreset("Jeddah", "جدة", 21.4858, 39.1925, "Asia/Riyadh"),
        CityPreset("Dammam", "الدمام", 26.4207, 50.0888, "Asia/Riyadh"),
        CityPreset("Dubai", "دبي", 25.2048, 55.2708, "Asia/Dubai"),
        CityPreset("Abu Dhabi", "أبوظبي", 24.4539, 54.3773, "Asia/Dubai"),
        CityPreset("Sharjah", "الشارقة", 25.3463, 55.4209, "Asia/Dubai"),
        CityPreset("Doha", "الدوحة", 25.2854, 51.5310, "Asia/Qatar"),
        CityPreset("Kuwait City", "مدينة الكويت", 29.3759, 47.9774, "Asia/Kuwait"),
        CityPreset("Manama", "المنامة", 26.2285, 50.5860, "Asia/Bahrain"),
        CityPreset("Muscat", "مسقط", 23.5880, 58.3829, "Asia/Muscat"),
        CityPreset("Sana'a", "صنعاء", 15.3694, 44.1910, "Asia/Aden"),
        // Levant & Iraq
        CityPreset("Amman", "عمّان", 31.9454, 35.9284, "Asia/Amman"),
        CityPreset("Jerusalem", "القدس", 31.7683, 35.2137, "Asia/Jerusalem"),
        CityPreset("Beirut", "بيروت", 33.8938, 35.5018, "Asia/Beirut"),
        CityPreset("Damascus", "دمشق", 33.5138, 36.2765, "Asia/Damascus"),
        CityPreset("Baghdad", "بغداد", 33.3152, 44.3661, "Asia/Baghdad"),
        // Africa
        CityPreset("Cairo", "القاهرة", 30.0444, 31.2357, "Africa/Cairo"),
        CityPreset("Alexandria", "الإسكندرية", 31.2001, 29.9187, "Africa/Cairo"),
        CityPreset("Khartoum", "الخرطوم", 15.5007, 32.5599, "Africa/Khartoum"),
        CityPreset("Tripoli", "طرابلس", 32.8872, 13.1913, "Africa/Tripoli"),
        CityPreset("Tunis", "تونس", 36.8065, 10.1815, "Africa/Tunis"),
        CityPreset("Algiers", "الجزائر", 36.7538, 3.0588, "Africa/Algiers"),
        CityPreset("Casablanca", "الدار البيضاء", 33.5731, -7.5898, "Africa/Casablanca"),
        CityPreset("Rabat", "الرباط", 34.0209, -6.8416, "Africa/Casablanca"),
        CityPreset("Lagos", "لاغوس", 6.5244, 3.3792, "Africa/Lagos"),
        CityPreset("Nairobi", "نيروبي", -1.2921, 36.8219, "Africa/Nairobi"),
        CityPreset("Mogadishu", "مقديشو", 2.0469, 45.3182, "Africa/Mogadishu"),
        CityPreset("Johannesburg", "جوهانسبرغ", -26.2041, 28.0473, "Africa/Johannesburg"),
        // Türkiye, Iran & Central/South Asia
        CityPreset("Istanbul", "إسطنبول", 41.0082, 28.9784, "Europe/Istanbul"),
        CityPreset("Ankara", "أنقرة", 39.9334, 32.8597, "Europe/Istanbul"),
        CityPreset("Tehran", "طهران", 35.6892, 51.3890, "Asia/Tehran"),
        CityPreset("Baku", "باكو", 40.4093, 49.8671, "Asia/Baku"),
        CityPreset("Tashkent", "طشقند", 41.2995, 69.2401, "Asia/Tashkent"),
        CityPreset("Karachi", "كراتشي", 24.8607, 67.0011, "Asia/Karachi"),
        CityPreset("Lahore", "لاهور", 31.5204, 74.3587, "Asia/Karachi"),
        CityPreset("Islamabad", "إسلام آباد", 33.6844, 73.0479, "Asia/Karachi"),
        CityPreset("Dhaka", "دكا", 23.8103, 90.4125, "Asia/Dhaka"),
        CityPreset("Delhi", "دلهي", 28.7041, 77.1025, "Asia/Kolkata"),
        CityPreset("Mumbai", "مومباي", 19.0760, 72.8777, "Asia/Kolkata"),
        // Southeast Asia
        CityPreset("Jakarta", "جاكرتا", -6.2088, 106.8456, "Asia/Jakarta"),
        CityPreset("Kuala Lumpur", "كوالالمبور", 3.1390, 101.6869, "Asia/Kuala_Lumpur"),
        CityPreset("Singapore", "سنغافورة", 1.3521, 103.8198, "Asia/Singapore"),
        // Europe
        CityPreset("London", "لندن", 51.5074, -0.1278, "Europe/London"),
        CityPreset("Paris", "باريس", 48.8566, 2.3522, "Europe/Paris"),
        CityPreset("Berlin", "برلين", 52.5200, 13.4050, "Europe/Berlin"),
        CityPreset("Amsterdam", "أمستردام", 52.3676, 4.9041, "Europe/Amsterdam"),
        CityPreset("Brussels", "بروكسل", 50.8503, 4.3517, "Europe/Brussels"),
        CityPreset("Stockholm", "ستوكهولم", 59.3293, 18.0686, "Europe/Stockholm"),
        CityPreset("Moscow", "موسكو", 55.7558, 37.6173, "Europe/Moscow"),
        // Americas
        CityPreset("New York", "نيويورك", 40.7128, -74.0060, "America/New_York"),
        CityPreset("Toronto", "تورونتو", 43.6532, -79.3832, "America/Toronto"),
        CityPreset("Chicago", "شيكاغو", 41.8781, -87.6298, "America/Chicago"),
        CityPreset("Houston", "هيوستن", 29.7604, -95.3698, "America/Chicago"),
        CityPreset("Los Angeles", "لوس أنجلوس", 34.0522, -118.2437, "America/Los_Angeles"),
        // Oceania
        CityPreset("Sydney", "سيدني", -33.8688, 151.2093, "Australia/Sydney"),
        CityPreset("Melbourne", "ملبورن", -37.8136, 144.9631, "Australia/Melbourne"),
    )

    fun named(name: String): CityPreset = all.firstOrNull { it.name == name } ?: all[0]

    /// Closest preset to a coordinate — 1:1 with iOS `CityPreset.nearest`.
    fun nearest(latitude: Double, longitude: Double): CityPreset =
        all.minByOrNull { distanceSq(it, latitude, longitude) } ?: all[0]

    private fun distanceSq(city: CityPreset, lat: Double, lon: Double): Double {
        val dLat = city.latitude - lat
        // Rough longitude scaling by latitude — plenty for a nearest label.
        val dLon = (city.longitude - lon) * kotlin.math.cos(Math.toRadians(lat))
        return dLat * dLat + dLon * dLon
    }
}

/// Calculation methods exposed in Settings — 1:1 with iOS CalculationMethodChoice.
enum class CalculationMethodChoice(
    val nameArabic: String,
    val nameEnglish: String,
    val adhanMethod: CalculationMethod,
) {
    MOONSIGHTING_COMMITTEE("لجنة رؤية الهلال", "Moonsighting Committee", CalculationMethod.MOON_SIGHTING_COMMITTEE),
    MUSLIM_WORLD_LEAGUE("رابطة العالم الإسلامي", "Muslim World League", CalculationMethod.MUSLIM_WORLD_LEAGUE),
    EGYPTIAN("الهيئة المصرية العامة", "Egyptian General Authority", CalculationMethod.EGYPTIAN),
    UMM_AL_QURA("أم القرى (مكة)", "Umm al-Qura (Makkah)", CalculationMethod.UMM_AL_QURA),
    KARACHI("جامعة كراتشي", "University of Karachi", CalculationMethod.KARACHI),
    DUBAI("دبي", "Dubai", CalculationMethod.DUBAI),
    NORTH_AMERICA("إسنا (أمريكا الشمالية)", "ISNA (North America)", CalculationMethod.NORTH_AMERICA);

    companion object {
        fun named(name: String?): CalculationMethodChoice =
            entries.firstOrNull { it.name == name } ?: MOONSIGHTING_COMMITTEE
    }
}

enum class MadhabChoice(val nameArabic: String, val adhanMadhab: Madhab) {
    SHAFI("الشافعي والمالكي والحنبلي", Madhab.SHAFI),
    HANAFI("الحنفي", Madhab.HANAFI);

    companion object {
        fun named(name: String?): MadhabChoice =
            entries.firstOrNull { it.name == name } ?: SHAFI
    }
}

/// Adhan notification sounds — 1:1 with the iOS `AdhanSound` enum
/// (bundled clips converted from App/Resources/adhan_*.caf).
enum class AdhanSound(val nameArabic: String, val rawRes: Int?) {
    MADINAH("أذان الحرم النبوي", R.raw.adhan_madinah),
    MELODIC("أذان مجوّد", R.raw.adhan_melodic),
    AZEEZ("أذان (عاقب عزيز)", R.raw.adhan_azeez),
    BELL("تنبيه", null),
    SILENT("صامت", null);

    companion object {
        fun named(name: String?): AdhanSound =
            entries.firstOrNull { it.name == name } ?: MADINAH
    }
}

/// SharedPreferences-backed prayer settings — mirrors the iOS @AppStorage keys.
/// Writes happen only from explicit user actions (never from Compose observers).
class PrayerPrefs(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("prayer", Context.MODE_PRIVATE)

    var cityName: String
        get() = prefs.getString("prayer.city", Cities.all[0].name) ?: Cities.all[0].name
        set(value) = prefs.edit().putString("prayer.city", value).apply()

    var method: CalculationMethodChoice
        get() = CalculationMethodChoice.named(prefs.getString("prayer.method", null))
        set(value) = prefs.edit().putString("prayer.method", value.name).apply()

    var madhab: MadhabChoice
        get() = MadhabChoice.named(prefs.getString("prayer.madhab", null))
        set(value) = prefs.edit().putString("prayer.madhab", value.name).apply()

    val city: CityPreset get() = Cities.named(cityName)

    /// One-shot device location — mirrors the iOS "prayer.useCustom",
    /// "prayer.customLat/Lon/Label" keys. Exact coordinates are stored and
    /// reused offline; nothing ever leaves the device (CLAUDE.md rule 3).
    var useCustomLocation: Boolean
        get() = prefs.getBoolean("prayer.useCustom", false)
        set(value) = prefs.edit().putBoolean("prayer.useCustom", value).apply()

    val customLat: Double
        get() = Double.fromBits(prefs.getLong("prayer.customLat", 0L))

    val customLon: Double
        get() = Double.fromBits(prefs.getLong("prayer.customLon", 0L))

    val customLabel: String
        get() = prefs.getString("prayer.customLabel", null) ?: "موقعي"

    fun saveCustomLocation(latitude: Double, longitude: Double, label: String) {
        prefs.edit()
            .putLong("prayer.customLat", latitude.toRawBits())
            .putLong("prayer.customLon", longitude.toRawBits())
            .putString("prayer.customLabel", label)
            .putBoolean("prayer.useCustom", true)
            .apply()
    }

    /// The active location: the saved device fix (device time zone, labelled
    /// with the nearest preset like iOS) or the selected city preset.
    val location: CityPreset
        get() = if (useCustomLocation) {
            val label = customLabel
            CityPreset(
                name = label,
                nameArabic = Cities.all.firstOrNull { it.name == label }?.nameArabic ?: label,
                latitude = customLat,
                longitude = customLon,
                timeZone = TimeZone.getDefault().id)
        } else {
            city
        }

    /// Adhan sound choice — mirrors iOS "prayer.sound".
    var sound: AdhanSound
        get() = AdhanSound.named(prefs.getString("prayer.sound", null))
        set(value) = prefs.edit().putString("prayer.sound", value.name).apply()

    /// Gentle reminder N minutes before each adhan (0 = off) — iOS "prayer.prealert".
    var preAlertMinutes: Int
        get() = prefs.getInt("prayer.prealert", 0)
        set(value) = prefs.edit().putInt("prayer.prealert", value).apply()

    /// Per-prayer notification toggles (iOS "notif.fajr" … "notif.isha", default on).
    fun notificationEnabled(prayerKey: String): Boolean =
        prefs.getBoolean("notif.$prayerKey", true)

    fun setNotificationEnabled(prayerKey: String, enabled: Boolean) {
        prefs.edit().putBoolean("notif.$prayerKey", enabled).apply()
    }

    /// Manual per-prayer offsets in minutes, clamped to -30..30 like iOS.
    fun adjustment(prayerKey: String): Int = prefs.getInt("prayer.adj.$prayerKey", 0)

    fun setAdjustment(prayerKey: String, minutes: Int) {
        prefs.edit().putInt("prayer.adj.$prayerKey", minutes.coerceIn(-30, 30)).apply()
    }
}

data class PrayerEntry(
    val key: String,
    val nameArabic: String,
    val nameEnglish: String,
    val time: Date,
)

object PrayerEngine {
    fun today(
        city: CityPreset,
        date: Date = Date(),
        method: CalculationMethodChoice = CalculationMethodChoice.MOONSIGHTING_COMMITTEE,
        madhab: MadhabChoice = MadhabChoice.SHAFI,
        adjustments: (String) -> Int = { 0 },
    ): List<PrayerEntry> {
        val zone = TimeZone.getTimeZone(city.timeZone)
        val calendar = Calendar.getInstance(zone).apply { time = date }
        val components = DateComponents(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH))
        val params = method.adhanMethod.parameters.apply {
            this.madhab = madhab.adhanMadhab
        }
        val times = PrayerTimes(Coordinates(city.latitude, city.longitude), components, params)
        fun adjusted(time: Date, key: String): Date =
            Date(time.time + adjustments(key) * 60_000L)
        return listOf(
            PrayerEntry("fajr", "الفجر", "Fajr", adjusted(times.fajr, "fajr")),
            PrayerEntry("dhuhr", "الظهر", "Dhuhr", adjusted(times.dhuhr, "dhuhr")),
            PrayerEntry("asr", "العصر", "Asr", adjusted(times.asr, "asr")),
            PrayerEntry("maghrib", "المغرب", "Maghrib", adjusted(times.maghrib, "maghrib")),
            PrayerEntry("isha", "العشاء", "Isha", adjusted(times.isha, "isha")),
        )
    }

    fun today(prefs: PrayerPrefs, date: Date = Date()): List<PrayerEntry> =
        today(prefs.location, date, prefs.method, prefs.madhab, prefs::adjustment)

    fun next(entries: List<PrayerEntry>, now: Date = Date()): PrayerEntry? =
        entries.firstOrNull { it.time.after(now) }
}
