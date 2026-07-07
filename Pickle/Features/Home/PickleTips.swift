import TipKit

/// First-run contextual tips: Apple's real TipKit popovers (genuine system Liquid
/// Glass material + native pointer arrow), shown one at a time in order. Standard
/// TipKit dismissal applies - an outside tap, tapping the anchor, or the X all close
/// the current tip, exactly like any other app's tips. Gated behind onboarding via a
/// shared parameter so nothing pops during setup. Reset alongside "Delete all my
/// data" (Tips.resetDatastore in AboutView).
enum PickleTipsGate {
    /// Flipped true the first time Home appears with onboarding complete.
    @Parameter static var onboarded: Bool = false
}

struct LogButtonTip: Tip {
    var title: Text { Text("Log anything in seconds") }
    var message: Text? { Text("Search, scan, describe it, or snap a photo - from any tab.") }
    var rules: [Rule] { #Rule(PickleTipsGate.$onboarded) { $0 == true } }
}

struct GaugeTip: Tip {
    var title: Text { Text("Your day at a glance") }
    var message: Text? { Text("The arc fills and shifts color as you eat - red only if you go over.") }
    var rules: [Rule] { #Rule(PickleTipsGate.$onboarded) { $0 == true } }
}

struct WeekStripTip: Tip {
    var title: Text { Text("Tap any day") }
    var message: Text? { Text("Swipe back through past weeks; log onto a day you missed.") }
    var rules: [Rule] { #Rule(PickleTipsGate.$onboarded) { $0 == true } }
}

struct PredictedTip: Tip {
    var title: Text { Text("Your usual, predicted") }
    var message: Text? { Text("PICKLE learns your routine - one tap logs your next meal.") }
    var rules: [Rule] { #Rule(PickleTipsGate.$onboarded) { $0 == true } }
}

struct BellTip: Tip {
    var title: Text { Text("Gentle reminders") }
    var message: Text? { Text("Meal nudges that skip anything you already logged.") }
    var rules: [Rule] { #Rule(PickleTipsGate.$onboarded) { $0 == true } }
}
