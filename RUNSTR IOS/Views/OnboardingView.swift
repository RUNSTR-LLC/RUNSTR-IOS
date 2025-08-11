import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var currentPage = 0
    
    private let onboardingPages = [
        OnboardingPage(
            title: "RUNSTR",
            subtitle: "Track your cardio workouts",
            imageName: "runstr_logo",
            description: "",
            isLogo: true
        ),
        OnboardingPage(
            title: "Track Running, Walking & Cycling",
            subtitle: "",
            imageName: "figure.run",
            description: "",
            isLogo: false
        ),
        OnboardingPage(
            title: "Save Locally or Share on Nostr",
            subtitle: "",
            imageName: "square.and.arrow.up",
            description: "",
            isLogo: false
        )
    ]
    
    var body: some View {
        VStack {
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
                    .background(Color.orange)
                    .foregroundColor(.white)
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