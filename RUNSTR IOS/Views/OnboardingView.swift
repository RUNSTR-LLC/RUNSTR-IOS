import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var currentPage = 0
    @State private var showingRunstrLogin = false
    @State private var showingNsecImport = false
    
    private let onboardingPages = [
        OnboardingPage(
            title: "RUNSTR",
            subtitle: "Put your workouts to work",
            imageName: "runstr_logo",
            description: "",
            isLogo: true
        ),
        OnboardingPage(
            title: "Enter your workouts into competitions",
            subtitle: "",
            imageName: "trophy.fill",
            description: "",
            isLogo: false
        ),
        OnboardingPage(
            title: "Join Teams, Leagues, and Events",
            subtitle: "",
            imageName: "person.3.fill",
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
                    
                    // RUNSTR Sign-In Button
                    Button {
                        showingRunstrLogin = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "key.horizontal")
                                .font(.title3)
                            Text("Continue with RUNSTR")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(2)
                    }
                    .disabled(authService.isLoading)
                    
                    // Advanced/Restore Button
                    Button {
                        showingNsecImport = true
                    } label: {
                        Text("Advanced: Restore with nsec")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
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
        .sheet(isPresented: $showingRunstrLogin) {
            RunstrSecurityWarningView {
                authService.signInWithRunstr()
                showingRunstrLogin = false
            }
        }
        .sheet(isPresented: $showingNsecImport) {
            NsecImportView { nsec in
                let success = authService.signInWithNsec(nsec)
                if success {
                    showingNsecImport = false
                }
                return success
            }
        }
    }
}

struct RunstrSecurityWarningView: View {
    let onAccept: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Important Security Notice")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("RUNSTR will generate a new Nostr identity for you. Your private key will be stored locally on your device.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Self-Custody")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("You have full control over your keys")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Backup Responsibility")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Write down your private key somewhere safe. If you lose it, your account cannot be recovered.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "gear.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export Available")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("You can export your private key from Settings after login")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Button {
                    onAccept()
                } label: {
                    Text("I Understand, Create Account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(2)
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

struct NsecImportView: View {
    let onImport: (String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var nsecInput = ""
    @State private var errorMessage = ""
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Restore RUNSTR Account")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Enter your nsec private key to restore your RUNSTR account. This should be the nsec you backed up when you first created your account.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRIVATE KEY (nsec)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("nsec1...", text: $nsecInput)
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
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button {
                        isImporting = true
                        errorMessage = ""
                        
                        let success = onImport(nsecInput)
                        if !success {
                            errorMessage = "Invalid nsec format. Please check your private key and try again."
                        }
                        
                        isImporting = false
                    } label: {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            Text(isImporting ? "Restoring..." : "Restore Account")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(2)
                    }
                    .disabled(nsecInput.isEmpty || !nsecInput.hasPrefix("nsec1") || isImporting)
                    .opacity((nsecInput.isEmpty || !nsecInput.hasPrefix("nsec1") || isImporting) ? 0.5 : 1.0)
                }
                
                VStack(spacing: 8) {
                    Text("⚠️ Security Notice")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.yellow)
                    
                    Text("Your nsec is your master key. Never share it with anyone. RUNSTR will store it locally on your device.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
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