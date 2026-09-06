import SwiftUI

#if os(iOS)
import UIKit

private struct NoorPlatformChromeTypographyModifier: ViewModifier {
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.background(
            NoorPlatformChromeTypographyResolver(
                usesArabicFont: NoorFont.usesArabicInterfaceFont(locale: locale)
            )
            .frame(width: 0, height: 0)
        )
    }
}

/// Adapts SwiftUI locale changes to UIKit-owned tab and navigation bars.
private struct NoorPlatformChromeTypographyResolver: UIViewControllerRepresentable {
    let usesArabicFont: Bool

    func makeUIViewController(context: Context) -> NoorPlatformChromeResolverViewController {
        NoorPlatformChromeResolverViewController(usesArabicFont: usesArabicFont)
    }

    func updateUIViewController(
        _ viewController: NoorPlatformChromeResolverViewController,
        context: Context
    ) {
        viewController.update(usesArabicFont: usesArabicFont)
    }
}

private final class NoorPlatformChromeResolverViewController: UIViewController {
    private var usesArabicFont: Bool
    private var appliedUsesArabicFont: Bool?
    private var isApplicationScheduled = false

    init(usesArabicFont: Bool) {
        self.usesArabicFont = usesArabicFont
        super.init(nibName: nil, bundle: nil)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleApplication()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent != nil {
            scheduleApplication(force: true)
        }
    }

    func update(usesArabicFont: Bool) {
        if self.usesArabicFont != usesArabicFont {
            self.usesArabicFont = usesArabicFont
            appliedUsesArabicFont = nil
        }
        scheduleApplication()
    }

    private func scheduleApplication(force: Bool = false) {
        if force {
            appliedUsesArabicFont = nil
        }
        guard appliedUsesArabicFont != usesArabicFont,
              !isApplicationScheduled else { return }

        isApplicationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isApplicationScheduled = false
            guard appliedUsesArabicFont != usesArabicFont,
                  let rootViewController = view.window?.rootViewController else { return }

            NoorPlatformChromeAppearance.apply(
                to: rootViewController,
                usesArabicFont: usesArabicFont
            )
            appliedUsesArabicFont = usesArabicFont
        }
    }
}
#endif

public extension View {
    /// Applies the locale-aware Noor interface font to SwiftUI's UIKit-backed
    /// tab and navigation bars, which do not inherit the SwiftUI `font` value.
    @ViewBuilder
    func noorPlatformChromeTypography() -> some View {
        #if os(iOS)
        modifier(NoorPlatformChromeTypographyModifier())
        #else
        self
        #endif
    }
}
