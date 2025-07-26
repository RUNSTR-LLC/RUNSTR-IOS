import SwiftUI

struct SimpleTestView: View {
    @State private var buttonTapped = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("RUNSTR")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            Text("iOS App Test")
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    SimpleTestView()
}