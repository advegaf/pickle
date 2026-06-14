import Foundation

/// A bundled nutrition guide.
struct Article: Identifiable, Decodable, Equatable, Hashable {
    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let readMins: Int
    let body: [String]

    static let all: [Article] = {
        guard let url = Bundle.main.url(forResource: "articles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([Article].self, from: data) else { return [] }
        return items
    }()
}

/// A curated collection that opens as a pre-filtered food search.
struct FoodCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    /// The query the collection seeds the search with.
    let query: String

    static let all: [FoodCollection] = [
        .init(id: "high-protein", title: "High Protein", subtitle: "Anchor your plate", query: "chicken"),
        .init(id: "breakfast", title: "Breakfast", subtitle: "Start strong", query: "egg"),
        .init(id: "smart-snacks", title: "Smart Snacks", subtitle: "Between meals", query: "yogurt"),
        .init(id: "lean-protein", title: "Lean Protein", subtitle: "Low fat, high return", query: "tuna"),
        .init(id: "whole-grains", title: "Whole Grains", subtitle: "Steady energy", query: "rice"),
        .init(id: "greens", title: "Greens", subtitle: "Volume for free", query: "broccoli"),
    ]
}

/// Food categories that seed a search.
enum FoodCategory: String, CaseIterable, Identifiable {
    case fruit = "Fruit"
    case vegetables = "Vegetables"
    case meat = "Meat"
    case seafood = "Seafood"
    case dairy = "Dairy"
    case grains = "Grains"
    case nuts = "Nuts & Seeds"
    case drinks = "Drinks"
    case snacks = "Snacks"
    case fastFood = "Fast Food"

    var id: String { rawValue }

    var query: String {
        switch self {
        case .fruit: return "apple"
        case .vegetables: return "broccoli"
        case .meat: return "chicken"
        case .seafood: return "salmon"
        case .dairy: return "milk"
        case .grains: return "rice"
        case .nuts: return "almonds"
        case .drinks: return "juice"
        case .snacks: return "protein bar"
        case .fastFood: return "burger"
        }
    }
}
