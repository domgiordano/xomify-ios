import SwiftUI

/// Main tab bar view after authentication
struct MainTabView: View {
    
    @State private var selectedTab = 0
    
    // Xomify brand colors
    private let primaryPurple = Color(red: 156/255, green: 10/255, blue: 191/255)
    private let primaryGreen = Color(red: 27/255, green: 220/255, blue: 111/255)
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            TopItemsViewTab()
                .tabItem {
                    Label("Top", systemImage: "chart.bar.fill")
                }
                .tag(1)
            
            ReleaseRadarView()
                .tabItem {
                    Label("Releases", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(2)
            
            WrappedView()
                .tabItem {
                    Label("Wrapped", systemImage: "gift.fill")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(primaryGreen)
    }
}

// MARK: - Placeholder Views (we'll build these out)

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome to Xomify")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .navigationTitle("Home")
        }
    }
}

struct TopItemsViewTab: View {
    var body: some View {
        TopItemsViewReal()
    }
}

struct TopItemsViewReal: View {
    
    @State private var viewModel = TopItemsViewModel()
    
    private let primaryPurple = Color(red: 156/255, green: 10/255, blue: 191/255)
    private let primaryGreen = Color(red: 27/255, green: 220/255, blue: 111/255)
    private let darkBackground = Color(red: 10/255, green: 10/255, blue: 20/255)
    private let cardBackground = Color(red: 26/255, green: 26/255, blue: 46/255)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabSelector
                timeRangeSelector
                content
            }
            .background(darkBackground.ignoresSafeArea())
            .navigationTitle("Your Top")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadData()
            }
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(TopItemsViewModel.TopItemsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.onTabChange(tab)
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.selectedTab == tab ? primaryPurple.opacity(0.2) : Color.clear)
                    .foregroundColor(viewModel.selectedTab == tab ? primaryPurple : .gray)
                }
            }
        }
        .background(cardBackground)
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.onTimeRangeChange(range)
                    }
                } label: {
                    Text(range.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedTimeRange == range ? primaryGreen : cardBackground)
                        .foregroundColor(viewModel.selectedTimeRange == range ? .black : .gray)
                        .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Spacer()
        } else if let error = viewModel.errorMessage {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.gray)
                Button("Try Again") {
                    Task { await viewModel.refresh() }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(primaryPurple)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    switch viewModel.selectedTab {
                    case .tracks:
                        ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(track: track, rank: index + 1)
                        }
                    case .artists:
                        ForEach(Array(viewModel.artists.enumerated()), id: \.element.id) { index, artist in
                            artistRow(artist: artist, rank: index + 1)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
    
    private func trackRow(track: SpotifyTrack, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rank <= 3 ? primaryGreen : .gray)
                .frame(width: 30)
            
            AsyncImage(url: track.imageUrl) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(cardBackground)
                    .overlay(Image(systemName: "music.note").foregroundColor(.gray))
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(track.artistNames)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(track.duration)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private func artistRow(artist: SpotifyArtist, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rank <= 3 ? primaryGreen : .gray)
                .frame(width: 30)
            
            AsyncImage(url: artist.imageUrl) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(cardBackground)
                    .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let genres = artist.genres, !genres.isEmpty {
                    Text(genres.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let popularity = artist.popularity {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.caption2)
                    Text("\(popularity)").font(.caption)
                }
                .foregroundColor(.orange.opacity(0.8))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct ReleaseRadarView: View {
    var body: some View {
        NavigationStack {
            Text("Release Radar")
                .navigationTitle("Releases")
        }
    }
}

struct WrappedView: View {
    var body: some View {
        NavigationStack {
            Text("Wrapped")
                .navigationTitle("Wrapped")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        ProfileViewReal()
    }
}

// Renamed to avoid conflict - delete this and use the one in Views/Profile/
struct ProfileViewReal: View {
    
    @State private var viewModel = ProfileViewModel()
    @State private var showLogoutConfirmation = false
    
    // Xomify brand colors
    private let primaryPurple = Color(red: 156/255, green: 10/255, blue: 191/255)
    private let primaryGreen = Color(red: 27/255, green: 220/255, blue: 111/255)
    private let darkBackground = Color(red: 10/255, green: 10/255, blue: 20/255)
    private let cardBackground = Color(red: 26/255, green: 26/255, blue: 46/255)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileHeader
                    statsSection
                    accountSection
                    logoutButton
                }
                .padding()
            }
            .background(darkBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadProfile()
            }
            .refreshable {
                await viewModel.loadProfile()
            }
            .confirmationDialog(
                "Are you sure you want to logout?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Logout", role: .destructive) {
                    viewModel.logout()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            AsyncImage(url: viewModel.profileImageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [primaryPurple, primaryGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            )
            
            if viewModel.isLoading {
                ProgressView()
            } else {
                Text(viewModel.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if !viewModel.email.isEmpty {
                    Text(viewModel.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.top, 20)
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            statCard(title: "Followers", value: "\(viewModel.followersCount)", icon: "person.2.fill", color: primaryPurple)
            statCard(title: "Account", value: viewModel.accountType, icon: "star.fill", color: primaryGreen)
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(cardBackground)
        .cornerRadius(16)
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Details")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                accountRow(icon: "globe", title: "Country", value: viewModel.country)
                Divider().background(Color.gray.opacity(0.3))
                accountRow(icon: "music.note", title: "Subscription", value: viewModel.accountType)
            }
            .background(cardBackground)
            .cornerRadius(12)
        }
    }
    
    private func accountRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(primaryGreen)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    private var logoutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Logout")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.2))
            .foregroundColor(.red)
            .cornerRadius(12)
        }
        .padding(.top, 20)
    }
}

#Preview {
    MainTabView()
}
