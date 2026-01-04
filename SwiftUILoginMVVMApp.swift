import SwiftUI

@main
struct SwiftUILoginMVVMApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView(viewModel: LoginViewModel())
        }
    }
}

