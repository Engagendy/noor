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

private struct NoorPlatformChromeTypographyResolver: UIViewControllerRepresentable {
    let usesArabicFont: Bool

    func makeUIViewController(context: Context) -> ResolverViewController {
        ResolverViewController(usesArabicFont: usesArabicFont)
    }

    func updateUIViewController(
        _ viewController: ResolverViewController,
        context: Context
    ) {
        viewController.update(usesArabicFont: usesArabicFont)
    }

    final class ResolverViewController: UIViewController {
        private var usesArabicFont: Bool

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
            applyTypographyWhenAttached()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyTypographyWhenAttached()
        }

        func update(usesArabicFont: Bool) {
            self.usesArabicFont = usesArabicFont
            applyTypographyWhenAttached()
        }

        private func applyTypographyWhenAttached() {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let rootViewController = view.window?.rootViewController else { return }

                Self.applyAppearanceDefaults(usesArabicFont: usesArabicFont)

                if let tabBarController = Self.findTabBarController(
                    from: rootViewController
                ) {
                    Self.applyTypography(
                        to: tabBarController.tabBar,
                        usesArabicFont: usesArabicFont
                    )
                }

                for navigationController in Self.findNavigationControllers(
                    from: rootViewController
                ) {
                    Self.applyTypography(
                        to: navigationController.navigationBar,
                        usesArabicFont: usesArabicFont
                    )
                }
            }
        }

        private static func findTabBarController(
            from viewController: UIViewController
        ) -> UITabBarController? {
            if let tabBarController = viewController as? UITabBarController {
                return tabBarController
            }
            if let presented = viewController.presentedViewController,
               let tabBarController = findTabBarController(from: presented) {
                return tabBarController
            }
            for child in viewController.children {
                if let tabBarController = findTabBarController(from: child) {
                    return tabBarController
                }
            }
            return nil
        }

        private static func findNavigationControllers(
            from viewController: UIViewController
        ) -> [UINavigationController] {
            var result: [UINavigationController] = []
            if let navigationController = (viewController as? UINavigationController) {
                result.append(navigationController)
            }
            if let presented = viewController.presentedViewController {
                result.append(contentsOf: findNavigationControllers(from: presented))
            }
            for child in viewController.children {
                result.append(contentsOf: findNavigationControllers(from: child))
            }
            return result
        }

        private static func applyAppearanceDefaults(usesArabicFont: Bool) {
            let tabFonts = tabBarFonts(usesArabicFont: usesArabicFont)
            UITabBarItem.appearance().setTitleTextAttributes(
                [.font: tabFonts.normal],
                for: .normal
            )
            UITabBarItem.appearance().setTitleTextAttributes(
                [.font: tabFonts.selected],
                for: .selected
            )

            let navigationFonts = navigationBarFonts(
                usesArabicFont: usesArabicFont
            )
            let navigationBar = UINavigationBar.appearance()
            var titleAttributes = navigationBar.titleTextAttributes ?? [:]
            titleAttributes[.font] = navigationFonts.inline
            navigationBar.titleTextAttributes = titleAttributes
            var largeTitleAttributes = navigationBar.largeTitleTextAttributes ?? [:]
            largeTitleAttributes[.font] = navigationFonts.large
            navigationBar.largeTitleTextAttributes = largeTitleAttributes
        }

        private static func applyTypography(
            to tabBar: UITabBar,
            usesArabicFont: Bool
        ) {
            let fonts = tabBarFonts(usesArabicFont: usesArabicFont)

            let standardAppearance = updatedAppearance(
                tabBar.standardAppearance,
                fonts: fonts
            )
            tabBar.standardAppearance = standardAppearance

            if let scrollEdgeAppearance = tabBar.scrollEdgeAppearance {
                tabBar.scrollEdgeAppearance = updatedAppearance(
                    scrollEdgeAppearance,
                    fonts: fonts
                )
            }

            for item in tabBar.items ?? [] {
                var normalAttributes = item.titleTextAttributes(for: .normal) ?? [:]
                normalAttributes[.font] = fonts.normal
                item.setTitleTextAttributes(normalAttributes, for: .normal)

                var selectedAttributes = item.titleTextAttributes(for: .selected) ?? [:]
                selectedAttributes[.font] = fonts.selected
                item.setTitleTextAttributes(selectedAttributes, for: .selected)
            }

            tabBar.setNeedsLayout()
        }

        private static func updatedAppearance(
            _ source: UITabBarAppearance,
            fonts: (normal: UIFont, selected: UIFont)
        ) -> UITabBarAppearance {
            let appearance = source.copy()
            apply(fonts, to: appearance.stackedLayoutAppearance)
            apply(fonts, to: appearance.inlineLayoutAppearance)
            apply(fonts, to: appearance.compactInlineLayoutAppearance)
            return appearance
        }

        private static func applyTypography(
            to navigationBar: UINavigationBar,
            usesArabicFont: Bool
        ) {
            let fonts = navigationBarFonts(usesArabicFont: usesArabicFont)
            navigationBar.standardAppearance = updatedAppearance(
                navigationBar.standardAppearance,
                fonts: fonts
            )
            if let compactAppearance = navigationBar.compactAppearance {
                navigationBar.compactAppearance = updatedAppearance(
                    compactAppearance,
                    fonts: fonts
                )
            }
            if let scrollEdgeAppearance = navigationBar.scrollEdgeAppearance {
                navigationBar.scrollEdgeAppearance = updatedAppearance(
                    scrollEdgeAppearance,
                    fonts: fonts
                )
            }
            if let compactScrollEdgeAppearance = navigationBar
                .compactScrollEdgeAppearance {
                navigationBar.compactScrollEdgeAppearance = updatedAppearance(
                    compactScrollEdgeAppearance,
                    fonts: fonts
                )
            }

            var titleAttributes = navigationBar.titleTextAttributes ?? [:]
            titleAttributes[.font] = fonts.inline
            navigationBar.titleTextAttributes = titleAttributes
            var largeTitleAttributes = navigationBar.largeTitleTextAttributes ?? [:]
            largeTitleAttributes[.font] = fonts.large
            navigationBar.largeTitleTextAttributes = largeTitleAttributes
            navigationBar.setNeedsLayout()
        }

        private static func updatedAppearance(
            _ source: UINavigationBarAppearance,
            fonts: (inline: UIFont, large: UIFont)
        ) -> UINavigationBarAppearance {
            let appearance = source.copy()
            var titleAttributes = appearance.titleTextAttributes
            titleAttributes[.font] = fonts.inline
            appearance.titleTextAttributes = titleAttributes
            var largeTitleAttributes = appearance.largeTitleTextAttributes
            largeTitleAttributes[.font] = fonts.large
            appearance.largeTitleTextAttributes = largeTitleAttributes
            return appearance
        }

        private static func apply(
            _ fonts: (normal: UIFont, selected: UIFont),
            to itemAppearance: UITabBarItemAppearance
        ) {
            var normalAttributes = itemAppearance.normal.titleTextAttributes
            normalAttributes[.font] = fonts.normal
            itemAppearance.normal.titleTextAttributes = normalAttributes

            var selectedAttributes = itemAppearance.selected.titleTextAttributes
            selectedAttributes[.font] = fonts.selected
            itemAppearance.selected.titleTextAttributes = selectedAttributes
        }

        private static func tabBarFonts(
            usesArabicFont: Bool
        ) -> (normal: UIFont, selected: UIFont) {
            let size: CGFloat = 10
            guard usesArabicFont else {
                return (
                    UIFont.systemFont(ofSize: size, weight: .regular),
                    UIFont.systemFont(ofSize: size, weight: .semibold)
                )
            }

            FontRegistrar.registerBundledFonts()
            return (
                UIFont(name: "Cairo-Regular", size: size)
                    ?? UIFont.systemFont(ofSize: size, weight: .regular),
                UIFont(name: "Cairo-SemiBold", size: size)
                    ?? UIFont.systemFont(ofSize: size, weight: .semibold)
            )
        }

        private static func navigationBarFonts(
            usesArabicFont: Bool
        ) -> (inline: UIFont, large: UIFont) {
            guard usesArabicFont else {
                return (
                    UIFont.systemFont(ofSize: 17, weight: .semibold),
                    UIFont.systemFont(ofSize: 34, weight: .bold)
                )
            }

            FontRegistrar.registerBundledFonts()
            return (
                UIFont(name: "Cairo-SemiBold", size: 17)
                    ?? UIFont.systemFont(ofSize: 17, weight: .semibold),
                UIFont(name: "Cairo-Bold", size: 34)
                    ?? UIFont.systemFont(ofSize: 34, weight: .bold)
            )
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
