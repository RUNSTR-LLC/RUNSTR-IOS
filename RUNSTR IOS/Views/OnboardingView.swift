import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var currentPage = 0
    @State private var showingNostrLogin = false
    @State private var npubInput = ""
    
    private let onboardingPages = [
        OnboardingPage(
            title: "RUNSTR",
            subtitle: "Run. Earn. Connect.",
            imageName: "runstr_logo",
            description: "The fitness app that rewards you with Bitcoin for staying active.",
            isLogo: true
        ),
        OnboardingPage(
            title: "Join Teams",
            subtitle: "Build community and stay motivated",
            imageName: "person.3.fill",
            description: "Join teams to stay motivated and participate in group challenges with friends and fellow runners.",
            isLogo: false
        ),
        OnboardingPage(
            title: "Compete",
            subtitle: "Enter competitions for bigger rewards",
            imageName: "trophy.fill",
            description: "Participate in challenges and events to compete with other users and win Bitcoin prizes.",
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
                    
                    // nsec bunker Sign-In Button (Primary Nostr option)
                    Button {
                        Task {
                            await authService.signInWithNsecBunker()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "key.radiowaves.forward")
                                .font(.title3)
                            Text("Continue with nsec bunker")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(2)
                    }
                    .disabled(authService.isLoading)
                    
                    // Legacy Nostr Sign-In Button
                    Button {
                        showingNostrLogin = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .font(.title3)
                            Text("Continue with npub")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Button("Continue with Email") {
                        // Email signup would go here
                    }
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .medium))
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
        .sheet(isPresented: $showingNostrLogin) {
            NostrLoginView(npubInput: $npubInput) {
                authService.signInWithNostr(npub: npubInput)
                showingNostrLogin = false
            }
        }
    }
}

struct NostrLoginView: View {
    @Binding var npubInput: String
    let onLogin: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Manual Nostr Connection")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Enter your npub for legacy Nostr integration. For better security, use nsec bunker instead.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOSTR PUBLIC KEY")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("npub1...", text: $npubInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button {
                        onLogin()
                    } label: {
                        Text("Connect Account")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(2)
                    }
                    .disabled(npubInput.isEmpty || !npubInput.hasPrefix("npub1"))
                    .opacity(npubInput.isEmpty || !npubInput.hasPrefix("npub1") ? 0.5 : 1.0)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
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
    let isLogo: Bool
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationService())
}