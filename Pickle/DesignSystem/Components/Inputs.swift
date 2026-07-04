import SwiftUI

// MARK: - Editorial underline field (onboarding)

/// Floating-label underline input. Label rests on the baseline when empty, floats up
/// when focused or filled. Underline brightens on focus. Beautiful, used where entry is rare.
struct UnderlineField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool
    private var floated: Bool { focused || !text.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ZStack(alignment: .leading) {
                Text(label)
                    .font(floated ? PickleFont.label(11) : PickleFont.body(17))
                    .foregroundStyle(floated ? Palette.tertiary : Palette.secondary)
                    .offset(y: floated ? -20 : 0)
                    .animation(Motion.easeOut, value: floated)

                TextField("", text: $text)
                    .font(PickleFont.body(17))
                    .foregroundStyle(Palette.primary)
                    .tint(Palette.accent)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .focused($focused)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
            }
            .frame(height: 24)
            .padding(.top, 12)

            Rectangle()
                .fill(focused ? Palette.accent : Palette.hairline)
                .frame(height: 1)
                .animation(Motion.easeOut, value: focused)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(text)
    }
}

// MARK: - Utility numeric stepper (hot paths: Quick Add, portion)

/// Large-target numeric entry with − / + steppers and a tappable value. Tabular numerals,
/// numeric keypad. Built for speed where the editorial field would be too slow.
struct UtilityStepper: View {
    let label: String
    @Binding var value: Int
    var step: Int = 1
    var range: ClosedRange<Int> = 0...100_000
    var unit: String = ""

    @FocusState private var focused: Bool
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionLabel(text: label)
            HStack(spacing: Spacing.m) {
                stepButton(.minus) { set(value - step) }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("0", text: $draft)
                        .font(PickleFont.stat(28))
                        .foregroundStyle(Palette.primary)
                        .monospacedDigit()
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .fixedSize()
                        .frame(minWidth: 56)
                        .onChange(of: draft) { _, new in
                            let filtered = new.filter(\.isNumber)
                            if filtered != new { draft = filtered }
                            if let n = Int(filtered) { value = min(max(n, range.lowerBound), range.upperBound) }
                            else if filtered.isEmpty { value = range.lowerBound }
                        }
                    if !unit.isEmpty {
                        Text(unit)
                            .font(PickleFont.caption())
                            .foregroundStyle(Palette.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)

                stepButton(.add) { set(value + step) }
            }
        }
        .onAppear { draft = value == 0 ? "" : String(value) }
        .onChange(of: value) { _, new in
            let s = new == 0 ? "" : String(new)
            if s != draft { draft = s }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(value + step)
            case .decrement: set(value - step)
            default: break
            }
        }
    }

    private func set(_ n: Int) {
        value = min(max(n, range.lowerBound), range.upperBound)
        Haptics.select()
    }

    private func stepButton(_ glyph: Glyph, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PickleIcon(glyph, size: 16)
                .foregroundStyle(Palette.primary)
                .frame(width: 44, height: 44)
                .background(Palette.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Validation row (password checklist; reused for any rule list)

struct ValidationRow: View {
    let text: String
    let satisfied: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            PickleIcon(satisfied ? .check : .close, size: 11)
                .foregroundStyle(satisfied ? Palette.success : Palette.tertiary)
                .frame(width: 14)
            Text(text)
                .font(PickleFont.caption())
                .foregroundStyle(satisfied ? Palette.secondary : Palette.tertiary)
        }
        .animation(Motion.easeOut, value: satisfied)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text), \(satisfied ? "met" : "not met")")
    }
}

#Preview {
    StatefulPreview()
}

private struct StatefulPreview: View {
    @State var name = ""
    @State var kcal = 250
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: Spacing.xxl) {
                UnderlineField(label: "First name", text: $name)
                UtilityStepper(label: "Calories", value: $kcal, step: 10, unit: "cal")
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ValidationRow(text: "One number", satisfied: true)
                    ValidationRow(text: "8 characters minimum", satisfied: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.screen)
        }
    }
}
