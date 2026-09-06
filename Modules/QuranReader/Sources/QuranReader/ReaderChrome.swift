import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shared reader-chrome state — the iOS twin of Android's `ReaderChrome`.
///
/// The reader is immersive: the system tab bar is hidden for the whole
/// session. But iOS has no system back button, and with the navigation bar
/// hidden the interactive edge-swipe back is gone too (verified on the
/// simulator), so in the fully immersive state the drawer's "Back to Quran"
/// row is the only way out. To give a familiar escape, the app layer draws a
/// floating tab bar over the reader whenever the reader's chrome is up: tap
/// the page, the top strip AND the bar fade in together; tap again, both go.
///
/// This is the single source of truth for that — `SurahReaderView` owns
/// `chromeVisible` through this object (it has no private copy), so the bar
/// can never disagree with the strip.
///
/// Deliberate divergence from Android, which keeps its bar hidden for the
/// whole reader session because it has a system back button. Do not
/// "fix" the two back into symmetry.
@MainActor
@Observable
public final class ReaderChrome {
    public static let shared = ReaderChrome()

    /// True while a Quran reader is on screen.
    public private(set) var readerOpen = false
    /// True while the reader's chrome (top strip) is showing.
    public var chromeVisible = true

    private init() {}

    /// Reader appeared: chrome starts visible (it auto-hides shortly after).
    public func readerAppeared() {
        readerOpen = true
        chromeVisible = true
    }

    /// Reader left by ANY path — drawer exit row, tab switch, pop.
    public func readerDisappeared() {
        readerOpen = false
        chromeVisible = false
    }

    /// Height of the home indicator (0 on a home-button device).
    ///
    /// The reader ignores its container's bottom safe area so the tab bar
    /// floats over the page instead of resizing it, then pads this back in
    /// to keep exactly the layout it had before the bar existed. It must
    /// come from the WINDOW: a `GeometryProxy`'s bottom inset includes the
    /// tab bar — the very thing being ignored — while the window's carries
    /// only the system inset and never moves when the bar appears.
    public static var homeIndicatorInset: CGFloat {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
        #else
        0
        #endif
    }
}

