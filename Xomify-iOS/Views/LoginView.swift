import SwiftUI

/// Login screen with Spotify authentication
struct LoginView: View {
    
    @State private var viewModel = LoginViewModel()
    
    // Xomify brand colors
    private let primaryPurple = Color(red: 156/255, green: 10/255, blue: 191/255)
    private let primaryGreen = Color(red: 27/255, green: 220/255, blue: 111/255)
    private let darkBackground = Color(red: 10/255, green: 10/255, blue: 20/255)
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    darkBackground,
                    Color(red: 26/255, green: 26/255, blue: 46/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and title
                VStack(spacing: 20) {
                    // Logo placeholder - replace with your actual logo
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryPurple, primaryGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Text("X")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text("XOMIFY")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [primaryPurple, primaryGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Your Music. Your Stats.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Login button
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await viewModel.login()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "music.note")
                                    .font(.title2)
                            }
                            
                            Text(viewModel.isLoading ? "Connecting..." : "Continue with Spotify")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 30/255, green: 215/255, blue: 96/255)) // Spotify green
                        .foregroundColor(.black)
                        .cornerRadius(30)
                    }
                    .disabled(viewModel.isLoading)
                    
                    Text("We'll never post without your permission")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .alert("Login Failed", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
}

#Preview {
    LoginView()
}
