import Foundation

public struct OpenAICompatibleRemoteTextProcessor: AITextProcessingProviding {
    public let providerID: String
    public let providerKind: AIProviderKind = .remoteAPI

    private let configuration: AIRemoteProviderConfiguration
    private let apiKey: String
    private let session: URLSession

    public init(
        configuration: AIRemoteProviderConfiguration,
        apiKey: String,
        session: URLSession = .shared
    ) {
        self.providerID = configuration.id
        self.configuration = configuration
        self.apiKey = apiKey
        self.session = session
    }

    public func models() -> [AIModelDescriptor] {
        guard configuration.isEnabled else { return [] }
        return configuration.discoveredModels.map { model in
            AIModelDescriptor(
                id: Self.selectionModelID(providerID: configuration.id, modelID: model.id),
                providerID: configuration.id,
                requestModelID: model.id,
                displayName: "\(configuration.displayName) - \(model.displayName)",
                providerKind: .remoteAPI,
                availability: .available,
                quickSettingsEligible: model.quickSettingsEligible
            )
        }
    }

    public func process(_ request: AIProcessingRequest, model: AIModelDescriptor) async throws -> String {
        let endpoint = try Self.endpointURL(baseURLString: configuration.baseURLString, path: configuration.chatCompletionsPath)
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        Self.applyAuthentication(to: &urlRequest, apiKey: apiKey)

        if configuration.preset.supportsOpenRouterHeaders {
            if let referer = configuration.appReferer, !referer.isEmpty {
                urlRequest.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
            }
            if let title = configuration.appTitle, !title.isEmpty {
                urlRequest.setValue(title, forHTTPHeaderField: "X-Title")
            }
        }

        let body = ChatCompletionsRequest(
            model: model.requestModelID,
            messages: [
                .init(role: "system", content: AppleFoundationPromptBuilder.instructions(for: request.configuration)),
                .init(role: "user", content: AppleFoundationPromptBuilder.prompt(for: request))
            ],
            temperature: 0.2
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProcessingError.providerUnavailable("Remote AI provider returned no HTTP response.")
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIProcessingError.providerUnavailable("Remote AI provider request failed: \(message)")
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw AIProcessingError.providerUnavailable("Remote AI provider returned no text content.")
        }

        return content
    }

    public static func discoverModels(
        configuration: AIRemoteProviderConfiguration,
        apiKey: String,
        session: URLSession = .shared
    ) async throws -> [AIRemoteModel] {
        let endpoint = try endpointURL(baseURLString: configuration.baseURLString, path: configuration.modelsPath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        applyAuthentication(to: &request, apiKey: apiKey)

        if configuration.preset.supportsOpenRouterHeaders {
            if let referer = configuration.appReferer, !referer.isEmpty {
                request.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
            }
            if let title = configuration.appTitle, !title.isEmpty {
                request.setValue(title, forHTTPHeaderField: "X-Title")
            }
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProcessingError.providerUnavailable("Remote model catalog returned no HTTP response.")
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIProcessingError.providerUnavailable("Remote model catalog request failed: \(message)")
        }

        let decoded = try JSONDecoder().decode(RemoteModelsResponse.self, from: data)
        return decoded.data
            .map { AIRemoteModel(id: $0.id, displayName: $0.name ?? $0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public static func selectionModelID(providerID: String, modelID: String) -> String {
        "\(providerID)::\(modelID)"
    }

    private static func endpointURL(baseURLString: String, path: String) throws -> URL {
        guard let baseURL = URL(string: baseURLString) else {
            throw AIProcessingError.providerUnavailable("Invalid remote provider base URL.")
        }
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appending(path: normalizedPath)
    }

    private static func applyAuthentication(to request: inout URLRequest, apiKey: String) {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else { return }
        request.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")
    }
}

private struct ChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct RemoteModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
        let name: String?
    }

    let data: [Model]
}
