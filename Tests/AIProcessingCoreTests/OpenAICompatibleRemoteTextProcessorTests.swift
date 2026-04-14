#if canImport(XCTest)
    import Foundation
    import XCTest
    @testable import AIProcessingCore

    final class OpenAICompatibleRemoteTextProcessorTests: XCTestCase {
        override func setUp() {
            super.setUp()
            StubURLProtocol.requestHandler = nil
        }

        func testDiscoverModelsParsesRemoteCatalog() async throws {
            let session = makeSession()
            StubURLProtocol.requestHandler = { request in
                XCTAssertEqual(request.url?.absoluteString, "https://openrouter.ai/api/v1/models")
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = Data(
                    #"{"data":[{"id":"openai/gpt-4o-mini","name":"GPT-4o Mini"}]}"#.utf8)
                return (response, data)
            }

            let models = try await OpenAICompatibleRemoteTextProcessor.discoverModels(
                configuration: AIRemoteProviderConfiguration(
                    id: "openrouter",
                    preset: .openRouter,
                    displayName: "OpenRouter",
                    baseURLString: "https://openrouter.ai/api/v1"
                ),
                apiKey: "test-key",
                session: session
            )

            XCTAssertEqual(
                models, [AIRemoteModel(id: "openai/gpt-4o-mini", displayName: "GPT-4o Mini")])
        }

        func testProcessUsesRequestModelIdentifier() async throws {
            let session = makeSession()
            StubURLProtocol.requestHandler = { request in
                XCTAssertEqual(
                    request.url?.absoluteString, "https://openrouter.ai/api/v1/chat/completions")
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

                let requestData = try XCTUnwrap(
                    request.httpBody ?? request.httpBodyStream?.readToEnd())
                let body = try JSONDecoder().decode(RequestBody.self, from: requestData)
                XCTAssertEqual(body.model, "openai/gpt-4o-mini")
                XCTAssertEqual(body.messages.first?.role, "system")
                XCTAssertEqual(body.messages.last?.role, "user")
                XCTAssertTrue(
                    body.messages.first?.content.contains("Format the output as an email") == true)
                XCTAssertTrue(
                    body.messages.first?.content.contains("Use a businesslike, professional style.")
                        == true)
                XCTAssertTrue(
                    body.messages.first?.content.contains("Use a formal form of address.") == true)

                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = Data(
                    #"{"choices":[{"message":{"content":"Polished remote text"}}]}"#.utf8)
                return (response, data)
            }

            let configuration = AIRemoteProviderConfiguration(
                id: "openrouter",
                preset: .openRouter,
                displayName: "OpenRouter",
                baseURLString: "https://openrouter.ai/api/v1",
                discoveredModels: [
                    AIRemoteModel(id: "openai/gpt-4o-mini", displayName: "GPT-4o Mini")
                ]
            )
            let provider = OpenAICompatibleRemoteTextProcessor(
                configuration: configuration, apiKey: "test-key", session: session)
            let model = try XCTUnwrap(provider.models().first)

            let result = try await provider.process(
                AIProcessingRequest(
                    text: "Ich geh morgen klettern.",
                    stage: .final,
                    locale: Locale(identifier: "de_DE"),
                    configuration: AIProcessingConfiguration(
                        enabled: true,
                        selectedModelID: model.id,
                        applyDuringLiveInsertion: true,
                        applyToFinalResult: true,
                        revisionGoal: .adaptFormat,
                        formattingMode: .email,
                        style: .business,
                        salutation: .formal,
                        toneAdjustmentEnabled: true,
                        salutationAdjustmentEnabled: true,
                        formatAdaptationEnabled: true
                    )
                ),
                model: model
            )

            XCTAssertEqual(result, "Polished remote text")
        }

        func testRemoteModelDecodingDefaultsToQuickSettingsEligible() throws {
            let data = Data(#"{"id":"local-model","displayName":"Local model"}"#.utf8)
            let model = try JSONDecoder().decode(AIRemoteModel.self, from: data)

            XCTAssertTrue(model.quickSettingsEligible)
        }

        func testOptionalAPIKeyProviderOmitsAuthorizationHeader() async throws {
            let session = makeSession()
            StubURLProtocol.requestHandler = { request in
                XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/v1/models")
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = Data(#"{"data":[{"id":"llama3.2","name":"Llama 3.2"}]}"#.utf8)
                return (response, data)
            }

            let models = try await OpenAICompatibleRemoteTextProcessor.discoverModels(
                configuration: AIRemoteProviderConfiguration.template(for: .ollama),
                apiKey: "",
                session: session
            )

            XCTAssertEqual(models, [AIRemoteModel(id: "llama3.2", displayName: "Llama 3.2")])
        }

        private func makeSession() -> URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            return URLSession(configuration: configuration)
        }
    }

    private final class StubURLProtocol: URLProtocol {
        static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                fatalError("StubURLProtocol.requestHandler not set")
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    private struct RequestBody: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
    }

    extension InputStream {
        fileprivate func readToEnd() -> Data? {
            open()
            defer { close() }

            let chunkSize = 4096
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
            defer { buffer.deallocate() }

            while hasBytesAvailable {
                let count = read(buffer, maxLength: chunkSize)
                if count < 0 {
                    return nil
                }
                if count == 0 {
                    break
                }
                data.append(buffer, count: count)
            }

            return data
        }
    }
#endif
