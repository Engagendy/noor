import DesignSystem
import SwiftUI

/// Athkar home: tasbih counter up top, then Hisn al-Muslim categories.
public struct AthkarView: View {
    @State private var categories: [DhikrCategory] = []
    @State private var searchText = ""

    public init() {}

    private var filtered: [DhikrCategory] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return categories }
        return categories.filter {
            $0.category.contains(query)
                || $0.items.contains { $0.text.contains(query) }
        }
    }

    public var body: some View {
        List {
            NavigationLink {
                TasbihView()
            } label: {
                HStack(spacing: 14) {
                    RubElHizbMark(size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tasbih")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: "سبحان الله · الحمد لله · الله أكبر")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            ForEach(filtered) { category in
                NavigationLink {
                    DhikrListView(category: category)
                } label: {
                    HStack {
                        Text(verbatim: category.category)
                            .font(.system(size: 16))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Text(verbatim: "\(category.items.count)")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        // Athkar content is Arabic — always right-to-left, any UI language.
        .environment(\.layoutDirection, .rightToLeft)
        .searchable(text: $searchText, prompt: Text("Search athkar"))
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Athkar"))
        .task {
            if categories.isEmpty { categories = AthkarStore.load() }
        }
    }
}

/// One category: tappable dhikr cards that count down their repetitions.
struct DhikrListView: View {
    let category: DhikrCategory
    @State private var progress: [String: Int] = [:]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(category.items) { dhikr in
                    DhikrCard(
                        dhikr: dhikr,
                        done: progress[dhikr.id] ?? 0,
                        onTap: {
                            let current = progress[dhikr.id] ?? 0
                            if current < dhikr.count {
                                progress[dhikr.id] = current + 1
                                #if os(iOS)
                                if current + 1 == dhikr.count {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } else {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                #endif
                            }
                        })
                }
            }
            .padding(16)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text(verbatim: category.category))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    progress = [:]
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(NoorColor.accentPrimary)
                }
                .accessibilityLabel("Reset")
            }
        }
    }
}

struct DhikrCard: View {
    let dhikr: Dhikr
    let done: Int
    let onTap: () -> Void

    private var isComplete: Bool { done >= dhikr.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Inside RTL, .leading is the right edge — where Arabic starts.
            Text(dhikr.text)
                .font(.system(size: 19))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if isComplete {
                    Label {
                        Text("Done")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
                } else {
                    Text(verbatim: "\(done) / \(dhikr.count)")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Spacer()
                if dhikr.count > 1 {
                    Text("Repeat \(dhikr.count)×")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.accentGold)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isComplete ? NoorColor.stateReciting : NoorColor.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isComplete ? NoorColor.accentPrimary.opacity(0.4) : NoorColor.inkPrimary.opacity(0.06),
                        lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeInOut(duration: 0.2), value: done)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dhikr.text)
        .accessibilityValue("\(done) of \(dhikr.count)")
        .accessibilityAddTraits(.isButton)
    }
}

/// Free tasbih: tap the big dial; gentle haptic every 33.
struct TasbihView: View {
    @AppStorage("tasbih.count") private var count = 0

    var body: some View {
        VStack(spacing: 34) {
            Spacer()
            Button {
                count += 1
                #if os(iOS)
                if count % 33 == 0 {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                #endif
            } label: {
                ZStack {
                    Circle()
                        .fill(NoorColor.accentPrimary.opacity(0.1))
                    Circle()
                        .trim(from: 0, to: CGFloat(count % 33) / 33)
                        .stroke(NoorColor.accentGold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(verbatim: "\(count)")
                            .font(.system(size: 64, weight: .semibold).monospacedDigit())
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: "\(count / 33) × ٣٣")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .frame(width: 260, height: 260)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Count")
            .accessibilityValue("\(count)")

            Button {
                count = 0
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoorColor.inkSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Tasbih"))
    }
}

#Preview {
    NavigationStack { AthkarView() }
}
