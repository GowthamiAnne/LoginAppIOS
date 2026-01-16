import SwiftUI
import Combine

@MainActor
final class LoginViewModel: ObservableObject {

    @Published var state = LoginState()
    private let authService: AuthServiceProtocol
    private let networkMonitor: NetworkMonitorProtocol

    private let maxFailures = 3
    private let lockoutMinutes = 15

    private var cancellables = Set<AnyCancellable>()
    private var loginTask: Task<Void, Never>?

    init(authService: AuthServiceProtocol? = nil,
         networkMonitor: NetworkMonitorProtocol? = nil) {
        self.authService = authService ?? AuthService()
        self.networkMonitor = networkMonitor ?? MockNetworkMonitor()

        setupNetworkBinding()
        restoreSessionIfPossible()
    }

    // MARK: - Session Restoration
    public func restoreSessionIfPossible() {
        if KeychainManager.shared.getToken() != nil {
            state.loginSuccess = true
        }
    }

    // MARK: - Network Handling
    private func setupNetworkBinding() {
        networkMonitor.isOnlinePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] online in
                guard let self else { return }
                self.state.isOffline = !online

                // Cancel running login if network goes offline
                if !online {
                    self.loginTask?.cancel()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Login
    func login() async {
        guard state.isButtonEnabled else { return }

        loginTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Locked out check
                if state.isLocked {
                    let minutes = (state.remainingLockoutSeconds ?? 0 + 59) / 60
                    state.errorMessage = LoginErrorMessage.locked(minutes: minutes)
                    state.loginSuccess = false
                    return
                }

                // Offline check
                if state.isOffline {
                    state.loginSuccess = false
                    state.errorMessage = LoginErrorMessage.noInternet
                    return
                }

                // Perform login
                let token = try await authService.login(
                    username: state.username,
                    password: state.password
                )

                try Task.checkCancellation() // check immediately after login

                if state.isOffline {
                    state.loginSuccess = false
                    state.errorMessage = LoginErrorMessage.noInternet
                    return
                }

                // Success
                if state.rememberMe {
                    KeychainManager.shared.saveToken(token)
                }

                state.loginSuccess = true
                state.failureCount = 0
                state.errorMessage = ""
                state.lockoutExpiresAt = nil

            } catch is CancellationError {
                // ✅ Immediately mark login as cancelled
                state.loginSuccess = false
                state.errorMessage = ""
                return
            } catch let authError as AuthError {
                state.failureCount += 1
                if state.failureCount >= maxFailures {
                    state.lockoutExpiresAt = Date().addingTimeInterval(TimeInterval(lockoutMinutes * 60))
                    state.errorMessage = LoginErrorMessage.locked(minutes: lockoutMinutes)
                    return
                }
                switch authError {
                case .invalidCredentials:
                    state.errorMessage = LoginErrorMessage.invalidCredentials
                case .serverError:
                    state.errorMessage = LoginErrorMessage.serverError
                }
            } catch {
                state.failureCount += 1
                state.errorMessage = LoginErrorMessage.generic
            }
        }

        do {
            try await loginTask?.value
        } catch {
            // Already handled inside the Task
        }
    }

    // MARK: - Remember Me
    func toggleRememberMe() {
        state.rememberMe.toggle()
    }

    // MARK: - Reset / Logout
    func reset() {
        KeychainManager.shared.clearToken()
        state = LoginState()
    }

    /// Reset lockout if expired
    func resetLockoutIfExpired() {
        if let expiresAt = state.lockoutExpiresAt, Date() >= expiresAt {
            state.lockoutExpiresAt = nil
            state.failureCount = 0
            state.errorMessage = ""
        }
    }
}

