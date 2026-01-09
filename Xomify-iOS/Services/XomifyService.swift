import Foundation

/// Service for Xomify backend API calls
actor XomifyService {
    
    // MARK: - Singleton
    
    static let shared = XomifyService()
    
    private let network = NetworkService.shared
    
    private init() {}
    
    // MARK: - User Data
    
    func getUserData(email: String) async throws -> WrappedDataResponse {
        try await network.xomifyGet("/wrapped/data", queryParams: ["email": email])
    }
    
    func getUserTableData(email: String) async throws -> XomifyUser {
        try await network.xomifyGet("/user", queryParams: ["email": email])
    }
    
    // MARK: - Enrollments
    
    func updateEnrollments(email: String, activeWrapped: Bool, activeReleaseRadar: Bool) async throws {
        let _: EmptyResponse = try await network.xomifyPost("/user/enrollments", body: [
            "email": email,
            "activeWrapped": activeWrapped,
            "activeReleaseRadar": activeReleaseRadar
        ])
    }
    
    // MARK: - Release Radar
    
    /// Get current week's releases live from Spotify
    func getReleaseRadarLive(email: String) async throws -> ReleaseRadarLiveResponse {
        try await network.xomifyGet("/release-radar/live", queryParams: ["email": email])
    }
    
    /// Get release radar history from database
    func getReleaseRadarHistory(email: String, limit: Int = 26) async throws -> ReleaseRadarHistoryResponse {
        try await network.xomifyGet("/release-radar/history", queryParams: [
            "email": email,
            "limit": String(limit)
        ])
    }
    
    /// Check release radar enrollment status
    func getReleaseRadarCheck(email: String) async throws -> ReleaseRadarCheckResponse {
        try await network.xomifyGet("/release-radar/check", queryParams: ["email": email])
    }
    
    // MARK: - Wrapped
    
    /// Get all user's wraps
    func getWraps(email: String) async throws -> [MonthlyWrap] {
        let response: WrappedDataResponse = try await network.xomifyGet("/wrapped/data", queryParams: ["email": email])
        return response.wraps ?? []
    }
    
    /// Get a specific month's wrap
    func getWrap(email: String, monthKey: String) async throws -> MonthlyWrap {
        try await network.xomifyGet("/wrapped/\(monthKey)", queryParams: ["email": email])
    }
}
