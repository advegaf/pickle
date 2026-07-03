#if DEBUG
import SwiftUI

/// DEBUG-only preview of every widget family, rendered with the exact Shared/WidgetViews code the
/// widget extension uses, so the layouts can be screenshot-verified in the simulator without adding
/// the widgets to the springboard by hand. Reachable via `--open widgets`.
///
/// Caveat: lock-screen (accessory) families render here in full color; on the real Lock Screen they
/// render monochrome/vibrant. This view checks LAYOUT, not the monochrome pass.
struct WidgetGallery: View {
    let snapshot: DiarySnapshot

    private let widgetCorner: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Widget gallery").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)

                group("Calories - Home") {
                    homeTile("Small", 158, 158) { CalorieHome(snap: snapshot, small: true) }
                    homeTile("Medium", 338, 158) { CalorieHome(snap: snapshot, small: false) }
                    homeTile("Large", 338, 354) { CalorieLarge(snap: snapshot) }
                }

                group("Calories - Lock") {
                    lockTile("Circular", 76, 76) { CalorieCircular(snap: snapshot) }
                    lockTile("Rectangular", 170, 76) { CalorieRectangular(snap: snapshot) }
                    lockTile("Inline", 200, 30) { CalorieInline(snap: snapshot).foregroundStyle(.white) }
                }

                group("Macros - Home") {
                    homeTile("Small", 158, 158) { MacrosHome(snap: snapshot, small: true) }
                    homeTile("Medium", 338, 158) { MacrosHome(snap: snapshot, small: false) }
                }

                group("Macros - Lock") {
                    lockTile("Circular", 76, 76) { MacrosCircular(snap: snapshot) }
                    lockTile("Rectangular", 170, 76) { MacrosRectangular(snap: snapshot) }
                }
            }
            .padding(20)
        }
        .background(Color(white: 0.08).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased()).font(.system(size: 11, weight: .medium)).tracking(1.5).foregroundStyle(.gray)
            content()
        }
    }

    private func homeTile(_ label: String, _ w: CGFloat, _ h: CGFloat,
                          @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 10)).foregroundStyle(.gray)
            content()
                .frame(width: w, height: h)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: widgetCorner))
        }
    }

    private func lockTile(_ label: String, _ w: CGFloat, _ h: CGFloat,
                          @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 10)).foregroundStyle(.gray)
            content()
                .frame(width: w, height: h)
                .padding(8)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
#endif
