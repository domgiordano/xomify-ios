import SwiftUI

// MARK: - Profile View (Home)

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner header
                    bannerHeader
                    
                    // Main content - reduced top padding
                    VStack(spacing: 20) {
                        profileHeader
                        statsSection
                        quickStatsSection
                        enrollmentSection
                        accountSection
                        logoutButton
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color.xomifyDark.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    xomifyLogo
                }
            }
            .task {
                await viewModel.loadProfile()
            }
            .refreshable {
                await viewModel.loadProfile()
            }
            .confirmationDialog("Are you sure you want to logout?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Logout", role: .destructive) { viewModel.logout() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Banner Header
    
    private var bannerHeader: some View {
        ZStack(alignment: .bottom) {
            // Gradient background as fallback
            LinearGradient(
                colors: [Color.xomifyPurple.opacity(0.6), Color.xomifyDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)
            .overlay(
                // Try to load banner image
                Image("banner")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .clipped()
            )
            
            // Gradient overlay for smooth transition
            LinearGradient(
                colors: [.clear, Color.xomifyDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
        }
        .frame(height: 140)
    }
    
    // MARK: - Logo
    
    private var xomifyLogo: some View {
        Image("logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 28)
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            AsyncImage(url: viewModel.profileImageUrl) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(LinearGradient(colors: [.xomifyPurple, .xomifyGreen], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3))
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
            .offset(y: -50)
            .padding(.bottom, -50)
            
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
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            statCard(title: "Followers", value: "\(viewModel.followersCount)", icon: "person.2.fill", color: .xomifyPurple)
            
            NavigationLink(destination: FollowingView()) {
                statCardContent(title: "Following", value: "\(viewModel.followingCount)", icon: "heart.fill", color: .xomifyGreen)
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(.white)
            Text(title).font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.xomifyCard)
        .cornerRadius(16)
    }
    
    private func statCardContent(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(.white)
            Text(title).font(.caption).foregroundColor(.gray)
            
            HStack(spacing: 4) {
                Text("View")
                    .font(.caption2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
            }
            .foregroundColor(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.xomifyCard)
        .cornerRadius(16)
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Listening").font(.headline).foregroundColor(.white)
            Text("Quick overview of your music taste").font(.caption).foregroundColor(.gray)
            
            VStack(spacing: 12) {
                NavigationLink(destination: TopItemsView()) {
                    quickStatRow(title: "Top Songs", subtitle: "View your most played tracks", icon: "music.note", iconColor: .xomifyPurple)
                }
                
                NavigationLink(destination: TopItemsView()) {
                    quickStatRow(title: "Top Artists", subtitle: "Discover your favorite artists", icon: "person.2.fill", iconColor: .xomifyGreen)
                }
                
                NavigationLink(destination: TopItemsView()) {
                    quickStatRow(title: "Top Genres", subtitle: "See what styles you love", icon: "guitars.fill", iconColor: .blue)
                }
            }
        }
    }
    
    private func quickStatRow(title: String, subtitle: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(iconColor.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: icon).font(.title3).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                Text(subtitle).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
        }
        .padding()
        .background(Color.xomifyCard)
        .cornerRadius(12)
    }
    
    // MARK: - Enrollment Section
    
    private var enrollmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features").font(.headline).foregroundColor(.white)
            Text("Enhance your Xomify experience").font(.caption).foregroundColor(.gray)
            
            VStack(spacing: 16) {
                NavigationLink(destination: WrappedView()) {
                    enrollmentCard(
                        title: "Monthly Wrapped",
                        description: "Get monthly insights about your listening habits and track your music taste over time.",
                        icon: "chart.bar.fill",
                        iconGradient: [.xomifyGreen, Color(red: 23/255, green: 183/255, blue: 91/255)],
                        isEnrolled: viewModel.isWrappedEnrolled,
                        isUpdating: viewModel.isUpdatingEnrollment
                    ) {
                        Task { await viewModel.toggleWrappedEnrollment() }
                    }
                }
                
                NavigationLink(destination: ReleaseRadarView()) {
                    enrollmentCard(
                        title: "Release Radar",
                        description: "Stay updated with new releases from your favorite artists. Never miss a drop.",
                        icon: "antenna.radiowaves.left.and.right",
                        iconGradient: [.xomifyPurple, Color(red: 122/255, green: 8/255, blue: 150/255)],
                        isEnrolled: viewModel.isReleaseRadarEnrolled,
                        isUpdating: viewModel.isUpdatingEnrollment
                    ) {
                        Task { await viewModel.toggleReleaseRadarEnrollment() }
                    }
                }
            }
        }
    }
    
    private func enrollmentCard(title: String, description: String, icon: String, iconGradient: [Color], isEnrolled: Bool, isUpdating: Bool, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .shadow(color: iconGradient[0].opacity(0.3), radius: 8, x: 0, y: 4)
                Image(systemName: icon).font(.title2).foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                Text(description).font(.caption).foregroundColor(.gray).lineLimit(2)
                if isEnrolled {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").font(.caption2)
                        Text("Enrolled").font(.caption2).fontWeight(.medium)
                    }
                    .foregroundColor(.xomifyGreen)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.xomifyGreen.opacity(0.15))
                    .cornerRadius(10)
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Toggle("", isOn: Binding(get: { isEnrolled }, set: { _ in onToggle() }))
                    .labelsHidden().tint(.xomifyGreen).disabled(isUpdating)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16).fill(Color.xomifyCard)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isEnrolled ? Color.xomifyGreen.opacity(0.3) : Color.clear, lineWidth: 1))
        )
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Details").font(.headline).foregroundColor(.white)
            
            VStack(spacing: 0) {
                accountRow(icon: "globe", title: "Country", value: viewModel.country)
                Divider().background(Color.gray.opacity(0.3))
                accountRow(icon: "music.note", title: "Subscription", value: viewModel.accountType)
                Divider().background(Color.gray.opacity(0.3))
                accountRow(icon: "person", title: "User ID", value: viewModel.userId)
            }
            .background(Color.xomifyCard)
            .cornerRadius(12)
            
            if let url = viewModel.spotifyProfileUrl {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open Spotify Profile")
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.spotifyGreen)
                    .foregroundColor(.white).cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func accountRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.xomifyGreen).frame(width: 24)
            Text(title).foregroundColor(.white)
            Spacer()
            Text(value).foregroundColor(.gray).lineLimit(1).truncationMode(.middle)
        }
        .padding()
    }
    
    // MARK: - Logout Button
    
    private var logoutButton: some View {
        Button { showLogoutConfirmation = true } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Logout")
            }
            .frame(maxWidth: .infinity).padding()
            .background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(12)
        }
        .padding(.top, 20)
    }
}

#Preview {
    ProfileView()
}
