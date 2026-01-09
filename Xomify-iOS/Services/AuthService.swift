import Foundation
import AuthenticationServices
import CommonCrypto

/// Handles Spotify OAuth authentication
@Observable
final class AuthService: NSObject, Sendable {
    
    // MARK: - Singleton
    
    static let shared = AuthService()
    
    // MARK: - Properties
    
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var tokenExpirationDate: Date?
    private(set) var isAuthenticated = false
    
    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String?
    
    // Config values cached at init (matching your Secrets.xcconfig keys)
    private let clientId: String
    private let clientSecret: String
    private let redirectUri = "xomify://callback"
    private let scopes: String
    
    // MARK: - Keychain Keys
    
    private let accessTokenKey = "xomify.spotify.accessToken"
    private let refreshTokenKey = "xomify.spotify.refreshToken"
    private let expirationKey = "xomify.spotify.expiration"
    
    // MARK: - Init
    
    private override init() {
        // Read config at init time - matching your Secrets.xcconfig variable names
        self.clientId = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String ?? ""
        self.clientSecret = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_SECRET") as? String ?? ""
        self.scopes = [
            "user-read-private",
            "user-read-email",
            "user-top-read",
            "user-follow-read",
            "user-follow-modify",
            "playlist-read-private",
            "playlist-read-collaborative",
            "playlist-modify-public",
            "playlist-modify-private",
            "user-library-read"
        ].joined(separator: " ")
        
        super.init()
        loadTokens()
    }
    
    // MARK: - Token Management
    
    private func loadTokens() {
        accessToken = KeychainHelper.read(key: accessTokenKey)
        refreshToken = KeychainHelper.read(key: refreshTokenKey)
        
        if let expirationString = KeychainHelper.read(key: expirationKey),
           let timestamp = Double(expirationString) {
            tokenExpirationDate = Date(timeIntervalSince1970: timestamp)
        }
        
        isAuthenticated = accessToken != nil && !isTokenExpired
        
        if isAuthenticated {
            print("✅ Auth: Loaded existing session")
        }
    }
    
    private func saveTokens(accessToken: String, refreshToken: String?, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken ?? self.refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        self.isAuthenticated = true
        
        KeychainHelper.save(key: accessTokenKey, value: accessToken)
        if let refresh = self.refreshToken {
            KeychainHelper.save(key: refreshTokenKey, value: refresh)
        }
        if let expiration = tokenExpirationDate {
            KeychainHelper.save(key: expirationKey, value: String(expiration.timeIntervalSince1970))
        }
        
        print("✅ Auth: Tokens saved, expires in \(expiresIn)s")
    }
    
    private var isTokenExpired: Bool {
        guard let expiration = tokenExpirationDate else { return true }
        return Date() >= expiration.addingTimeInterval(-60) // 1 min buffer
    }
    
    // MARK: - Login
    
    @MainActor
    func login() async throws {
        // Generate PKCE code verifier and challenge
        codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier!)
        
        // Build authorization URL
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge)
        ]
        
        guard let authUrl = components.url else {
            throw AuthError.invalidURL
        }
        
        print("🔐 Auth: Starting login flow...")
        print("🔐 Auth: Client ID: \(clientId.prefix(8))...")
        
        // Start auth session
        let callbackUrl = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            authSession = ASWebAuthenticationSession(
                url: authUrl,
                callbackURLScheme: "xomify"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = callbackURL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: AuthError.cancelled)
                }
            }
            
            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.start()
        }
        
        // Extract authorization code
        guard let code = extractCode(from: callbackUrl) else {
            throw AuthError.noCode
        }
        
        print("🔐 Auth: Got authorization code")
        
        // Exchange code for tokens
        try await exchangeCodeForTokens(code: code)
    }
    
    private func exchangeCodeForTokens(code: String) async throws {
        guard let verifier = codeVerifier else {
            throw AuthError.noCodeVerifier
        }
        
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectUri)",
            "client_id=\(clientId)",
            "code_verifier=\(verifier)"
        ].joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("❌ Auth: Token exchange failed")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Auth: Response: \(responseString)")
            }
            throw AuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: tokenResponse.expiresIn
        )
        
        print("✅ Auth: Login successful!")
    }
    
    // MARK: - Refresh Token
    
    func refreshAccessToken() async throws {
        guard let refresh = refreshToken else {
            throw AuthError.noRefreshToken
        }
        
        print("🔄 Auth: Refreshing access token...")
        
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refresh)",
            "client_id=\(clientId)"
        ].joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.refreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: tokenResponse.expiresIn
        )
        
        print("✅ Auth: Token refreshed!")
    }
    
    // MARK: - Logout
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
        isAuthenticated = false
        
        KeychainHelper.delete(key: accessTokenKey)
        KeychainHelper.delete(key: refreshTokenKey)
        KeychainHelper.delete(key: expirationKey)
        
        print("👋 Auth: Logged out")
    }
    
    // MARK: - PKCE Helpers
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncodedString()
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64URLEncodedString()
    }
    
    private func extractCode(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Token Response

private struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case invalidURL
    case cancelled
    case noCode
    case noCodeVerifier
    case noRefreshToken
    case tokenExchangeFailed
    case refreshFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid authorization URL"
        case .cancelled: return "Login was cancelled"
        case .noCode: return "No authorization code received"
        case .noCodeVerifier: return "Missing code verifier"
        case .noRefreshToken: return "No refresh token available"
        case .tokenExchangeFailed: return "Failed to exchange code for tokens"
        case .refreshFailed: return "Failed to refresh access token"
        }
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Data Extension

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
