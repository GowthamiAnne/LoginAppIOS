import Foundation

struct LoginState {
    var username: String = ""
    var password: String = ""
    var isButtonEnabled: Bool = false
    var errorMessage: String = ""
    var failureCount: Int = 0
    var isLocked: Bool = false
    var isOffline: Bool = false
    var isConnected: Bool = true
    var rememberMe: Bool = false
}

