import SwiftUI

/// A tab in the custom bar. `icon` is an SF Symbol rendered at a thin weight to echo
/// the reference's hairline glyphs.
struct PickleTabItem: Identifiable, Equatable {
    let id: Int
    let icon: String
    let label: String
}

/// Custom 5-item tab bar — thin-stroke icons, white when active, gray when not, on a
/// black bar with a top hairline. A selection change fires a selection haptic.
struct PickleTabBar: View {
    let items: [PickleTabItem]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let active = item.id == selection
                Button {
                    if selection != item.id {
                        selection = item.id
                        Haptics.select()
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: active ? .regular : .light))
                            .symbolVariant(active ? .fill : .none)
                        Text(item.label)
                            .font(PickleFont.caption(10))
                    }
                    .foregroundStyle(active ? Palette.primary : Palette.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.xs)
        .background(
            Palette.background
                .overlay(Palette.hairline.frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

extension PickleTabItem {
    /// The app's five tabs, in order.
    static let pickleTabs: [PickleTabItem] = [
        .init(id: 0, icon: "house", label: "Home"),
        .init(id: 1, icon: "rhombus", label: "Explore"),
        .init(id: 2, icon: "stopwatch", label: "Coach"),
        .init(id: 3, icon: "circle.hexagonpath", label: "Activity"),
        .init(id: 4, icon: "ellipsis", label: "More"),
    ]
}

#Preview {
    StatefulTabPreview()
}

private struct StatefulTabPreview: View {
    @State var sel = 0
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack {
                Spacer()
                PickleTabBar(items: PickleTabItem.pickleTabs, selection: $sel)
            }
        }
    }
}
