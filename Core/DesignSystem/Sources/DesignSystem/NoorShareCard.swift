import DesignSystem
import SwiftUI

/// Status-ready branded image card: paper background, gold frame, mihrab
/// mark, Arabic text, optional translation, reference + attribution.
public struct NoorShareCard: View {
    let arabicText: String
    let translation: String?
    let reference: String
    let attribution: String
    let useQuranFont: Bool

    public var body: some View {
        VStack(spacing: 18) {
            MihrabLogoMark(
                size: 44,
                archColor: Color(red: 0.055, green: 0.420, blue: 0.361),
                lampColor: Color(red: 0.73, green: 0.54, blue: 0.18))
            Text(arabicText)
                .font(useQuranFont ? NoorFont.quran(size: 30) : .system(size: 24))
                .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.20))
                .lineSpacing(useQuranFont ? 22 : 14)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
            if let translation {
                Text(translation)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Color(red: 0.36, green: 0.40, blue: 0.44))
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 3) {
                Text(verbatim: reference)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.05, green: 0.42, blue: 0.36))
                Text(verbatim: attribution)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.36, green: 0.40, blue: 0.44).opacity(0.8))
            }
        }
        .padding(36)
        .frame(width: 620)
        .background(Color(red: 0.98, green: 0.965, blue: 0.933))
        .overlay(Rectangle().stroke(Color(red: 0.73, green: 0.54, blue: 0.18), lineWidth: 1.5).padding(10))
    }
}

/// Renders the card at 3× and offers the system share sheet.
public struct NoorShareSheet: View {
    let arabicText: String
    let translation: String?
    let reference: String
    let attribution: String
    let useQuranFont: Bool

    @State private var fileURL: URL?
    @Environment(\.dismiss) private var dismiss

    public init(arabicText: String, translation: String? = nil, reference: String,
                attribution: String, useQuranFont: Bool) {
        self.arabicText = arabicText
        self.translation = translation
        self.reference = reference
        self.attribution = attribution
        self.useQuranFont = useQuranFont
    }

    private var card: NoorShareCard {
        NoorShareCard(arabicText: arabicText, translation: translation,
                      reference: reference, attribution: attribution, useQuranFont: useQuranFont)
    }

    public var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                card
                    .scaleEffect(0.5, anchor: .top)
                    .frame(maxWidth: .infinity)
            }
            if let fileURL {
                ShareLink(item: fileURL) {
                    Label("Share image", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NoorColor.bgPrimary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(NoorColor.accentPrimary))
                }
            } else {
                ProgressView()
            }
            Button("Done") { dismiss() }
                .foregroundStyle(NoorColor.inkSecondary)
        }
        .padding(.vertical, 24)
        .background(NoorColor.bgPrimary)
        .task { render() }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
        renderer.scale = 3
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("noor-share-\(abs(reference.hashValue)).png")
        #if os(iOS)
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        #else
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return }
        #endif
        try? data.write(to: url)
        fileURL = url
    }
}
