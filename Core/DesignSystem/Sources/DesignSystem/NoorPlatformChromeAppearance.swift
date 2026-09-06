#if os(iOS)
import UIKit

/// Platform-default point sizes and the registered variable-font instances.
private enum NoorPlatformChromeFontToken {
    static let tabBarSize: CGFloat = 10
    static let navigationInlineSize: CGFloat = 17
    static let navigationLargeSize: CGFloat = 34

    static let cairoRegular = "\(NoorFont.arabicUIFontName)-Regular"
    // CoreText exposes the variable font's named instances with the
    // Regular_ prefix, even though font metadata tools display shorter names.
    static let cairoSemibold = "\(NoorFont.arabicUIFontName)-Regular_SemiBold"
    static let cairoBold = "\(NoorFont.arabicUIFontName)-Regular_Bold"
}

private struct NoorTabBarFonts {
    let normal: UIFont?
    let selected: UIFont?
}

private struct NoorNavigationBarFonts {
    let inline: UIFont?
    let large: UIFont?
}

/// Creates Cairo fonts for Arabic and nil for the UIKit system defaults.
private enum NoorPlatformChromeFontFactory {
    static func tabBar(usesArabicFont: Bool) -> NoorTabBarFonts {
        guard usesArabicFont else {
            return NoorTabBarFonts(normal: nil, selected: nil)
        }

        FontRegistrar.registerBundledFonts()
        let size = NoorPlatformChromeFontToken.tabBarSize
        return NoorTabBarFonts(
            normal: UIFont(
                name: NoorPlatformChromeFontToken.cairoRegular,
                size: size
            ) ?? UIFont.systemFont(ofSize: size, weight: .regular),
            selected: UIFont(
                name: NoorPlatformChromeFontToken.cairoSemibold,
                size: size
            ) ?? UIFont.systemFont(ofSize: size, weight: .semibold)
        )
    }

    static func navigationBar(usesArabicFont: Bool) -> NoorNavigationBarFonts {
        guard usesArabicFont else {
            return NoorNavigationBarFonts(inline: nil, large: nil)
        }

        FontRegistrar.registerBundledFonts()
        let inlineSize = NoorPlatformChromeFontToken.navigationInlineSize
        let largeSize = NoorPlatformChromeFontToken.navigationLargeSize
        return NoorNavigationBarFonts(
            inline: UIFont(
                name: NoorPlatformChromeFontToken.cairoSemibold,
                size: inlineSize
            ) ?? UIFont.systemFont(ofSize: inlineSize, weight: .semibold),
            large: UIFont(
                name: NoorPlatformChromeFontToken.cairoBold,
                size: largeSize
            ) ?? UIFont.systemFont(ofSize: largeSize, weight: .bold)
        )
    }
}

/// Applies the font factory output while preserving every non-font attribute.
enum NoorPlatformChromeAppearance {
    static func apply(
        to rootViewController: UIViewController,
        usesArabicFont: Bool
    ) {
        applyAppearanceDefaults(usesArabicFont: usesArabicFont)

        for tabBarController in descendants(
            of: UITabBarController.self,
            from: rootViewController
        ) {
            applyTypography(
                to: tabBarController.tabBar,
                usesArabicFont: usesArabicFont
            )
        }

        for navigationController in descendants(
            of: UINavigationController.self,
            from: rootViewController
        ) {
            applyTypography(
                to: navigationController.navigationBar,
                usesArabicFont: usesArabicFont
            )
        }
    }

    private static func descendants<T: UIViewController>(
        of type: T.Type,
        from viewController: UIViewController
    ) -> [T] {
        var result = (viewController as? T).map { [$0] } ?? []
        if let presented = viewController.presentedViewController {
            result.append(contentsOf: descendants(of: type, from: presented))
        }
        for child in viewController.children {
            result.append(contentsOf: descendants(of: type, from: child))
        }
        return result
    }

    private static func applyAppearanceDefaults(usesArabicFont: Bool) {
        let tabFonts = NoorPlatformChromeFontFactory.tabBar(
            usesArabicFont: usesArabicFont
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            fontAttributes(tabFonts.normal),
            for: .normal
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            fontAttributes(tabFonts.selected),
            for: .selected
        )

        let navigationFonts = NoorPlatformChromeFontFactory.navigationBar(
            usesArabicFont: usesArabicFont
        )
        let navigationBar = UINavigationBar.appearance()
        navigationBar.titleTextAttributes = attributes(
            navigationBar.titleTextAttributes ?? [:],
            setting: navigationFonts.inline
        )
        navigationBar.largeTitleTextAttributes = attributes(
            navigationBar.largeTitleTextAttributes ?? [:],
            setting: navigationFonts.large
        )
    }

    private static func applyTypography(
        to tabBar: UITabBar,
        usesArabicFont: Bool
    ) {
        let fonts = NoorPlatformChromeFontFactory.tabBar(
            usesArabicFont: usesArabicFont
        )
        tabBar.standardAppearance = updatedAppearance(
            tabBar.standardAppearance,
            fonts: fonts
        )
        if let scrollEdgeAppearance = tabBar.scrollEdgeAppearance {
            tabBar.scrollEdgeAppearance = updatedAppearance(
                scrollEdgeAppearance,
                fonts: fonts
            )
        }

        for item in tabBar.items ?? [] {
            item.setTitleTextAttributes(
                attributes(
                    item.titleTextAttributes(for: .normal) ?? [:],
                    setting: fonts.normal
                ),
                for: .normal
            )
            item.setTitleTextAttributes(
                attributes(
                    item.titleTextAttributes(for: .selected) ?? [:],
                    setting: fonts.selected
                ),
                for: .selected
            )
        }
        tabBar.setNeedsLayout()
    }

    private static func updatedAppearance(
        _ source: UITabBarAppearance,
        fonts: NoorTabBarFonts
    ) -> UITabBarAppearance {
        let appearance = source.copy()
        apply(fonts, to: appearance.stackedLayoutAppearance)
        apply(fonts, to: appearance.inlineLayoutAppearance)
        apply(fonts, to: appearance.compactInlineLayoutAppearance)
        return appearance
    }

    private static func apply(
        _ fonts: NoorTabBarFonts,
        to itemAppearance: UITabBarItemAppearance
    ) {
        itemAppearance.normal.titleTextAttributes = attributes(
            itemAppearance.normal.titleTextAttributes,
            setting: fonts.normal
        )
        itemAppearance.selected.titleTextAttributes = attributes(
            itemAppearance.selected.titleTextAttributes,
            setting: fonts.selected
        )
    }

    private static func applyTypography(
        to navigationBar: UINavigationBar,
        usesArabicFont: Bool
    ) {
        let fonts = NoorPlatformChromeFontFactory.navigationBar(
            usesArabicFont: usesArabicFont
        )
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
        if let compactScrollEdgeAppearance = navigationBar.compactScrollEdgeAppearance {
            navigationBar.compactScrollEdgeAppearance = updatedAppearance(
                compactScrollEdgeAppearance,
                fonts: fonts
            )
        }

        navigationBar.titleTextAttributes = attributes(
            navigationBar.titleTextAttributes ?? [:],
            setting: fonts.inline
        )
        navigationBar.largeTitleTextAttributes = attributes(
            navigationBar.largeTitleTextAttributes ?? [:],
            setting: fonts.large
        )
        navigationBar.setNeedsLayout()
    }

    private static func updatedAppearance(
        _ source: UINavigationBarAppearance,
        fonts: NoorNavigationBarFonts
    ) -> UINavigationBarAppearance {
        let appearance = source.copy()
        appearance.titleTextAttributes = attributes(
            appearance.titleTextAttributes,
            setting: fonts.inline
        )
        appearance.largeTitleTextAttributes = attributes(
            appearance.largeTitleTextAttributes,
            setting: fonts.large
        )
        return appearance
    }

    private static func fontAttributes(
        _ font: UIFont?
    ) -> [NSAttributedString.Key: Any]? {
        font.map { [.font: $0] }
    }

    private static func attributes(
        _ source: [NSAttributedString.Key: Any],
        setting font: UIFont?
    ) -> [NSAttributedString.Key: Any] {
        var result = source
        if let font {
            result[.font] = font
        } else {
            result.removeValue(forKey: .font)
        }
        return result
    }
}
#endif
