import SwiftUI

struct SimpleTestView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var buttonTapped = false
    @State private var authStatus = "Not tested"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("RUNSTR")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("iOS App Test - Login System")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(buttonTapped ? "Button Works!" : "")
                .font(.title2)
                .foregroundColor(.white)
            
            Button("Test Button") {
                buttonTapped = true
            }
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(10)
            
            Divider()
                .background(Color.gray)
            
            VStack(spacing: 16) {
                Text("Authentication Test")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Status: \(authStatus)")
                    .font(.body)
                    .foregroundColor(.gray)
                
                HStack(spacing: 16) {
                    Button("Test Apple Login") {
                        Task {
                            authStatus = "Testing Apple Sign-In..."
                            await testAppleSignIn()
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .disabled(authService.isLoading)
                    
                    Button("Test RUNSTR Login") {
                        authStatus = "Testing RUNSTR Sign-In..."
                        testRunstrSignIn()
                    }
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(authService.isLoading)
                }
                
                if authService.isAuthenticated {
                    VStack(spacing: 8) {
                        Text("✅ Authenticated!")
                            .foregroundColor(.white)
                            .font(.title3)
                        
                        if let user = authService.currentUser {
                            Text("Method: \(user.loginMethod.rawValue)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("npub: \(user.nostrPublicKey)")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Button("Sign Out") {
                            authService.signOut()
                            authStatus = "Signed out"
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.runstrGrayDark)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func testAppleSignIn() async {
        authService.signInWithApple()
        authStatus = authService.isAuthenticated ? "Success!" : "Apple Sign-In initiated"
    }
    
    private func testRunstrSignIn() {
        authService.signInWithApple()
        authStatus = authService.isAuthenticated ? "Success!" : "Apple Sign-In completed"
    }
}

#Preview {
    SimpleTestView()
        .environmentObject(AuthenticationService())
}