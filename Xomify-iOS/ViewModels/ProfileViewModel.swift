import Foundation

/// ViewModel for the Profile screen
@Observable
final class ProfileViewModel {
    
    // MARK: - Properties
    
    var user: SpotifyUser?
    var isLoading = false
    var errorMessage: String?
    
    private let spotifyService = SpotifyService.shared
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
    
    var country: String {
        user?.country ?? ""
    }
    
    var followersCount: Int {
        user?.followers?.total ?? 0
    }
    
    // MARK: - Actions
    
    @MainActor
    func loadProfile() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await spotifyService.getCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        authService.logout()
    }
}
