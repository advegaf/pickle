import Foundation

/// One AI-estimated food item, before it enters the diary.
struct AIFoodItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    var name: String
    var portion: String
    var macros: MacroTargets
    var confidence: Double   // 0...1
    var needsReview: Bool = false

    func candidate() -> FoodCandidate {
        FoodCandidate(name: name, brand: nil, source: .custom,
                      sourceID: "ai:\(id.uuidString)", barcode: nil,
                      nutrition: FoodNutrition(kcalPer100: Double(macros.kcal),
                                               proteinPer100: Double(macros.proteinG),
                                               carbsPer100: Double(macros.carbsG),
                                               fatPer100: Double(macros.fatG), servingGrams: 100))
    }
}

enum AIEstimationError: Error, Equatable { case unavailable, couldNotRead, network }

protocol AIEstimating: Sendable {
    func estimate(text: String) async throws -> [AIFoodItem]
    func estimate(imageJPEG: Data) async throws -> [AIFoodItem]
}

enum AIEstimation {
    /// Real proxy impl when the proxy is configured; otherwise the realistic mock so the
    /// whole flow works end-to-end in development.
    static func make() -> AIEstimating {
        AppConfig.hasProxy ? ProxyAIEstimationService() : MockAIEstimationService()
    }

    /// The sanity gate. Garbage must never auto-enter the diary and poison the adaptive plan.
    /// kcal in [0, 4000]/item, macro-implied kcal within ~20%, and low confidence → review.
    static func applySanity(_ items: [AIFoodItem]) -> [AIFoodItem] {
        items.map { item in
            var it = item
            let m = item.macros
            let implied = Double(m.proteinG) * 4 + Double(m.carbsG) * 4 + Double(m.fatG) * 9
            let kcalOutOfRange = m.kcal < 0 || m.kcal > 4000
            let inconsistent = implied > 0 && abs(Double(m.kcal) - implied) / implied > 0.2
            it.needsReview = kcalOutOfRange || inconsistent || item.confidence < 0.6
            return it
        }
    }
}

/// Calls the proxy (which holds the Anthropic key + does the vision call) and decodes ONCE
/// after the response completes — never per streaming delta, which would always throw on
/// partial JSON. Inert until `PICKLE_PROXY_URL` is set.
struct ProxyAIEstimationService: AIEstimating {
    func estimate(text: String) async throws -> [AIFoodItem] {
        try await post(body: ["text": text])
    }
    func estimate(imageJPEG: Data) async throws -> [AIFoodItem] {
        try await post(body: ["image_base64": imageJPEG.base64EncodedString()])
    }

    private func post(body: [String: Any]) async throws -> [AIFoodItem] {
        guard AppConfig.hasProxy, let url = URL(string: AppConfig.proxyURL + "/estimate") else {
            throw AIEstimationError.unavailable
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw AIEstimationError.network
            }
            return try decode(data)
        } catch is AIEstimationError {
            throw AIEstimationError.network
        } catch {
            throw AIEstimationError.network
        }
    }

    private struct Payload: Decodable {
        struct Item: Decodable { let name: String; let portion: String?
            let kcal: Int; let protein: Int; let carbs: Int; let fat: Int; let confidence: Double? }
        let items: [Item]
    }

    private func decode(_ data: Data) throws -> [AIFoodItem] {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw AIEstimationError.couldNotRead
        }
        guard !payload.items.isEmpty else { throw AIEstimationError.couldNotRead }
        return payload.items.map {
            AIFoodItem(name: $0.name, portion: $0.portion ?? "1 serving",
                       macros: MacroTargets(kcal: $0.kcal, proteinG: $0.protein,
                                            carbsG: $0.carbs, fatG: $0.fat),
                       confidence: $0.confidence ?? 0.8)
        }
    }
}
