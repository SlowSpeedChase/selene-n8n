import Foundation

// MARK: - Request/Response Models

private struct GenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
}

private struct GenerateResponse: Codable {
    let model: String
    let response: String
    let done: Bool
}

class OllamaService {
    static let shared = OllamaService()

    private let baseURL = "http://localhost:11434"
    private let session = URLSession.shared

    private var lastAvailabilityCheck: Date?
    private var cachedAvailability: Bool = false
    private let cacheTimeout: TimeInterval = 60  // Cache for 60 seconds

    private init() {}

    enum OllamaError: Error, LocalizedError {
        case serviceUnavailable
        case invalidResponse
        case decodingError
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .serviceUnavailable:
                return "Ollama service is not running at localhost:11434"
            case .invalidResponse:
                return "Invalid response from Ollama service"
            case .decodingError:
                return "Failed to decode response from Ollama"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    /// Check if Ollama service is running and available (cached for 60s)
    func isAvailable() async -> Bool {
        // Return cached result if fresh
        if let lastCheck = lastAvailabilityCheck,
           Date().timeIntervalSince(lastCheck) < cacheTimeout {
            return cachedAvailability
        }

        // Perform actual health check
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            return false
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                cachedAvailability = false
                lastAvailabilityCheck = Date()
                return false
            }

            // Try to decode response to verify it's valid JSON
            _ = try JSONSerialization.jsonObject(with: data)

            cachedAvailability = true
            lastAvailabilityCheck = Date()
            return true

        } catch {
            print("⚠️ Ollama health check failed: \(error.localizedDescription)")
            cachedAvailability = false
            lastAvailabilityCheck = Date()
            return false
        }
    }

    /// Generate text completion from Ollama
    /// - Parameters:
    ///   - prompt: The full prompt including system instructions and context
    ///   - model: The model to use (default: mistral:7b)
    /// - Returns: Generated text response
    func generate(prompt: String, model: String = "mistral:7b") async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidResponse
        }

        // Build request body
        let requestBody = GenerateRequest(
            model: model,
            prompt: prompt,
            stream: false
        )

        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30.0  // 30 second timeout

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                print("⚠️ Ollama returned status \(httpResponse.statusCode)")
                throw OllamaError.serviceUnavailable
            }

            // Decode response
            let generateResponse = try JSONDecoder().decode(GenerateResponse.self, from: data)

            return generateResponse.response

        } catch let error as OllamaError {
            throw error
        } catch {
            print("⚠️ Ollama generate error: \(error.localizedDescription)")
            throw OllamaError.networkError(error)
        }
    }
}
