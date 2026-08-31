import DesignSystem
import SwiftUI

/// Compact floating player pill (design 1c): reciter, ayah reference,
/// previous/play/next, stop. Shown over the reader while audio plays.
public struct AudioPillView: View {
    @Bindable var player: QuranAudioPlayer

    public init(player: QuranAudioPlayer) {
        self.player = player
    }

    public var body: some View {
        if let current = player.current {
            HStack(spacing: 12) {
                Menu {
                    ForEach(Reciter.allCases) { reciter in
                        Button(reciter.displayName) { player.reciter = reciter }
                    }
                } label: {
                    Image(systemName: "person.wave.2")
                        .font(.system(size: 15))
                        .foregroundStyle(NoorColor.accentPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(NoorColor.accentPrimary.opacity(0.15)))
                }
                .accessibilityLabel("Reciter: \(player.reciter.displayName)")

                VStack(alignment: .leading, spacing: 1) {
                    Text(player.reciter.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineLimit(1)
                    Text("\(player.surahTitle) · \(String(localized: "Ayah \(current.ayah)"))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NoorColor.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)

                Button { player.previous() } label: {
                    Image(systemName: "backward.fill").font(.system(size: 14))
                }
                .accessibilityLabel("Previous ayah")

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(NoorColor.bgPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(NoorColor.accentPrimary))
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.system(size: 14))
                }
                .accessibilityLabel("Next ayah")

                Button { player.stop() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                }
                .accessibilityLabel("Stop")
            }
            .buttonStyle(.plain)
            .foregroundStyle(NoorColor.inkSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(NoorColor.bgElevated)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            )
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
