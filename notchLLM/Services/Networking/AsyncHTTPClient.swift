import Foundation

/// Lightweight async HTTP helper — always off the main actor, with hard timeouts.
actor AsyncHTTPClient {
    static let shared = AsyncHTTPClient()

    enum HTTPError: Error, LocalizedError {
        case invalidURL
        case badStatus(Int, String)
        case timeout
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Invalid URL"
            case .badStatus(let code, let body): "HTTP \(code): \(body.prefix(160))"
            case .timeout: "Request timed out"
            case .transport(let message): message
            }
        }
    }

    private let session: URLSession

    init(timeout: TimeInterval = 8) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    func getJSON(
        url: URL,
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HTTPError.transport("Non-HTTP response")
            }
            return (data, http)
        } catch let error as URLError where error.code == .timedOut {
            throw HTTPError.timeout
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError.transport(error.localizedDescription)
        }
    }
}
