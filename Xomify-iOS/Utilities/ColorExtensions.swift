import SwiftUI

// MARK: - Xomify Brand Colors

extension Color {
    /// Primary purple - #9C0ABF
    static let xomifyPurple = Color(red: 156/255, green: 10/255, blue: 191/255)
    
    /// Primary green - #1BDC6F
    static let xomifyGreen = Color(red: 27/255, green: 220/255, blue: 111/255)
    
    /// Dark background - #0A0A14
    static let xomifyDark = Color(red: 10/255, green: 10/255, blue: 20/255)
    
    /// Card background - #1A1A2E
    static let xomifyCard = Color(red: 26/255, green: 26/255, blue: 46/255)
    
    /// Secondary background - slightly lighter than dark
    static let xomifySecondary = Color(red: 18/255, green: 18/255, blue: 32/255)
    
    /// Spotify green for reference
    static let spotifyGreen = Color(red: 29/255, green: 185/255, blue: 84/255)
}

// MARK: - Gradient Helpers

extension LinearGradient {
    /// Xomify brand gradient (purple to green)
    static let xomifyGradient = LinearGradient(
        colors: [.xomifyPurple, .xomifyGreen],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Vertical brand gradient
    static let xomifyVerticalGradient = LinearGradient(
        colors: [.xomifyPurple, .xomifyGreen],
        startPoint: .top,
        endPoint: .bottom
    )
}
