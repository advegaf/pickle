import Foundation

protocol FoodSearching: Sendable {
    func search(_ query: String) async -> [FoodCandidate]
    func lookup(barcode: String) async -> FoodCandidate?
}

/// Open Food Facts client. OFF data is crowdsourced and inconsistent (numbers as strings,
/// missing fields, per-100g-only entries), so parsing is deliberately defensive via
/// JSONSerialization + numeric coercion rather than strict Codable. Results are sanitized by
/// `FoodRanking` before they reach the UI. USDA lives behind the proxy and is skipped here
/// until the proxy exists.
struct FoodSearchService: FoodSearching {
    var session: URLSession = .shared
    private let base = "https://world.openfoodfacts.org"

    func search(_ query: String) async -> [FoodCandidate] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        guard var comps = URLComponents(string: "\(base)/cgi/search.pl") else { return [] }
        comps.queryItems = [
            .init(name: "search_terms", value: q),
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: "25"),
            .init(name: "fields", value: "product_name,brands,code,nutriments,serving_quantity"),
        ]
        guard let url = comps.url else { return [] }
        guard let data = await fetch(url) else { return [] }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = obj["products"] as? [[String: Any]] else { return [] }
        return products.compactMap(Self.parse)
    }

    func lookup(barcode: String) async -> FoodCandidate? {
        let code = barcode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty,
              let url = URL(string: "\(base)/api/v2/product/\(code).json?fields=product_name,brands,code,nutriments,serving_quantity")
        else { return nil }
        guard let data = await fetch(url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard (obj["status"] as? Int) == 1 || obj["product"] != nil,
              let product = obj["product"] as? [String: Any] else { return nil }
        var parsed = Self.parse(product)
        if parsed?.barcode == nil { parsed?.barcode = code }
        return parsed
    }

    private func fetch(_ url: URL) async -> Data? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("Pickle/0.1 (iOS; contact@pickle.app)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
            return data
        } catch {
            return nil
        }
    }

    static func parse(_ p: [String: Any]) -> FoodCandidate? {
        let name = (p["product_name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else { return nil }
        let brand = (p["brands"] as? String)?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) }
        let code = p["code"] as? String
        let nutr = p["nutriments"] as? [String: Any] ?? [:]

        func num(_ key: String) -> Double? {
            if let d = nutr[key] as? Double { return d }
            if let n = nutr[key] as? NSNumber { return n.doubleValue }
            if let s = nutr[key] as? String { return Double(s) }
            return nil
        }
        guard let kcal = num("energy-kcal_100g") ?? num("energy_100g").map({ $0 / 4.184 }) else { return nil }
        let serving = (p["serving_quantity"] as? NSNumber)?.doubleValue
            ?? Double((p["serving_quantity"] as? String) ?? "")

        let nutrition = FoodNutrition(
            kcalPer100: kcal,
            proteinPer100: num("proteins_100g") ?? 0,
            carbsPer100: num("carbohydrates_100g") ?? 0,
            fatPer100: num("fat_100g") ?? 0,
            servingGrams: serving)

        return FoodCandidate(name: name, brand: brand?.isEmpty == true ? nil : brand,
                             source: .off, sourceID: code ?? name, barcode: code, nutrition: nutrition)
    }
}
