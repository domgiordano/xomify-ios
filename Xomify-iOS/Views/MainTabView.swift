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
            .navigationTitle("Top")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Your Top")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Based on listening history")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(TopItemsViewModel.TopItemsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.onTabChange(tab)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.selectedTab == tab ? primaryPurple.opacity(0.3) : Color.clear)
                    )
                    .foregroundColor(viewModel.selectedTab == tab ? primaryPurple : .gray)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
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
                    case .genres:
                        ForEach(Array(viewModel.genres.enumerated()), id: \.element.id) { index, genre in
                            genreRow(genre: genre, rank: index + 1, maxCount: viewModel.genres.first?.count ?? 1)
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
    
    private func genreRow(genre: TopItemsViewModel.GenreCount, rank: Int, maxCount: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rank <= 3 ? primaryGreen : .gray)
                .frame(width: 30)
            
            // Genre icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryPurple.opacity(0.6), primaryGreen.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "music.mic")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(genre.name.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [primaryPurple, primaryGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(genre.count) / CGFloat(maxCount), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            Text("\(genre.count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryGreen)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct ReleaseRadarView: View {
    
    @State private var viewModel = ReleaseRadarViewModel()
    
    private let primaryPurple = Color(red: 156/255, green: 10/255, blue: 191/255)
    private let primaryGreen = Color(red: 27/255, green: 220/255, blue: 111/255)
    private let darkBackground = Color(red: 10/255, green: 10/255, blue: 20/255)
    private let cardBackground = Color(red: 26/255, green: 26/255, blue: 46/255)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Mode Toggle
                viewModeSelector
                
                // Week Picker (for history)
                if viewModel.selectedView == .history && !viewModel.pastWeeks.isEmpty {
                    weekPicker
                }
                
                // Stats Header
                if let week = viewModel.displayedWeek {
                    statsHeader(week: week)
                }
                
                // Content
                content
            }
            .background(darkBackground.ignoresSafeArea())
            .navigationTitle("Releases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Release Radar")
                            .font(.headline)
                            .foregroundColor(.white)
                        if let week = viewModel.displayedWeek {
                            Text(week.dateRangeDisplay)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                if viewModel.selectedView == .current {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            if viewModel.isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(primaryGreen)
                            }
                        }
                        .disabled(viewModel.isRefreshing)
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - View Mode Selector
    
    private var viewModeSelector: some View {
        HStack(spacing: 4) {
            ForEach(ReleaseRadarViewModel.ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.onViewModeChange(mode)
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.selectedView == mode ? primaryPurple : Color.clear)
                        )
                        .foregroundColor(viewModel.selectedView == mode ? .white : .gray)
                }
            }
        }
        .padding(4)
        .background(cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Week Picker
    
    private var weekPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.pastWeeks) { week in
                    Button {
                        viewModel.selectWeek(week)
                    } label: {
                        VStack(spacing: 4) {
                            Text(week.dateRangeDisplay)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("\(week.releases.count) releases")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.selectedWeek?.weekKey == week.weekKey ? primaryGreen : cardBackground)
                        )
                        .foregroundColor(viewModel.selectedWeek?.weekKey == week.weekKey ? .black : .white)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Stats Header
    
    private func statsHeader(week: ReleaseRadarWeek) -> some View {
        HStack(spacing: 16) {
            statPill(count: viewModel.albumCount, label: "Albums", color: primaryPurple)
            statPill(count: viewModel.singleCount, label: "Singles", color: primaryGreen)
            statPill(count: viewModel.featureCount, label: "Features", color: .orange)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func statPill(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(cardBackground)
        .cornerRadius(10)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Spacer()
        } else if let error = viewModel.errorMessage {
            Spacer()
            errorView(error)
            Spacer()
        } else if viewModel.displayedReleases.isEmpty {
            Spacer()
            emptyView
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.displayedReleases) { release in
                        releaseRow(release)
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Release Row
    
    private func releaseRow(_ release: Release) -> some View {
        HStack(spacing: 12) {
            // Album Art
            AsyncImage(url: release.image) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(cardBackground)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 56, height: 56)
            .cornerRadius(8)
            
            // Release Info
            VStack(alignment: .leading, spacing: 4) {
                Text(release.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(release.artistName)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Type badge
                    Text(release.typeDisplay)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor(release.albumType).opacity(0.2))
                        .foregroundColor(typeColor(release.albumType))
                        .cornerRadius(4)
                    
                    // Track count
                    if release.totalTracksInt > 1 {
                        Text("\(release.totalTracksInt) tracks")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Spotify link indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private func typeColor(_ type: String?) -> Color {
        switch type?.lowercased() {
        case "album": return primaryPurple
        case "single": return primaryGreen
        case "appears_on": return .orange
        default: return .gray
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No releases this week")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Check back later for new music from artists you follow")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await viewModel.loadData() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(primaryPurple)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .padding()
    }
}

struct WrappedView: View {
    
    @State private var viewModel = WrappedViewModel()
    @State private var showMonthPicker = false
    
    private let primaryPurple = Color(red: 156/255, green: 10/255, blue: 191/255)
    private let primaryGreen = Color(red: 27/255, green: 220/255, blue: 111/255)
    private let darkBackground = Color(red: 10/255, green: 10/255, blue: 20/255)
    private let cardBackground = Color(red: 26/255, green: 26/255, blue: 46/255)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else if !viewModel.hasWraps {
                    emptyState
                } else {
                    // Month Selector
                    monthSelector
                    
                    // Tab Selector
                    tabSelector
                    
                    // Content
                    content
                }
            }
            .background(darkBackground.ignoresSafeArea())
            .navigationTitle("Wrapped")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Monthly Wrapped")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Your top music each month")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .task {
                await viewModel.loadWraps()
            }
        }
    }
    
    // MARK: - Month Selector
    
    private var monthSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.wraps) { wrap in
                    Button {
                        Task { await viewModel.selectWrap(wrap) }
                    } label: {
                        Text(wrap.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(viewModel.selectedWrap?.monthKey == wrap.monthKey
                                          ? primaryPurple
                                          : cardBackground)
                            )
                            .foregroundColor(viewModel.selectedWrap?.monthKey == wrap.monthKey
                                           ? .white
                                           : .gray)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(WrappedViewModel.WrappedTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.onTabChange(tab)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.selectedTab == tab ? primaryGreen.opacity(0.3) : Color.clear)
                    )
                    .foregroundColor(viewModel.selectedTab == tab ? primaryGreen : .gray)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(cardBackground)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingDetails {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Spacer()
        } else if let error = viewModel.errorMessage {
            Spacer()
            errorView(error)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    switch viewModel.selectedTab {
                    case .tracks:
                        ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                            wrappedTrackRow(track: track, rank: index + 1)
                        }
                    case .artists:
                        ForEach(Array(viewModel.artists.enumerated()), id: \.element.id) { index, artist in
                            wrappedArtistRow(artist: artist, rank: index + 1)
                        }
                    case .genres:
                        ForEach(Array(viewModel.genres.enumerated()), id: \.element.id) { index, genre in
                            wrappedGenreRow(genre: genre, rank: index + 1, maxCount: viewModel.genres.first?.count ?? 1)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Track Row
    
    private func wrappedTrackRow(track: SpotifyTrack, rank: Int) -> some View {
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
    
    // MARK: - Artist Row
    
    private func wrappedArtistRow(artist: SpotifyArtist, rank: Int) -> some View {
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
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Genre Row
    
    private func wrappedGenreRow(genre: WrappedViewModel.GenreCount, rank: Int, maxCount: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rank <= 3 ? primaryGreen : .gray)
                .frame(width: 30)
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryPurple.opacity(0.6), primaryGreen.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "music.mic")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(genre.name.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [primaryPurple, primaryGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(genre.count) / CGFloat(maxCount), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            Text("\(genre.count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryGreen)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Wrapped Data Yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Your monthly music stats will appear here once they're generated")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await viewModel.loadWraps() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(primaryPurple)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .padding()
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
