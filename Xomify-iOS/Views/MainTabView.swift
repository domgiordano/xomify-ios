import SwiftUI

// MARK: - Brand Colors
extension Color {
    static let xomifyPurple = Color(red: 156/255, green: 10/255, blue: 191/255)
    static let xomifyGreen = Color(red: 27/255, green: 220/255, blue: 111/255)
    static let xomifyDark = Color(red: 10/255, green: 10/255, blue: 20/255)
    static let xomifyCard = Color(red: 26/255, green: 26/255, blue: 46/255)
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProfileView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            TopItemsView()
                .tabItem { Label("Top", systemImage: "chart.bar.fill") }
                .tag(1)
            
            ReleaseRadarView()
                .tabItem { Label("Releases", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(2)
            
            WrappedView()
                .tabItem { Label("Wrapped", systemImage: "gift.fill") }
                .tag(3)
            
            QueueBuilderView()
                .tabItem { Label("Queue", systemImage: "list.bullet.rectangle") }
                .tag(4)
        }
        .tint(.xomifyGreen)
    }
}

#Preview {
    MainTabView()
}
