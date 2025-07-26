import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var currentPage = 0
    
    private let onboardingPages = [
        OnboardingPage(
            title: "Get Paid to Run",
            subtitle: "Earn real Bitcoin for every workout",
            imageName: "bitcoin.circle.fill",
            description: "Track your runs and walks to earn sats. The more you move, the more you earn."
        ),
        OnboardingPage(
            title: "Join Teams",
            subtitle: "Build community and stay motivated",
            imageName: "person.3.fill",
            description: "Join teams to stay motivated and participate in group challenges with friends and fellow runners."
        ),
        OnboardingPage(
            title: "Compete & Win",
            subtitle: "Enter competitions for bigger rewards",
            imageName: "trophy.fill",
            description: "Participate in challenges and events to compete with other users and win Bitcoin prizes."
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
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        authService.signInWithApple()
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(25)
                    
                    Button("Continue with Email") {
                        // Email signup would go here
                    }
                    .foregroundColor(.orange)
                    .padding(.vertical, 8)
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
            
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
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
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationService())
}