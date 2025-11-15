import Foundation

class OllamaService {
    static let shared = OllamaService()

    private let baseURL = "http://localhost:11434"
    private let session = URLSession.shared

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

    /// Check if Ollama service is running and available
    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            return false
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            // Try to decode response to verify it's valid JSON
            _ = try JSONSerialization.jsonObject(with: data)
            return true

        } catch {
            print("⚠️ Ollama health check failed: \(error.localizedDescription)")
            return false
        }
    }
}
