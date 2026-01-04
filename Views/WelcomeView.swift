import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome, \(viewModel.username)!")
                .font(.title)
                .bold()
            
            Button("Logout") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Welcome")
        .navigationBarBackButtonHidden(true) // Prevent swipe back
    }
}

