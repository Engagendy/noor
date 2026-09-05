import DesignSystem
import SwiftUI

/// Status-ready branded image card: paper background, gold frame, mihrab
/// mark, Arabic text, optional translation, reference + attribution.
private var shareCornerStar: some View {
    EightPointStar()
        .fill(Color(red: 0.73, green: 0.54, blue: 0.18).opacity(0.55))
        .frame(width: 16, height: 16)
        .padding(22)
}

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
        .background(
            ZStack {
                Color(red: 0.98, green: 0.965, blue: 0.933)
                IslamicLattice(tint: Color(red: 0.73, green: 0.54, blue: 0.18).opacity(0.055), tile: 74)
            }
        )
        .overlay(Rectangle().stroke(Color(red: 0.73, green: 0.54, blue: 0.18), lineWidth: 1.5).padding(10))
        .overlay(alignment: .topLeading) { shareCornerStar }
        .overlay(alignment: .topTrailing) { shareCornerStar }
        .overlay(alignment: .bottomLeading) { shareCornerStar }
        .overlay(alignment: .bottomTrailing) { shareCornerStar }
    }
}

/// Optional "Share as video" action for `NoorShareSheet`. DesignSystem stays
/// audio-free: the caller (QuranAudio) supplies the composer; the sheet only
/// hands over the rendered card and shows progress / errors / the share UI.
public struct NoorShareVideoOption {
    /// Sub-line under the button, e.g. "with Mishary Alafasy's recitation".
    public let caption: String
    /// Produces a local MP4 from the rendered card. Errors should be
    /// `LocalizedError`s — `errorDescription` is shown inline.
    public let make: (CGImage) async throws -> URL

    public init(caption: String, make: @escaping (CGImage) async throws -> URL) {
        self.caption = caption
        self.make = make
    }
}

/// Renders the card at 3× and offers the system share sheet.
public struct NoorShareSheet: View {
    let arabicText: String
    let translation: String?
    let reference: String
    let attribution: String
    let useQuranFont: Bool
    let videoOption: NoorShareVideoOption?

    private enum VideoState: Equatable {
        case idle, working, ready(URL), failed(String)
    }

    @State private var fileURL: URL?
    @State private var cardImage: CGImage?
    @State private var videoState: VideoState = .idle
    @State private var videoTask: Task<Void, Never>?
    @State private var presentVideoShare = false
    @Environment(\.dismiss) private var dismiss

    public init(arabicText: String, translation: String? = nil, reference: String,
                attribution: String, useQuranFont: Bool,
                videoOption: NoorShareVideoOption? = nil) {
        self.arabicText = arabicText
        self.translation = translation
        self.reference = reference
        self.attribution = attribution
        self.useQuranFont = useQuranFont
        self.videoOption = videoOption
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
            if let videoOption {
                videoButton(videoOption)
            }
            Button("Done") { dismiss() }
                .foregroundStyle(NoorColor.inkSecondary)
        }
        .padding(.vertical, 24)
        .background(NoorColor.bgPrimary)
        .task { render() }
        .onDisappear { videoTask?.cancel() }
        #if os(iOS)
        .sheet(isPresented: $presentVideoShare) {
            if case .ready(let url) = videoState {
                ActivityShareView(items: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        #endif
    }

    // MARK: - Share as video

    @ViewBuilder
    private func videoButton(_ option: NoorShareVideoOption) -> some View {
        VStack(spacing: 6) {
            switch videoState {
            case .working:
                HStack(spacing: 10) {
                    ProgressView().tint(NoorColor.accentPrimary)
                    Text("Preparing video…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            case .ready(let url):
                #if os(iOS)
                Button { presentVideoShare = true } label: { videoLabel }
                    .buttonStyle(.plain)
                #else
                ShareLink(item: url) { videoLabel }
                    .buttonStyle(.plain)
                #endif
            case .idle, .failed:
                Button { startVideo(option) } label: { videoLabel }
                    .buttonStyle(.plain)
                    .disabled(cardImage == nil)
            }
            Text(verbatim: option.caption)
                .font(.system(size: 12))
                .foregroundStyle(NoorColor.inkSecondary)
            if case .failed(let message) = videoState {
                Text(verbatim: message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NoorColor.accentPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var videoLabel: some View {
        Label("Share as video", systemImage: "video")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(NoorColor.accentPrimary)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule().stroke(NoorColor.accentPrimary, lineWidth: 1.5))
            .contentShape(Capsule())
            .frame(minHeight: 44)
    }

    private func startVideo(_ option: NoorShareVideoOption) {
        guard let cardImage, videoState != .working else { return }
        videoState = .working
        videoTask = Task {
            do {
                let url = try await option.make(cardImage)
                guard !Task.isCancelled else { return }
                videoState = .ready(url)
                #if os(iOS)
                presentVideoShare = true
                #endif
            } catch is CancellationError {
                videoState = .idle
            } catch {
                guard !Task.isCancelled else { return }
                videoState = .failed(error.localizedDescription)
            }
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
        renderer.scale = 3
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("noor-share-\(abs(reference.hashValue)).png")
        cardImage = renderer.cgImage
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

#if os(iOS)
/// System share sheet wrapper so a freshly composed file can be offered
/// without a second tap (ShareLink can't be triggered programmatically).
private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
