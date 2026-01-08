import Foundation

/// Handles all network requests to Spotify API and Xomify backend
actor NetworkService {
    
    // MARK: - Singleton
    
    static let shared = NetworkService()
    
    private init() {}
    
    // MARK: - Spotify API
    
    /// Make an authenticated request to Spotify API
    func spotifyRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: [String: Any]? = nil
    ) async throws -> T {
        let token = try await AuthService.shared.getValidAccessToken()
        
        let url = URL(string: "\(Config.spotifyApiBaseUrl)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return try await performRequest(request)
    }
    
    /// GET request to Spotify
    func spotifyGet<T: Decodable>(_ endpoint: String) async throws -> T {
        try await spotifyRequest(endpoint: endpoint, method: .get)
    }
    
    /// POST request to Spotify
    func spotifyPost<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        try await spotifyRequest(endpoint: endpoint, method: .post, body: body)
    }
    
    /// PUT request to Spotify (no response body)
    func spotifyPut(_ endpoint: String, body: [String: Any]) async throws {
        let token = try await AuthService.shared.getValidAccessToken()
        
        let url = URL(string: "\(Config.spotifyApiBaseUrl)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "PUT failed")
        }
    }
    
    /// DELETE request to Spotify (no response body)
    func spotifyDelete(_ endpoint: String, body: [String: Any]? = nil) async throws {
        let token = try await AuthService.shared.getValidAccessToken()
        
        let url = URL(string: "\(Config.spotifyApiBaseUrl)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "DELETE failed")
        }
    }
    
    // MARK: - Xomify API
    
    /// Make a request to your Xomify backend
    /// Automatically includes the user's email from AuthService
    func xomifyRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        queryParams: [String: String]? = nil,
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let email = await AuthService.shared.userEmail else {
            throw NetworkError.unauthorized
        }
        
        var components = URLComponents(string: "\(Config.xomifyApiBaseUrl)\(endpoint)")!
        
        // Always include email in query params
        var allParams = queryParams ?? [:]
        allParams["email"] = email
        components.queryItems = allParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.xomifyApiToken)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return try await performRequest(request)
    }
    
    /// GET request to Xomify API
    func xomifyGet<T: Decodable>(_ endpoint: String, queryParams: [String: String]? = nil) async throws -> T {
        try await xomifyRequest(endpoint: endpoint, method: .get, queryParams: queryParams)
    }
    
    /// POST request to Xomify API
    func xomifyPost<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        try await xomifyRequest(endpoint: endpoint, method: .post, body: body)
    }
    
    // MARK: - Private Methods
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Log for debugging
        #if DEBUG
        if let url = request.url {
            print("📡 \(request.httpMethod ?? "GET") \(url.absoluteString) → \(httpResponse.statusCode)")
        }
        if let json = String(data: data, encoding: .utf8) {
            print("📄 Response (\(data.count) bytes): \(json.prefix(1000))")
        }
        #endif
        
        switch httpResponse.statusCode {
        case 200...299:
            // Handle empty responses
            if data.isEmpty || T.self == EmptyResponse.self {
                if let empty = EmptyResponse() as? T {
                    return empty
                }
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                #if DEBUG
                print("❌ Decode error for type \(T.self): \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Key '\(key.stringValue)' not found: \(context.debugDescription)")
                        print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch for \(type): \(context.debugDescription)")
                        print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .valueNotFound(let type, let context):
                        print("   Value not found for \(type): \(context.debugDescription)")
                        print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("   Data corrupted: \(context.debugDescription)")
                        print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
                #endif
                throw NetworkError.decodingError(error)
            }
            
        case 401:
            throw NetworkError.unauthorized
            
        case 404:
            throw NetworkError.notFound
            
        case 429:
            // Rate limited
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            throw NetworkError.rateLimited(retryAfter: Int(retryAfter ?? "1") ?? 1)
            
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            #if DEBUG
            print("❌ Server error \(httpResponse.statusCode): \(message)")
            #endif
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

struct EmptyResponse: Codable {
    init() {}
}

enum NetworkError: LocalizedError {
    case invalidResponse
    case unauthorized
    case notFound
    case rateLimited(retryAfter: Int)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized - please log in again"
        case .notFound:
            return "Resource not found"
        case .rateLimited(let seconds):
            return "Rate limited. Try again in \(seconds) seconds"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}
