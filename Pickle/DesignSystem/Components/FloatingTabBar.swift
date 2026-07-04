import SwiftUI

/// A tab in the floating bar. `icon` is a Hugeicons glyph; glyph-only (the accessibility
/// label carries the name).
struct PickleTabItem: Identifiable, Equatable {
    let id: Int
    let icon: Glyph
    let label: String
}

/// The Glow shell: one floating Liquid Glass pill holding the raised white Log circle
/// (leading, the reference position) and the five tab glyphs. Active glyph is teal,
/// inactive is `secondary` (`faint` fails WCAG for interactive glyphs). The bar is
/// supplied to content via `safeAreaInset`, so every tab clears it by construction.
struct FloatingTabBar: View {
    let items: [PickleTabItem]
    @Binding var selection: Int
    let onLog: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            logButton
            ForEach(items) { item in
                tab(item)
            }
        }
        .padding(6)
        .glassEffect(.regular, in: .capsule)
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.02)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
    }

    private var logButton: some View {
        Button(action: onLog) {
            PickleIcon(.add, size: 22)
                .foregroundStyle(Palette.onAccent)
                .frame(width: 52, height: 52)
                .background(Circle().fill(.white))
                .shadow(color: .black.opacity(0.30), radius: 10, y: 4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Log food")
        .accessibilityAddTraits(.isButton)
    }

    private func tab(_ item: PickleTabItem) -> some View {
        let active = item.id == selection
        return Button {
            if selection != item.id {
                selection = item.id
                Haptics.select()
            }
        } label: {
            PickleIcon(item.icon, size: 23)
                .foregroundStyle(active ? Palette.primary : Palette.secondary)
                .frame(width: 44, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

extension PickleTabItem {
    /// The app's five tabs, in order.
    static let pickleTabs: [PickleTabItem] = [
        .init(id: 0, icon: .home, label: "Home"),
        .init(id: 1, icon: .explore, label: "Explore"),
        .init(id: 2, icon: .coach, label: "Coach"),
        .init(id: 3, icon: .activity, label: "Activity"),
        .init(id: 4, icon: .more, label: "More"),
    ]
}

#Preview {
    StatefulBarPreview()
}

private struct StatefulBarPreview: View {
    @State var sel = 0
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack {
                Spacer()
                FloatingTabBar(items: PickleTabItem.pickleTabs, selection: $sel) {}
                    .padding(.horizontal, Spacing.screen + 8)
            }
        }
    }
}
