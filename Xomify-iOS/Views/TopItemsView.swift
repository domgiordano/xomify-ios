import SwiftUI

struct TopItemsView: View {
    @State private var viewModel = TopItemsViewModel()
    @State private var selectedCategory = 0 // 0: Tracks, 1: Artists, 2: Genres
    @State private var selectedTerm: TimeRange = .shortTerm
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category selector
                categorySelector
                
                // Term selector
                termSelector
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 40)
                        } else {
                            switch selectedCategory {
                            case 0:
                                tracksContent
                            case 1:
                                artistsContent
                            case 2:
                                genresContent
                            default:
                                EmptyView()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
            }
            .background(Color.xomifyDark.ignoresSafeArea())
            .navigationTitle("Top Items")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
    }
    
    private var categorySelector: some View {
        HStack(spacing: 8) {
            categoryButton(title: "Tracks", icon: "music.note", index: 0)
            categoryButton(title: "Artists", icon: "person.2.fill", index: 1)
            categoryButton(title: "Genres", icon: "guitars.fill", index: 2)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.xomifyCard)
    }
    
    private func categoryButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation { selectedCategory = index }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedCategory == index ? Color.xomifyPurple.opacity(0.3) : Color.clear)
            .foregroundColor(selectedCategory == index ? .xomifyPurple : .gray)
            .cornerRadius(10)
        }
    }
    
    private var termSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { term in
                Button {
                    withAnimation { selectedTerm = term }
                } label: {
                    Text(term.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTerm == term ? Color.xomifyGreen : Color.white.opacity(0.05))
                        .foregroundColor(selectedTerm == term ? .black : .gray)
                        .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Tracks Content
    
    private var tracksContent: some View {
        let tracks = getTracks(for: selectedTerm)
        return ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
            trackRow(track, rank: index + 1)
        }
    }
    
    private func getTracks(for term: TimeRange) -> [SpotifyTrack] {
        switch term {
        case .shortTerm: return viewModel.shortTermTracks
        case .mediumTerm: return viewModel.mediumTermTracks
        case .longTerm: return viewModel.longTermTracks
        }
    }
    
    private func trackRow(_ track: SpotifyTrack, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.xomifyGreen)
                .frame(width: 30)
            
            // Album art
            AsyncImage(url: track.imageUrl) { image in
                image.resizable()
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            
            // Track info
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
            
            // Duration
            Text(track.duration)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
    
    // MARK: - Artists Content
    
    private var artistsContent: some View {
        let artists = getArtists(for: selectedTerm)
        return ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
            artistRow(artist, rank: index + 1)
        }
    }
    
    private func getArtists(for term: TimeRange) -> [SpotifyArtist] {
        switch term {
        case .shortTerm: return viewModel.shortTermArtists
        case .mediumTerm: return viewModel.mediumTermArtists
        case .longTerm: return viewModel.longTermArtists
        }
    }
    
    private func artistRow(_ artist: SpotifyArtist, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.xomifyPurple)
                .frame(width: 30)
            
            // Artist image
            AsyncImage(url: artist.imageUrl) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // Artist info
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
            
            // Popularity
            if let popularity = artist.popularity {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(popularity)")
                        .font(.caption)
                }
                .foregroundColor(.yellow.opacity(0.8))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
    
    // MARK: - Genres Content
    
    private var genresContent: some View {
        let genres = getGenres(for: selectedTerm)
        return ForEach(Array(genres.enumerated()), id: \.element.name) { index, genre in
            genreRow(genre, rank: index + 1, maxCount: genres.first?.count ?? 1)
        }
    }
    
    private func getGenres(for term: TimeRange) -> [(name: String, count: Int)] {
        switch term {
        case .shortTerm: return viewModel.shortTermGenres
        case .mediumTerm: return viewModel.mediumTermGenres
        case .longTerm: return viewModel.longTermGenres
        }
    }
    
    private func genreRow(_ genre: (name: String, count: Int), rank: Int, maxCount: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            // Genre info
            VStack(alignment: .leading, spacing: 8) {
                Text(genre.name.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(LinearGradient(colors: [.xomifyPurple, .xomifyGreen], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(genre.count) / CGFloat(maxCount), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            // Count
            Text("\(genre.count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.xomifyGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.xomifyGreen.opacity(0.15))
                .cornerRadius(12)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
}

#Preview {
    TopItemsView()
}
