import SwiftUI

struct WrappedView: View {
    @State private var viewModel = WrappedViewModel()
    @State private var showMonthPicker = false
    @State private var selectedCategory = 0 // 0: Tracks, 1: Artists, 2: Genres
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month selector header
                monthHeader
                
                // Term selector
                termSelector
                
                // Category selector
                categorySelector
                
                // Content
                ScrollView {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    } else if !viewModel.hasSelectedWrap {
                        emptyState
                    } else {
                        LazyVStack(spacing: 8) {
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
                        .padding()
                    }
                }
            }
            .background(Color.xomifyDark.ignoresSafeArea())
            .navigationTitle("Monthly Wrapped")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Get email from profile and load data
                let profileVM = ProfileViewModel()
                await profileVM.loadProfile()
                viewModel.userEmail = profileVM.email
                await viewModel.loadWraps()
            }
            .sheet(isPresented: $showMonthPicker) {
                monthPicker
            }
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        Button {
            showMonthPicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Month")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(viewModel.selectedWrapName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.xomifyCard)
        }
    }
    
    // MARK: - Term Selector
    
    private var termSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { term in
                Button {
                    Task {
                        await viewModel.selectTerm(term)
                    }
                } label: {
                    Text(term.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedTerm == term ? Color.xomifyGreen : Color.white.opacity(0.05))
                        .foregroundColor(viewModel.selectedTerm == term ? .black : .gray)
                        .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Category Selector
    
    private var categorySelector: some View {
        HStack(spacing: 8) {
            categoryButton(title: "Tracks", icon: "music.note", index: 0, count: viewModel.topTracks.count)
            categoryButton(title: "Artists", icon: "person.2.fill", index: 1, count: viewModel.topArtists.count)
            categoryButton(title: "Genres", icon: "guitars.fill", index: 2, count: viewModel.topGenres.count)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func categoryButton(title: String, icon: String, index: Int, count: Int) -> some View {
        Button {
            withAnimation { selectedCategory = index }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.caption)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(selectedCategory == index ? .xomifyPurple : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedCategory == index ? Color.xomifyPurple.opacity(0.2) : Color.white.opacity(0.03))
            .foregroundColor(selectedCategory == index ? .xomifyPurple : .gray)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Tracks Content
    
    private var tracksContent: some View {
        ForEach(Array(viewModel.topTracks.enumerated()), id: \.element.id) { index, track in
            trackRow(track, rank: index + 1)
        }
    }
    
    private func trackRow(_ track: SpotifyTrack, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.xomifyGreen)
                .frame(width: 30)
            
            AsyncImage(url: track.imageUrl) { image in
                image.resizable()
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
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
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
    
    // MARK: - Artists Content
    
    private var artistsContent: some View {
        ForEach(Array(viewModel.topArtists.enumerated()), id: \.element.id) { index, artist in
            artistRow(artist, rank: index + 1)
        }
    }
    
    private func artistRow(_ artist: SpotifyArtist, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.xomifyPurple)
                .frame(width: 30)
            
            AsyncImage(url: artist.imageUrl) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
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
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
    
    // MARK: - Genres Content
    
    private var genresContent: some View {
        let maxCount = viewModel.topGenres.first?.count ?? 1
        return ForEach(Array(viewModel.topGenres.enumerated()), id: \.element.genre) { index, item in
            genreRow(item, rank: index + 1, maxCount: maxCount)
        }
    }
    
    private func genreRow(_ item: (genre: String, count: Int), rank: Int, maxCount: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(item.genre.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(LinearGradient(colors: [.xomifyPurple, .xomifyGreen], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
            
            Text("\(item.count)")
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
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gift.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Wrapped Data")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Enroll in Monthly Wrapped from the Home tab to start tracking your listening history")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Month Picker
    
    private var monthPicker: some View {
        NavigationStack {
            List {
                ForEach(viewModel.wraps) { wrap in
                    Button {
                        Task {
                            await viewModel.selectWrap(wrap)
                        }
                        showMonthPicker = false
                    } label: {
                        HStack {
                            Text(wrap.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if viewModel.selectedWrap?.monthKey == wrap.monthKey {
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
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showMonthPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    WrappedView()
}
