import SwiftUI

/// The app's icon set, backed by Hugeicons (free "Stroke Rounded" pack, MIT-licensed via
/// `@hugeicons/core-free-icons`). Icons ship as template-rendering vector PDFs in the asset
/// catalog, so they tint to the ambient foreground color and scale crisply. This enum is the
/// single source of truth for every glyph, so the whole set can be re-skinned in one place.
enum Glyph {
    // Tab bar
    case home, explore, coach, activity, more
    // Actions / nav
    case search, close, closeCircle, check, checkCircle, add, minus
    case chevronRight, chevronLeft, arrowRight, arrowDownRight, sort
    // Content
    case favorite, health, camera, scan, share, edit, shield, alert, delete
    // Distinct nav-row glyphs (Lucide, same rounded-stroke family) so rows never reuse a tab glyph.
    case goal, pulse, bookmark

    /// The Hugeicons asset name in the catalog.
    var asset: String {
        switch self {
        case .home: return "home01"
        case .explore: return "dashboard-square01"
        case .coach: return "analytics01"
        case .activity: return "fire"
        case .more: return "menu01"
        case .search: return "search01"
        case .close: return "cancel01"
        case .closeCircle: return "cancel-circle"
        case .check: return "tick02"
        case .checkCircle: return "checkmark-circle01"
        case .add: return "add01"
        case .minus: return "minus-sign"
        case .chevronRight: return "arrow-right01"
        case .chevronLeft: return "arrow-left01"
        case .arrowRight: return "arrow-right01"
        case .arrowDownRight: return "arrow-down-right01"
        case .sort: return "arrow-up-down"
        case .favorite: return "favourite"
        case .health: return "heart-check"
        case .camera: return "camera01"
        case .scan: return "barcode-scan"
        case .share: return "upload03"
        case .edit: return "pencil-edit01"
        case .shield: return "security-lock"
        case .alert: return "alert-circle"
        case .delete: return "delete02"
        case .goal: return "target"
        case .pulse: return "activity"
        case .bookmark: return "bookmark"
        }
    }
}

/// Renders a `Glyph` as a tintable template image at a given point size. Tinted by the ambient
/// `foregroundStyle`. Drop-in replacement for `Image(systemName:).font(.system(size:))`.
struct PickleIcon: View {
    let glyph: Glyph
    var size: CGFloat

    init(_ glyph: Glyph, size: CGFloat = 20) {
        self.glyph = glyph
        self.size = size
    }

    var body: some View {
        Image(glyph.asset)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
