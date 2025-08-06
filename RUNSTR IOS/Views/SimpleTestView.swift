import SwiftUI

struct SimpleTestView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var buttonTapped = false
    @State private var nip46Status = "Not tested"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("RUNSTR")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            Text("iOS App Test - NIP-46 Integration")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(buttonTapped ? "Button Works!" : "")
                .font(.title2)
                .foregroundColor(.green)
            
            Button("Test Button") {
                buttonTapped = true
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Divider()
                .background(Color.gray)
            
            VStack(spacing: 16) {
                Text("nsec bunker Integration Test")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Status: \(nip46Status)")
                    .font(.body)
                    .foregroundColor(.gray)
                
                if let connectionManager = authService.nip46ConnectionManager {
                    Text("Connection: \(connectionManager.displayStatus)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Button("Test nsec bunker Sign-In") {
                    Task {
                        nip46Status = "Testing..."
                        await testNsecBunkerSignIn()
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(authService.isLoading)
                
                if authService.isAuthenticated {
                    VStack(spacing: 8) {
                        Text("✅ Authenticated!")
                            .foregroundColor(.green)
                            .font(.title3)
                        
                        if let user = authService.currentUser {
                            Text("Method: \(user.loginMethod.rawValue)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func testNsecBunkerSignIn() async {
        do {
            await authService.signInWithNsecBunker()
            nip46Status = authService.isAuthenticated ? "Success!" : "Failed to authenticate"
        } catch {
            nip46Status = "Error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SimpleTestView()
        .environmentObject(AuthenticationService())
}