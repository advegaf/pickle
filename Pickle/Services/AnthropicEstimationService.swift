import Foundation
import UIKit

/// Direct Anthropic Messages API client for meal estimation. Swift has no official Anthropic
/// SDK, so this is raw HTTPS via URLSession (the documented path for unsupported languages).
/// Testing only: the key is embedded in the binary. Production routes through the proxy.
///
/// Uses claude-sonnet-4-6 with vision and a structured json_schema output, then decodes ONCE
/// after the full response (no streaming) and hands the items to the existing sanity gate.
struct AnthropicEstimationService: AIEstimating {
    var apiKey: String = AppConfig.anthropicKey
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    func estimate(text: String) async throws -> [AIFoodItem] {
        let prompt = "A person ate the following. Identify each distinct food and estimate its calories and macros for the portion described.\n\n\(text)"
        return try await send(content: [["type": "text", "text": prompt]])
    }

    func estimate(imageJPEG: Data) async throws -> [AIFoodItem] {
        let data = Self.downscaledJPEG(imageJPEG)
        let base64 = data.base64EncodedString()
        let content: [[String: Any]] = [
            ["type": "image",
             "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]],
            ["type": "text",
             "text": "Identify each distinct food in this photo and estimate its calories and macros for the portion shown. If it is not food, return an empty items array."],
        ]
        return try await send(content: content)
    }

    // MARK: - Request

    private func send(content: [[String: Any]]) async throws -> [AIFoodItem] {
        guard AppConfig.hasAnthropicKey else { throw AIEstimationError.unavailable }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": "You are a precise nutrition estimator. Estimate per-item calories and macro grams (protein, carbs, fat) for the portion shown. Set confidence between 0 and 1, lower when the portion or contents are ambiguous.",
            "messages": [["role": "user", "content": content]],
            "output_config": ["format": ["type": "json_schema", "schema": Self.schema]],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIEstimationError.network
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIEstimationError.network
        }
        return try decode(data)
    }

    // MARK: - Response

    private struct Envelope: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
        let stop_reason: String?
    }
    private struct Items: Decodable {
        struct Item: Decodable {
            let name: String; let portion: String?
            let kcal: Int; let protein: Int; let carbs: Int; let fat: Int
            let confidence: Double?
        }
        let items: [Item]
    }

    private func decode(_ data: Data) throws -> [AIFoodItem] {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            throw AIEstimationError.couldNotRead
        }
        if envelope.stop_reason == "refusal" { throw AIEstimationError.couldNotRead }
        guard let jsonText = envelope.content.first(where: { $0.type == "text" })?.text,
              let payload = try? JSONDecoder().decode(Items.self, from: Data(jsonText.utf8)),
              !payload.items.isEmpty else {
            throw AIEstimationError.couldNotRead
        }
        return payload.items.map {
            AIFoodItem(name: $0.name,
                       portion: $0.portion ?? "1 serving",
                       macros: MacroTargets(kcal: max($0.kcal, 0),
                                            proteinG: max($0.protein, 0),
                                            carbsG: max($0.carbs, 0),
                                            fatG: max($0.fat, 0)),
                       confidence: min(max($0.confidence ?? 0.8, 0), 1))
        }
    }

    // MARK: - Helpers

    private static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["items"],
        "properties": [
            "items": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["name", "portion", "kcal", "protein", "carbs", "fat", "confidence"],
                    "properties": [
                        "name": ["type": "string"],
                        "portion": ["type": "string"],
                        "kcal": ["type": "integer"],
                        "protein": ["type": "integer"],
                        "carbs": ["type": "integer"],
                        "fat": ["type": "integer"],
                        "confidence": ["type": "number"],
                    ],
                ],
            ],
        ],
    ]

    /// Resize to about 1024px on the long edge and re-encode JPEG to bound vision tokens.
    static func downscaledJPEG(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let longEdge = max(image.size.width, image.size.height)
        guard longEdge > maxDimension else {
            return image.jpegData(compressionQuality: quality) ?? data
        }
        let scale = maxDimension / longEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}
