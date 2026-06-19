import Foundation

/// Natural-language coaching from the user's logging patterns. Same direct-Anthropic path as
/// the food estimator (testing key embedded; production should move behind the proxy). Returns
/// plain text, not structured output.
protocol AICoaching: Sendable {
    func advise(_ summary: String) async throws -> String
}

enum AICoachingError: Error { case unavailable, network, empty }

/// The assembled picture of the user's recent logging, plus a cache key that changes once per
/// day and whenever the underlying numbers move, so advice regenerates at most daily.
struct CoachingSummary: Sendable {
    /// The natural-language brief handed to the coach.
    let text: String
    /// Identity of the data behind `text`; cached advice is reused while this is unchanged.
    let cacheKey: String
    /// How many days the user has logged in the window (gates the card on/off).
    let loggedDays: Int
}

enum AICoachingFactory {
    static func make() -> AICoaching {
        AppConfig.hasAnthropicKey ? AnthropicCoachingService() : MockCoachingService()
    }
}

struct AnthropicCoachingService: AICoaching {
    var apiKey: String = AppConfig.anthropicKey
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    func advise(_ summary: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { throw AICoachingError.unavailable }

        let system = """
        You are PICKLE's nutrition coach: warm, direct, specific. Read the user's recent data, \
        name one real pattern you notice, and give exactly one concrete action for the week \
        ahead. Two or three short sentences. No preamble, no lists, no markdown, no emojis. \
        Speak to them as "you".
        """
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 320,
            "system": system,
            "messages": [["role": "user", "content": [["type": "text", "text": summary]]]],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AICoachingError.network
        }
        struct Envelope: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data),
              let text = env.content.first(where: { $0.type == "text" })?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AICoachingError.empty
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MockCoachingService: AICoaching {
    func advise(_ summary: String) async throws -> String {
        try? await Task.sleep(for: .milliseconds(700))
        return "You're most consistent at breakfast and lightest on protein at dinner. This week, anchor dinner with a palm-sized protein first, then build the rest of the plate around it."
    }
}
