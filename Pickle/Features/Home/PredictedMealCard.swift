import SwiftUI

/// The signature Glow card: what the app thinks you'll log next, one tap away.
/// With a predicted food it reads "Predicted - 8:00 AM"; with no slot history it
/// becomes a warm first-log nudge instead of vanishing (the empty state teaches
/// the feature).
struct PredictedMealCard: View {
    let prediction: MealPrediction
    /// The moment "now" for the time label (injected so previews/tests are stable).
    var now: Date = Date()
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if let food = prediction.food {
                predictedBody(food)
            } else {
                nudgeBody
            }
        }
        .buttonStyle(.pressable)
    }

    private func predictedBody(_ food: MealPrediction.PredictedFood) -> some View {
        HStack(spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Predicted - \(timeLabel(food.minutesSinceMidnight))")
                    .font(PickleFont.label())
                    .foregroundStyle(Palette.tertiary)
                Text(food.name)
                    .font(PickleFont.bodyMedium(16))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
                Text("\(food.kcal) cal · \(prediction.slot.title)")
                    .font(PickleFont.caption(12))
                    .foregroundStyle(Palette.tertiary)
                    .monospacedDigit()
            }
            Spacer()
            PickleIcon(.add, size: 16)
                .foregroundStyle(Palette.primary)
                .frame(width: 36, height: 36)
                .background(Palette.surfaceRaised)
                .clipShape(Circle())
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 20)
        .opacity(0.92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Predicted \(prediction.slot.title): \(food.name), \(food.kcal) calories, around \(timeLabel(food.minutesSinceMidnight)). Tap to log it.")
    }

    private var nudgeBody: some View {
        HStack(spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Log your first meal")
                    .font(PickleFont.bodyMedium(16))
                    .foregroundStyle(Palette.primary)
                Text("I'll start predicting your usual \(prediction.slot.title.lowercased()) from what you log.")
                    .font(PickleFont.caption(12))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            PickleIcon(.add, size: 16)
                .foregroundStyle(Palette.onAccent)
                .frame(width: 36, height: 36)
                .background(Color.white)
                .clipShape(Circle())
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Log your first meal to start predictions")
    }

    /// "8:00 AM", or "now" once the predicted time has passed.
    private func timeLabel(_ minutes: Int) -> String {
        let cal = Calendar.current
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        if minutes <= nowMinutes { return "now" }
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        guard let date = cal.date(from: comps) else { return "now" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: Spacing.l) {
            PredictedMealCard(
                prediction: MealPrediction(slot: .breakfast, food: .init(
                    canonicalID: "x", name: "Oats with banana", kcal: 320,
                    minutesSinceMidnight: 23 * 60)),
                onTap: {}
            )
            PredictedMealCard(prediction: MealPrediction(slot: .breakfast, food: nil), onTap: {})
        }
        .padding(Spacing.screen)
    }
}
