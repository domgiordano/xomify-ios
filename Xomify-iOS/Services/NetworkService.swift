import Foundation

/// Centralized network service for API requests
/// Swift 6 compatible with proper actor isolation
actor NetworkService {
    
    // MARK: - Singleton
    
    static let shared = NetworkService()
    
    // Store URLs as instance properties to avoid actor isolation issues
    private let spotifyBaseUrl = "https://api.spotify.com/v1"
    private let xomifyBaseUrl: String
    private let xomifyToken: String
    
    private init() {
        // Read config values during init - matching your Secrets.xcconfig keys
        // XOMIFY_API_ID is the API Gateway ID used to build the URL
        let apiId = Bundle.main.object(forInfoDictionaryKey: "XOMIFY_API_ID") as? String ?? "1hm6iwckle"
        self.xomifyBaseUrl = "https://\(apiId).execute-api.us-east-1.amazonaws.com/dev"
        self.xomifyToken = Bundle.main.object(forInfoDictionaryKey: "XOMIFY_API_TOKEN") as? String ?? ""
    }
    
    // MARK: - Spotify API
    
    func spotifyGet<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let accessToken = await AuthService.shared.accessToken else {
            throw NetworkError.unauthorized
        }
        
        let urlString = spotifyBaseUrl + endpoint
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return try await performRequest(request)
    }
    
    func spotifyPost<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        guard let accessToken = await AuthService.shared.accessToken else {
            throw NetworkError.unauthorized
        }
        
        let urlString = spotifyBaseUrl + endpoint
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request)
    }
    
    func spotifyPut(_ endpoint: String, body: [String: Any]) async throws {
        guard let accessToken = await AuthService.shared.accessToken else {
            throw NetworkError.unauthorized
        }
        
        let urlString = spotifyBaseUrl + endpoint
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func spotifyDelete(_ endpoint: String) async throws {
        guard let accessToken = await AuthService.shared.accessToken else {
            throw NetworkError.unauthorized
        }
        
        let urlString = spotifyBaseUrl + endpoint
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Xomify API
    
    func xomifyGet<T: Decodable>(_ endpoint: String, queryParams: [String: String] = [:]) async throws -> T {
        var urlString = xomifyBaseUrl + endpoint
        
        if !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(xomifyToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("📡 GET \(urlString)")
        
        return try await performRequest(request)
    }
    
    func xomifyPost<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        let urlString = xomifyBaseUrl + endpoint
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(xomifyToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("📡 POST \(urlString)")
        
        return try await performRequest(request)
    }
    
    // MARK: - Request Execution
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        print("📡 \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "") → \(httpResponse.statusCode)")
        
        // Log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            let preview = responseString.prefix(500)
            print("📄 Response (\(data.count) bytes): \(preview)")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Key '\(key.stringValue)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch for \(type): \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   Value not found for \(type): \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("   Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            throw error
        }
    }
}

// MARK: - Error Types

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Not authenticated"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
