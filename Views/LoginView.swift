import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Username", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                
                Toggle("Remember Me", isOn: $viewModel.rememberMe)
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Button("Login") {
                    Task { await viewModel.login() }
                }
                .disabled(!viewModel.isButtonEnabled)
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $viewModel.loginSuccess) {
                WelcomeView(viewModel: viewModel)
            }
            .navigationTitle("Login")
        }
    }
}

