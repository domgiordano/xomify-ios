import SwiftUI

struct ReleaseRadarView: View {
    @State private var viewModel = ReleaseRadarViewModel()
    @State private var showWeekPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week selector header
                weekHeader
                
                // Stats bar
                if let stats = viewModel.displayStats {
                    statsBar(stats)
                }
                
                // Content
                ScrollView {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    } else if viewModel.displayReleases.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.displayReleases) { release in
                                releaseCard(release)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.xomifyDark.ignoresSafeArea())
            .navigationTitle("Release Radar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        if viewModel.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isRefreshing)
                }
            }
            .task {
                // Get email from profile and load data
                let profileVM = ProfileViewModel()
                await profileVM.loadProfile()
                viewModel.userEmail = profileVM.email
                await viewModel.loadData()
            }
            .sheet(isPresented: $showWeekPicker) {
                weekPicker
            }
        }
    }
    
    // MARK: - Week Header
    
    private var weekHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Week")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(viewModel.displayWeekName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let dateRange = viewModel.displayDateRange {
                    Text(dateRange)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Week picker button
            Button {
                showWeekPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text("Change Week")
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(viewModel.historyWeeks.count <= 1)
        }
        .padding()
        .background(Color.xomifyCard)
    }
    
    // MARK: - Stats Bar
    
    private func statsBar(_ stats: ReleaseStats) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(stats.releaseCount)", label: "Releases", color: .xomifyGreen)
            Divider().frame(height: 30).background(Color.gray.opacity(0.3))
            statItem(value: "\(stats.artistCount)", label: "Artists", color: .xomifyPurple)
            Divider().frame(height: 30).background(Color.gray.opacity(0.3))
            statItem(value: "\(stats.trackCount)", label: "Tracks", color: .blue)
            Divider().frame(height: 30).background(Color.gray.opacity(0.3))
            statItem(value: "\(stats.albumCount)/\(stats.singleCount)", label: "Albums/Singles", color: .orange)
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Release Card
    
    private func releaseCard(_ release: Release) -> some View {
        HStack(spacing: 14) {
            // Album art
            AsyncImage(url: release.image) { image in
                image.resizable()
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 70, height: 70)
            .cornerRadius(8)
            
            // Release info
            VStack(alignment: .leading, spacing: 6) {
                Text(release.albumName ?? "Unknown Album")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(release.artistName ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Album type badge
                    if let type = release.albumType {
                        Text(type.capitalized)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(badgeColor(for: type).opacity(0.2))
                            .foregroundColor(badgeColor(for: type))
                            .cornerRadius(4)
                    }
                    
                    // Track count
                    if let tracks = release.totalTracks {
                        Text("\(tracks) tracks")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Release date
                    if let date = release.releaseDate {
                        Text(formatDate(date))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Spotify link
            if let url = release.spotify {
                Link(destination: url) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(Color.xomifyCard)
        .cornerRadius(12)
    }
    
    private func badgeColor(for type: String) -> Color {
        switch type.lowercased() {
        case "album": return .xomifyPurple
        case "single": return .xomifyGreen
        case "ep": return .blue
        default: return .gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Releases Yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Release data is updated weekly on Saturday mornings. Check back then for new music from your followed artists!")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Week Picker
    
    private var weekPicker: some View {
        NavigationStack {
            List {
                ForEach(viewModel.historyWeeks) { week in
                    Button {
                        viewModel.selectWeek(week)
                        showWeekPicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(week.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                if let dateRange = week.dateRange {
                                    Text(dateRange)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            if let stats = week.stats {
                                Text("\(stats.releaseCount ?? 0) releases")
                                    .font(.caption)
                                    .foregroundColor(.xomifyGreen)
                            }
                            
                            if viewModel.isWeekSelected(week) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.xomifyGreen)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.xomifyDark)
            .scrollContentBackground(.hidden)
            .navigationTitle("Select Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showWeekPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Week Release Count Extension

extension ReleaseRadarWeek {
    var releaseCount: Int? {
        stats?.releaseCount ?? releases?.count
    }
}

#Preview {
    ReleaseRadarView()
}
