import SwiftUI

/// The Activity calendar's day cell. Five visually-distinct, VoiceOver-labelled states,
/// readable at ~32pt. `isToday` is orthogonal (adds the ring) so "today + logged" still reads.
struct CalendarDayCircle: View {
    enum DayState {
        case future    // upcoming, faintest
        case empty     // past, nothing logged
        case logged    // logged, missed the goal
        case goalHit   // logged and hit the goal
    }

    let day: Int
    let state: DayState
    var isToday: Bool = false
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            background
            if state == .goalHit {
                PickleIcon(.check, size: size * 0.44)
                    .foregroundStyle(Palette.onAccent)
            } else {
                Text("\(day)")
                    .font(PickleFont.font(.medium, size * 0.36, relativeTo: .footnote))
                    .foregroundStyle(numberColor)
                    .monospacedDigit()
            }
            if state == .logged {
                // Accent dot marks a logged day, echoing the Home week strip.
                Circle()
                    .fill(Palette.accent)
                    .frame(width: max(3, size * 0.1), height: max(3, size * 0.1))
                    .offset(y: size * 0.28)
            }
            if isToday {
                Circle().stroke(Palette.accent, lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var background: some View {
        switch state {
        case .future:
            Circle().stroke(Palette.faint.opacity(0.35), lineWidth: 1)
        case .empty:
            Circle().stroke(Palette.faint.opacity(0.7), lineWidth: 1)
        case .logged:
            Circle().fill(Palette.surfaceRaised)
        case .goalHit:
            Circle().fill(Palette.accent)
        }
    }

    private var numberColor: Color {
        switch state {
        case .future: return Palette.faint
        case .empty: return Palette.secondary
        case .logged: return Palette.primary
        case .goalHit: return Palette.onAccent
        }
    }

    private var accessibilityText: String {
        let base = "Day \(day)"
        let status: String
        switch state {
        case .future: status = "upcoming"
        case .empty: status = "not logged"
        case .logged: status = "logged"
        case .goalHit: status = "logged, goal met"
        }
        return isToday ? "\(base), today, \(status)" : "\(base), \(status)"
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: Spacing.xl) {
            HStack(spacing: Spacing.l) {
                CalendarDayCircle(day: 8, state: .goalHit)
                CalendarDayCircle(day: 9, state: .logged)
                CalendarDayCircle(day: 11, state: .logged, isToday: true)
                CalendarDayCircle(day: 12, state: .empty)
                CalendarDayCircle(day: 20, state: .future)
            }
            HStack(spacing: Spacing.l) {
                ForEach(["Goal met", "Logged", "Today", "Missed", "Upcoming"], id: \.self) {
                    Text($0).font(PickleFont.caption(10)).foregroundStyle(Palette.tertiary).frame(width: 36)
                }
            }
        }
    }
}
