import Foundation

/// ViewModel for the Profile/Home screen
@Observable
@MainActor
final class ProfileViewModel {
    
    // MARK: - Properties
    
    var user: SpotifyUser?
    var xomifyUser: XomifyUser?
    var isLoading = false
    var errorMessage: String?
    
    // Counts
    var followingCount = 0
    var playlistCount = 0
    
    // Enrollment states
    var isWrappedEnrolled = false
    var isReleaseRadarEnrolled = false
    var isUpdatingEnrollment = false
    
    private let spotifyService = SpotifyService.shared
    private let xomifyService = XomifyService.shared
    private let authService = AuthService.shared
    
    // MARK: - Computed
    
    var displayName: String {
        user?.displayName ?? "User"
    }
    
    var email: String {
        user?.email ?? ""
    }
    
    var profileImageUrl: URL? {
        user?.profileImageUrl
    }
    
    var accountType: String {
        user?.product?.capitalized ?? "Free"
    }
    
    var isPremium: Bool {
        user?.product?.lowercased() == "premium"
    }
    
    var country: String {
        user?.country ?? ""
    }
    
    var followersCount: Int {
        user?.followers?.total ?? 0
    }
    
    var userId: String {
        user?.id ?? ""
    }
    
    var spotifyProfileUrl: URL? {
        if let urlString = user?.externalUrls?["spotify"] {
            return URL(string: urlString)
        }
        return nil
    }
    
    // MARK: - Actions
    
    func loadProfile() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load Spotify user
            user = try await spotifyService.getCurrentUser()
            
            // Load following count
            let followedArtists = try await spotifyService.getFollowedArtists()
            followingCount = followedArtists.count
            
            // Load Xomify enrollment status
            if let email = user?.email {
                await loadXomifyStatus(email: email)
            }
            
            print("✅ Profile: Loaded - \(displayName), following \(followingCount) artists")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Profile: Error loading profile - \(error)")
        }
        
        isLoading = false
    }
    
    private func loadXomifyStatus(email: String) async {
        do {
            let userData = try await xomifyService.getUserData(email: email)
            isWrappedEnrolled = userData.activeWrapped
            isReleaseRadarEnrolled = userData.activeReleaseRadar
            print("✅ Profile: Loaded enrollment - Wrapped: \(isWrappedEnrolled), ReleaseRadar: \(isReleaseRadarEnrolled)")
        } catch {
            // User might not exist yet in Xomify - that's OK
            print("⚠️ Profile: Could not load Xomify status - \(error)")
            isWrappedEnrolled = false
            isReleaseRadarEnrolled = false
        }
    }
    
    func toggleWrappedEnrollment() async {
        guard !isUpdatingEnrollment, let email = user?.email else { return }
        
        isUpdatingEnrollment = true
        let newValue = !isWrappedEnrolled
        
        do {
            try await xomifyService.updateEnrollments(
                email: email,
                activeWrapped: newValue,
                activeReleaseRadar: isReleaseRadarEnrolled
            )
            isWrappedEnrolled = newValue
            print("✅ Profile: Updated Wrapped enrollment to \(newValue)")
        } catch {
            print("❌ Profile: Failed to update Wrapped enrollment - \(error)")
        }
        
        isUpdatingEnrollment = false
    }
    
    func toggleReleaseRadarEnrollment() async {
        guard !isUpdatingEnrollment, let email = user?.email else { return }
        
        isUpdatingEnrollment = true
        let newValue = !isReleaseRadarEnrolled
        
        do {
            try await xomifyService.updateEnrollments(
                email: email,
                activeWrapped: isWrappedEnrolled,
                activeReleaseRadar: newValue
            )
            isReleaseRadarEnrolled = newValue
            print("✅ Profile: Updated Release Radar enrollment to \(newValue)")
        } catch {
            print("❌ Profile: Failed to update Release Radar enrollment - \(error)")
        }
        
        isUpdatingEnrollment = false
    }
    
    func logout() {
        authService.logout()
    }
}
