import AppIntents
import Foundation
import Notifications
import PrayerTimes

/// "اقرأ وردي" — opens the reader at the khatmah frontier (or last page).
struct ReadMyWirdIntent: AppIntent {
    static let title: LocalizedStringResource = "Read my wird"
    static let description = IntentDescription("Opens the Quran at your next khatmah page.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        let frontier = defaults.integer(forKey: "khatmah.page")
        let page = frontier > 0 ? frontier : max(1, defaults.integer(forKey: "reader.lastPage"))
        defaults.set(page, forKey: "pending.openPage")
        NotificationCenter.default.post(name: .noorOpenPendingPage, object: nil)
        return .result()
    }
}

/// "متى الصلاة القادمة" — speaks the next prayer and its time.
struct NextPrayerIntent: AppIntent {
    static let title: LocalizedStringResource = "Next prayer time"
    static let description = IntentDescription("Tells you the next prayer and when it is.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard
        let location = PrayerLocation.current()
        let method = CalculationMethodChoice(
            rawValue: defaults.string(forKey: "prayer.method") ?? "") ?? .moonsightingCommittee
        let madhab = MadhabChoice(rawValue: defaults.string(forKey: "prayer.madhab") ?? "") ?? .shafi
        guard let next = AdhanNotificationPlanner.plan(
            location: location, method: method, madhab: madhab, days: 2, limit: 1).first
        else {
            return .result(dialog: "I couldn't compute the prayer times.")
        }
        return .result(dialog: "\(next.prayerName): \(next.timeString)")
    }
}

/// Tasbih increment — usable from Shortcuts and interactive widgets.
struct TasbihIncrementIntent: AppIntent {
    static let title: LocalizedStringResource = "Add tasbih"
    static let description = IntentDescription("Adds one to your tasbih counter.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: "tasbih.count") + 1
        defaults.set(count, forKey: "tasbih.count")
        return .result(dialog: "\(count)")
    }
}

extension Notification.Name {
    static let noorOpenPendingPage = Notification.Name("noorOpenPendingPage")
}

/// Siri phrases in both app languages.
struct NoorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadMyWirdIntent(),
            phrases: [
                "Read my wird in \(.applicationName)",
                "اقرأ وردي في \(.applicationName)",
                "Continue my khatmah in \(.applicationName)",
            ],
            shortTitle: "Read my wird",
            systemImageName: "book")
        AppShortcut(
            intent: NextPrayerIntent(),
            phrases: [
                "Next prayer in \(.applicationName)",
                "متى الصلاة في \(.applicationName)",
            ],
            shortTitle: "Next prayer",
            systemImageName: "clock")
        AppShortcut(
            intent: TasbihIncrementIntent(),
            phrases: [
                "Tasbih in \(.applicationName)",
                "سبح في \(.applicationName)",
            ],
            shortTitle: "Tasbih",
            systemImageName: "circle.grid.3x3")
    }
}
