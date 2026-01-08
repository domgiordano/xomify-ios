import Foundation

/// Service for Xomify backend API calls
actor XomifyService {
    
    // MARK: - Singleton
    
    static let shared = XomifyService()
    
    private let network = NetworkService.shared
    
    private init() {}
    
    // MARK: - User / Enrollment
    
    /// Get user enrollment status and wraps
    func getUserData() async throws -> WrappedDataResponse {
        try await network.xomifyGet("/wrapped/data")
    }
    
    /// Get user table data
    func getUserTableData() async throws -> XomifyUser {
        try await network.xomifyGet("/user/user-table")
    }
    
    /// Enroll or update user
    func updateEnrollments(
        wrappedEnrolled: Bool,
        releaseRadarEnrolled: Bool
    ) async throws -> XomifyUser {
        try await network.xomifyPost("/user/user-table", body: [
            "wrappedEnrolled": wrappedEnrolled,
            "releaseRadarEnrolled": releaseRadarEnrolled
        ])
    }
    
    // MARK: - Release Radar
    
    /// Get release radar history (past weeks)
    func getReleaseRadarHistory(limit: Int = 12) async throws -> ReleaseRadarHistoryResponse {
        try await network.xomifyGet("/release-radar/history", queryParams: ["limit": String(limit)])
    }
    
    /// Get current week's releases (live)
    func getReleaseRadarLive() async throws -> ReleaseRadarLiveResponse {
        try await network.xomifyGet("/release-radar/live")
    }
    
    /// Check release radar status
    func checkReleaseRadar() async throws -> ReleaseRadarCheckResponse {
        try await network.xomifyGet("/release-radar/check")
    }
    
    /// Refresh current week (trigger re-fetch)
    func refreshReleaseRadar() async throws -> ReleaseRadarLiveResponse {
        try await network.xomifyPost("/release-radar/refresh", body: [:])
    }
    
    // MARK: - Wrapped
    
    /// Get all wraps from wrapped/data endpoint
    func getWraps() async throws -> [MonthlyWrap] {
        let response: WrappedDataResponse = try await network.xomifyGet("/wrapped/data")
        return response.wraps ?? []
    }
    
    /// Get specific wrap by month
    func getWrap(monthKey: String) async throws -> MonthlyWrap {
        try await network.xomifyGet("/wrapped/month", queryParams: ["monthKey": monthKey])
    }
}

// MARK: - Wrapped Data Response

struct WrappedDataResponse: Codable {
    let active: Bool?
    let activeWrapped: Bool?
    let activeReleaseRadar: Bool?
    let wraps: [MonthlyWrap]?
}
