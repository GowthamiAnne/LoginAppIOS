import SwiftUI
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    
    // MARK: - Published properties
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var rememberMe: Bool = false
    @Published var isButtonEnabled: Bool = false
    @Published var isLocked: Bool = false
    @Published var isOffline: Bool = false
    @Published var errorMessage: String = ""
    @Published var loginSuccess: Bool = false
    @Published var failureCount: Int = 0
    
    // MARK: - Dependencies
    private let authService: AuthServiceProtocol
    private let networkMonitor: NetworkMonitorProtocol
    
    // MARK: - Constants
    private let maxFailures = 3
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init(authService: AuthServiceProtocol = AuthService(),
         networkMonitor: NetworkMonitorProtocol = NetworkMonitor()) {
        self.authService = authService
        self.networkMonitor = networkMonitor
        setupBindings()
    }
    
    // MARK: - Combine bindings
    private func setupBindings() {
        // Enable/disable login button based on fields and offline/lock state
        Publishers.CombineLatest4($username, $password, $isLocked, $isOffline)
            .map { username, password, isLocked, isOffline in
                !username.isEmpty && !password.isEmpty && !isLocked && !isOffline
            }
            .assign(to: &$isButtonEnabled)
        
        // Observe network changes
        networkMonitor.isOnlinePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] online in
                self?.isOffline = !online
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Login action
    func login() async {
        guard isButtonEnabled else { return }
        if isOffline {
            errorMessage = "No internet connection"
            return
        }
        
        do {
            let token = try await authService.login(username: username, password: password)
            
            // Save token if Remember Me is enabled
            if rememberMe {
                UserDefaults.standard.set(token, forKey: "authToken")
            }
            
            // Reset failure count and update success state
            loginSuccess = true
            errorMessage = ""
            failureCount = 0
            
        } catch is CancellationError {
            // Task cancelled due to app background → ignore
            return
        } catch let authError as AuthError {
            failureCount += 1
            // Use default string if errorDescription is nil
            errorMessage = authError.errorDescription ?? "Login failed"
            
            if failureCount >= maxFailures {
                isLocked = true
                errorMessage = "Too many failed attempts. Account locked."
            }
        }
         catch {
            failureCount += 1
            errorMessage = "Something went wrong. Try again."
        }
    }
    
    // MARK: - Toggle Remember Me
    func toggleRememberMe() {
        rememberMe.toggle()
    }
    
    // MARK: - Reset login state
    func reset() {
        username = ""
        password = ""
        rememberMe = false
        isButtonEnabled = false
        isLocked = false
        isOffline = false
        errorMessage = ""
        loginSuccess = false
        failureCount = 0
    }
}

