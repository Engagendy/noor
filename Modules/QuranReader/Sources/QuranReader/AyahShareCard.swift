import ContentDB
import DesignSystem
import SwiftUI

/// Status-ready ayah image card: paper background, gold frame, Arabic text,
/// optional translation, reference + attribution (design §7 rules).
struct AyahShareCard: View {
    let verse: Verse
    let surahName: String
    let translation: String?

    var body: some View {
        VStack(spacing: 18) {
            MihrabLogoMark(
                size: 44,
                archColor: Color(red: 0.055, green: 0.420, blue: 0.361),
                lampColor: Color(red: 0.73, green: 0.54, blue: 0.18))
            Text(verse.text)
                .font(NoorFont.quran(size: 30))
                .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.20))
                .lineSpacing(22)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
            if let translation {
                Text(translation)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Color(red: 0.36, green: 0.40, blue: 0.44))
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 3) {
                Text(verbatim: "\(surahName) · \(verse.surahId):\(verse.ayah)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.05, green: 0.42, blue: 0.36))
                Text(verbatim: "نور Noor · Quran text: Tanzil.net")
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

/// Renders the card and offers the system share sheet.
struct ShareAyahSheet: View {
    let verse: Verse
    let surahName: String
    let translation: String?

    @State private var fileURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                AyahShareCard(verse: verse, surahName: surahName, translation: translation)
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
        let renderer = ImageRenderer(
            content: AyahShareCard(verse: verse, surahName: surahName, translation: translation)
                .environment(\.colorScheme, .light))
        renderer.scale = 3
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("noor-\(verse.surahId)-\(verse.ayah).png")
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
