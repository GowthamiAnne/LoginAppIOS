import Foundation
import Combine

struct LoginState {
    // MARK: - Inputs
    var username: String = ""
    var password: String = ""
    var rememberMe: Bool = false

    // MARK: - Status
    var failureCount: Int = 0
    var lockoutExpiresAt: Date? = nil
    var isOffline: Bool = false
    var loginSuccess: Bool = false
    var errorMessage: String = ""

    // MARK: - Computed properties
    var isLocked: Bool {
        guard let expiresAt = lockoutExpiresAt else { return false }
        return Date() < expiresAt
    }

    var remainingLockoutSeconds: Int? {
        guard let expiresAt = lockoutExpiresAt else { return nil }
        let seconds = Int(expiresAt.timeIntervalSince(Date()))
        return max(seconds, 0)
    }

    var isButtonEnabled: Bool {
        !username.isEmpty &&
        password.count >= 8 &&
        !isLocked &&
        !isOffline
    }
}

