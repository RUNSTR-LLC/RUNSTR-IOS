import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @State private var currentPage = 0
    @State private var showingNostrLogin = false
    
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
                    
                    // Nostr Login Button
                    Button {
                        showingNostrLogin = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "key.horizontal")
                                .font(.title3)
                            Text("Login with Nostr")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.orange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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
        .sheet(isPresented: $showingNostrLogin) {
            NostrLoginSheet()
                .environmentObject(authService)
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

struct NostrLoginSheet: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var nsecInput = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingKeyGenerator = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Login with Nostr")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your private key (nsec) to sign in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Private Key (nsec)")
                        .font(.headline)
                    
                    SecureField("nsec1...", text: $nsecInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await signInWithKey()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Signing In..." : "Sign In")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(nsecInput.isEmpty ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(nsecInput.isEmpty || isLoading)
                    
                    Button {
                        showingKeyGenerator = true
                    } label: {
                        Text("Generate New Nostr Key")
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Nostr Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingKeyGenerator) {
            NostrKeyGeneratorSheet()
                .environmentObject(authService)
        }
    }
    
    private func signInWithKey() async {
        isLoading = true
        errorMessage = ""
        
        let success = await authService.signInWithNostrKey(nsecInput)
        
        await MainActor.run {
            isLoading = false
            if success {
                dismiss()
            } else {
                errorMessage = "Invalid private key. Please check your nsec and try again."
            }
        }
    }
}

struct NostrKeyGeneratorSheet: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var generatedKeyPair: NostrKeyPair?
    @State private var isLoading = false
    @State private var keyCopied = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.viewfinder")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Generate Nostr Keys")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("We'll create a new Nostr identity for you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                if let keyPair = generatedKeyPair {
                    VStack(spacing: 16) {
                        // Public Key
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Public Key (npub)")
                                .font(.headline)
                            
                            Text(keyPair.publicKey)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Private Key
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Private Key (nsec)")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = keyPair.privateKey
                                    keyCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        keyCopied = false
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: keyCopied ? "checkmark" : "doc.on.doc")
                                        Text(keyCopied ? "Copied!" : "Copy")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                }
                            }
                            
                            Text(keyPair.privateKey)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Text("⚠️ Save your private key securely. You'll need it to access your account.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    Button {
                        Task {
                            await useGeneratedKey()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Creating Account..." : "Use This Key")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    
                } else {
                    Button {
                        generateNewKey()
                    } label: {
                        Text("Generate New Key")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Generate Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateNewKey() {
        // Use the existing NostrService method to generate keys
        if let keyPair = NostrService().generateRunstrKeys() {
            generatedKeyPair = keyPair
        }
    }
    
    private func useGeneratedKey() async {
        guard let keyPair = generatedKeyPair else { return }
        
        isLoading = true
        let success = await authService.signInWithNostrKey(keyPair.privateKey)
        
        await MainActor.run {
            isLoading = false
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationService())
}