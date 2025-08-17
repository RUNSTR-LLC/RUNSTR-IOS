import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @State private var currentPage = 0
    
    private let onboardingPages = [
        OnboardingPage(
            title: "RUNSTR",
            subtitle: "Fitness tracking for the decentralized web",
            imageName: "runstr_logo",
            description: "Connect with Nostr, track your activity, and share your achievements with the world.",
            isLogo: true
        ),
        OnboardingPage(
            title: "Login & Track Your Activity",
            subtitle: "Universal fitness tracking",
            imageName: "figure.run",
            description: "Sign in with Apple and automatically sync workouts from any fitness app through HealthKit integration.",
            isLogo: false
        ),
        OnboardingPage(
            title: "Post Your Workouts to Nostr",
            subtitle: "Share on the decentralized web",
            imageName: "square.and.arrow.up",
            description: "Optionally share your fitness achievements to Nostr relays and connect with the global fitness community.",
            isLogo: false
        )
    ]
    
    var body: some View {
        VStack {
            // Nostr connection status at top
            if currentPage == onboardingPages.count - 1 {
                HStack(spacing: 8) {
                    Circle()
                        .stroke(nostrService.isConnected ? Color.white : Color.gray, lineWidth: 1)
                        .background(Circle().fill(nostrService.isConnected ? Color.white : Color.clear))
                        .frame(width: 6, height: 6)
                    Text(nostrService.isConnected ? "Connected to Nostr" : "Connecting...")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 10)
            }
            
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    OnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            VStack(spacing: 16) {
                if currentPage == onboardingPages.count - 1 {
                    // Apple Sign-In Button
                    Button {
                        authService.signInWithApple()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "applelogo")
                                .font(.title3)
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(2)
                    }
                    .disabled(authService.isLoading)
                    
                } else {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(25)
                    .font(.headline)
                    
                    Button("Skip") {
                        withAnimation {
                            currentPage = onboardingPages.count - 1
                        }
                    }
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .background(Color.black)
        .foregroundColor(.white)
        .ignoresSafeArea(edges: .bottom)
    }
}



struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            if page.isLogo {
                Image(page.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
            } else {
                Image(systemName: page.imageName)
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if !page.subtitle.isEmpty {
                    Text(page.subtitle)
                        .font(.title2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                if !page.description.isEmpty {
                    Text(page.description)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let description: String
    let isLogo: Bool
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationService())
}