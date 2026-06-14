import SwiftUI
import VisionKit

/// Barcode scanning via VisionKit. On a device this opens the live camera with a reticle,
/// looks the barcode up in Open Food Facts, and routes to Food detail. Barcode-not-found is
/// common (OFF is crowdsourced), so that path offers a manual fallback rather than dead-ends.
struct ScanView: View {
    let onFound: (FoodCandidate) -> Void
    let onManual: () -> Void

    @State private var status: Status = .idle
    private let service = FoodSearchService()

    enum Status: Equatable {
        case idle, looking, notFound(String), unsupported
    }

    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                BarcodeScanner { code in handle(code) }
                    .ignoresSafeArea(edges: .bottom)
                reticleOverlay
            } else {
                unsupportedState
            }

            switch status {
            case .looking:
                lookingOverlay
            case .notFound(let code):
                notFoundOverlay(code)
            default:
                EmptyView()
            }
        }
    }

    private var reticleOverlay: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.primary.opacity(0.9), lineWidth: 2)
                .frame(width: 260, height: 150)
            Text("Point at a barcode")
                .font(PickleFont.caption())
                .foregroundStyle(Palette.primary.opacity(0.9))
                .padding(.top, Spacing.m)
            Spacer()
        }
    }

    private var lookingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: Spacing.m) {
                DotLoader(size: 44, dot: 10)
                Text("Looking it up…").font(PickleFont.body(15)).foregroundStyle(Palette.primary)
            }
        }
    }

    private func notFoundOverlay(_ code: String) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                Text("We don't have this one yet.")
                    .font(PickleFont.heading(20)).foregroundStyle(Palette.primary)
                    .multilineTextAlignment(.center)
                Text("Barcode \(code) isn't in the database. Add it as a custom food.")
                    .font(PickleFont.body(14)).foregroundStyle(Palette.tertiary)
                    .multilineTextAlignment(.center)
                VStack(spacing: Spacing.s) {
                    PrimaryButton(title: "Add manually") { onManual() }
                    SecondaryButton(title: "Scan again") { status = .idle }
                }
            }
            .padding(Spacing.xl)
        }
    }

    private var unsupportedState: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Palette.tertiary)
            Text("Scanning needs a camera")
                .font(PickleFont.bodyMedium(17)).foregroundStyle(Palette.primary)
            Text("Barcode scanning works on your iPhone. Search for the food instead here.")
                .font(PickleFont.body(14)).foregroundStyle(Palette.tertiary)
                .multilineTextAlignment(.center)
            SecondaryButton(title: "Search instead") { onManual() }
                .frame(maxWidth: 240)
            Spacer()
        }
        .padding(.horizontal, Spacing.screen)
    }

    private func handle(_ code: String) {
        guard status == .idle else { return }
        status = .looking
        Haptics.select()
        Task {
            if let candidate = await service.lookup(barcode: code) {
                Haptics.logAdded()
                onFound(candidate)
            } else {
                Haptics.warn()
                status = .notFound(code)
            }
        }
    }
}

/// Thin VisionKit wrapper that reports the first barcode it sees.
struct BarcodeScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        try? scanner.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var fired = false
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !fired else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue {
                    fired = true
                    onScan(payload)
                    break
                }
            }
        }
    }
}
