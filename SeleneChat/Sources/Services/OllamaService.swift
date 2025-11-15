import Foundation

/// Service for communicating with local Ollama LLM server
class OllamaService {
    private let baseURL: String
    private let defaultModel: String
    private let session: URLSession

    init(baseURL: String = "http://localhost:11434", defaultModel: String = "mistral:7b") {
        self.baseURL = baseURL
        self.defaultModel = defaultModel

        // Configure URL session with appropriate timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }

    /// Check if Ollama service is available
    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    /// Generate text completion from prompt
    func generate(prompt: String, model: String? = nil) async throws -> String {
        // Validate prompt
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.emptyPrompt
        }

        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0

        // Build payload
        let modelToUse = model ?? defaultModel
        let payload: [String: Any] = [
            "model": modelToUse,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.3
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // Make request
        do {
            let (data, response) = try await session.data(for: request)

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw OllamaError.connectionFailed
            }

            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                throw OllamaError.invalidResponse
            }

            return responseText

        } catch let error as OllamaError {
            throw error
        } catch {
            // Handle URLSession errors
            if (error as NSError).code == NSURLErrorTimedOut {
                throw OllamaError.timeout
            }
            throw OllamaError.connectionFailed
        }
    }
}

// MARK: - Errors

enum OllamaError: Error, LocalizedError {
    case notImplemented
    case connectionFailed
    case invalidResponse
    case timeout
    case emptyPrompt
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Feature not implemented"
        case .connectionFailed:
            return "Failed to connect to Ollama service"
        case .invalidResponse:
            return "Invalid response from Ollama"
        case .timeout:
            return "Request timed out"
        case .emptyPrompt:
            return "Prompt cannot be empty"
        case .invalidURL:
            return "Invalid Ollama URL"
        }
    }
}
