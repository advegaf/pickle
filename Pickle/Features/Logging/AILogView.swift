import SwiftUI
import PhotosUI

/// Describe a meal in words or snap a photo; the model returns an itemized estimate you can
/// edit before logging. Low-confidence / implausible items are flagged and must be confirmed
///, never silently added (the sanity gate protects the adaptive plan).
struct AILogView: View {
    @EnvironmentObject private var store: PickleStore
    let onConfirm: () -> Void

    @State private var text = ""
    @State private var meal: MealSlot = .current
    @State private var phase: Phase = .input
    @State private var thinkingDone = false
    @State private var items: [AIFoodItem] = []
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var focused: Bool

    private let service = AIEstimation.make()

    enum Phase: Equatable { case input, thinking, review, failed(String) }

    var body: some View {
        Group {
            switch phase {
            case .input: inputState
            case .thinking: thinkingState
            case .review: reviewState
            case .failed(let message): failedState(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    // MARK: Input

    private var inputState: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("Describe your meal, or add a photo.")
                .font(PickleFont.bodyMedium(16))
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, Spacing.screen)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("e.g. chipotle bowl with double chicken, brown rice, guac")
                        .font(PickleFont.body(16))
                        .foregroundStyle(Palette.faint)
                        .padding(Spacing.m)
                }
                TextEditor(text: $text)
                    .font(PickleFont.body(16))
                    .foregroundStyle(Palette.primary)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.s)
                    .focused($focused)
            }
            .frame(height: 120)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .padding(.horizontal, Spacing.screen)

            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: Spacing.s) {
                    PickleIcon(.camera, size: 17)
                    Text("Add a photo")
                }
                .font(PickleFont.button(15))
                .foregroundStyle(Palette.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(RoundedRectangle(cornerRadius: Radius.button)
                    .stroke(Palette.primary.opacity(0.4), lineWidth: 1))
            }
            .padding(.horizontal, Spacing.screen)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await runPhoto(item) }
            }

            MealRowPicker(meal: $meal).padding(.horizontal, Spacing.screen)

            Spacer()
            Text("AI estimates are approximate, not medical or dietary advice.")
                .font(PickleFont.caption(12))
                .foregroundStyle(Palette.tertiary)
                .padding(.horizontal, Spacing.screen)
            PrimaryButton(title: "Estimate", enabled: !text.trimmingCharacters(in: .whitespaces).isEmpty) {
                Task { await runText() }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.m)
        }
        .padding(.top, Spacing.m)
        .onAppear {
            focused = true
            #if DEBUG
            if LaunchOptions.open == "ai" && text.isEmpty {
                text = "chicken bowl with rice and vegetables"
                Task { await runText() }
            }
            #endif
        }
    }

    private var thinkingState: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            DotLoader(size: 52, dot: 11, done: thinkingDone)
            Text(thinkingDone ? "Done" : "Estimating your meal…")
                .font(PickleFont.body(15)).foregroundStyle(Palette.secondary)
            Spacer()
        }
    }

    // MARK: Review

    private var reviewState: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    HStack {
                        Eyebrow(text: "Estimated   \(items.count) items")
                        Spacer()
                        Text("\(totalKcal) cal")
                            .font(PickleFont.bodyMedium(15))
                            .foregroundStyle(Palette.primary)
                            .monospacedDigit()
                    }
                    ForEach($items) { $item in
                        AIItemCard(item: $item)
                    }
                    if items.contains(where: \.needsReview) {
                        Text("Items marked “review” looked uncertain, tap to confirm before logging.")
                            .font(PickleFont.caption())
                            .foregroundStyle(Palette.tertiary)
                    }
                    MealRowPicker(meal: $meal)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.m)
                .padding(.bottom, 120)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Add \(confirmedCount) to log", enabled: confirmedCount > 0) { addAll() }
                    .padding(.horizontal, Spacing.screen)
                    .padding(.vertical, Spacing.m)
                    .background(Palette.background)
            }
        }
    }

    private func failedState(_ message: String) -> some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            PickleIcon(.alert, size: 36)
                .foregroundStyle(Palette.tertiary)
            Text(message)
                .font(PickleFont.bodyMedium(16)).foregroundStyle(Palette.primary)
                .multilineTextAlignment(.center)
            SecondaryButton(title: "Try again") { phase = .input }
                .frame(maxWidth: 220)
            Spacer()
        }
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: Logic

    private var totalKcal: Int { items.filter { !$0.needsReview }.reduce(0) { $0 + $1.macros.kcal } }
    private var confirmedCount: Int { items.filter { !$0.needsReview }.count }

    private func runText() async {
        focused = false
        phase = .thinking
        do {
            let raw = try await service.estimate(text: text)
            items = AIEstimation.applySanity(raw)
            await finishThinking()
        } catch {
            phase = .failed(message(for: error))
        }
    }

    /// Play the loader's converge-to-one, then reveal the results.
    private func finishThinking() async {
        withAnimation { thinkingDone = true }
        try? await Task.sleep(for: .milliseconds(450))
        phase = .review
        thinkingDone = false
    }

    private func runPhoto(_ item: PhotosPickerItem) async {
        phase = .thinking
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                phase = .failed("Couldn't read that photo. Try again or describe it.")
                return
            }
            let raw = try await service.estimate(imageJPEG: data)
            items = AIEstimation.applySanity(raw)
            await finishThinking()
        } catch {
            phase = .failed(message(for: error))
        }
    }

    private func message(for error: Error) -> String {
        switch error as? AIEstimationError {
        case .unavailable: return "AI logging isn't set up yet. Log manually for now."
        case .couldNotRead: return "Couldn't read that, try again or describe it in words."
        default: return "AI is unavailable right now. Log manually for now."
        }
    }

    private func addAll() {
        for item in items where !item.needsReview {
            store.log(item.candidate(), amount: 1, unit: .serving, meal: meal, macros: item.macros)
        }
        Haptics.celebrate()
        onConfirm()
    }
}

/// Editable estimated-item card with a confidence dot and a review toggle.
struct AIItemCard: View {
    @Binding var item: AIFoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Circle()
                    .fill(item.needsReview ? Palette.tertiary : Palette.success)
                    .frame(width: 7, height: 7)
                Text(item.name)
                    .font(PickleFont.bodyMedium(16))
                    .foregroundStyle(Palette.primary)
                Spacer()
                Text("\(item.macros.kcal) cal")
                    .font(PickleFont.caption())
                    .foregroundStyle(Palette.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: Spacing.s) {
                Text(item.portion)
                    .font(PickleFont.caption(12))
                    .foregroundStyle(Palette.tertiary)
                MacroLine(macros: item.macros)
                Spacer()
                if item.needsReview {
                    Button { item.needsReview = false; Haptics.select() } label: {
                        Text("Confirm")
                            .font(PickleFont.button(12))
                            .foregroundStyle(Palette.background)
                            .padding(.horizontal, Spacing.m)
                            .frame(height: 28)
                            .background(Palette.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(Spacing.m)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(item.needsReview ? Palette.tertiary.opacity(0.4) : .clear, lineWidth: 1)
        )
        .opacity(item.needsReview ? 0.85 : 1)
    }
}
