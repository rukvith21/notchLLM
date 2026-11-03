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
        // Follow redirects for OAuth/dashboard quirks, but callers still check status.
        config.httpShouldSetCookies = false
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
        return try await perform(request)
    }

    func postJSON(
        url: URL,
        headers: [String: String] = [:],
        body: Data = Data("{}".utf8)
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        var merged = headers
        if merged["Content-Type"] == nil {
            merged["Content-Type"] = "application/json"
        }
        for (key, value) in merged {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await perform(request)
    }

    func postForm(
        url: URL,
        form: [String: String],
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoded = form
            .map { key, value in
                "\(formEncode(key))=\(formEncode(value))"
            }
            .joined(separator: "&")
        request.httpBody = Data(encoded.utf8)
        var merged = headers
        merged["Content-Type"] = "application/x-www-form-urlencoded"
        for (key, value) in merged {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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

    private func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
