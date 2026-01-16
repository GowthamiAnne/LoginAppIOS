import XCTest
@testable import LoginAppIOS

@MainActor
class LoginViewModelTests: XCTestCase {

    var viewModel: LoginViewModel!
    var mockAuth: MockAuthService!
    var mockNetwork: MockNetworkMonitor!

    override func setUp() {
        super.setUp()
        mockAuth = MockAuthService()
        mockNetwork = MockNetworkMonitor()
        viewModel = LoginViewModel(authService: mockAuth, networkMonitor: mockNetwork)
    }

    override func tearDown() {
        viewModel = nil
        mockAuth = nil
        mockNetwork = nil
        super.tearDown()
    }

    // Validation enables/disables button
    func testButtonEnabledValidation() {
        viewModel.state.username = ""
        viewModel.state.password = ""
        XCTAssertFalse(viewModel.state.isButtonEnabled)
        
        viewModel.state.username = "admin"
        viewModel.state.password = "12345678"
        XCTAssertTrue(viewModel.state.isButtonEnabled)
    }

    // Success → loginSuccess true
    func testLoginSuccessUpdatesState() async {
        viewModel.state.username = "anne"
        viewModel.state.password = "gowthami"
        mockAuth.shouldSucceed = true
        
        await viewModel.login()
        XCTAssertTrue(viewModel.state.loginSuccess)
        XCTAssertEqual(viewModel.state.failureCount, 0)
        XCTAssertEqual(viewModel.state.errorMessage, "")
    }

    // Error increments failure count
    func testLoginFailureIncrementsCount() async {
        viewModel.state.username = "user"
        viewModel.state.password = "gowthami"
        mockAuth.shouldSucceed = false
        
        await viewModel.login()
        XCTAssertEqual(viewModel.state.failureCount, 1)
        
        await viewModel.login()
        XCTAssertEqual(viewModel.state.failureCount, 2)
    }

    // Lockout after 3 failures
    func testLockoutAfterThreeFailures() async {
        // Arrange
        viewModel.state.username = "user"
        viewModel.state.password = "wrongpassword"
        mockAuth.shouldSucceed = false
        
        // Act - 3 failed attempts
        await viewModel.login()
        await viewModel.login()
        await viewModel.login()
        
        // Assert
        XCTAssertTrue(viewModel.state.isLocked, "Account should be locked after 3 failed attempts")
        
        // Check lockout error message contains "Try again in" (dynamic minutes)
        XCTAssertTrue(
            viewModel.state.errorMessage.contains("Try again in"),
            "Error message should indicate lockout duration"
        )
        
        // Optional: Check lockoutExpiresAt is set ~15 minutes from now
        if let lockout = viewModel.state.lockoutExpiresAt {
            let expected = Date().addingTimeInterval(TimeInterval(15 * 60))
            let difference = abs(lockout.timeIntervalSince(expected))
            XCTAssertLessThan(difference, 2.0, "Lockout expiration should be ~15 minutes from now")
        } else {
            XCTFail("lockoutExpiresAt should be set")
        }
    }

    // Remember me persists token
    func testRememberMePersistsToken() async {
        viewModel.state.username = "anne"
        viewModel.state.password = "gowthami"
        viewModel.state.rememberMe = true
        mockAuth.shouldSucceed = true
        
        // Clear token
        KeychainManager.shared.clearToken()

        await viewModel.login()
        let token = KeychainManager.shared.getToken()

        XCTAssertEqual(token, "mockToken123")
    }
    
    // Network drops during login
    func testNetworkDropsDuringLogin() async {
        viewModel.state.username = "anne"
        viewModel.state.password = "gowthami"

        // Simulate network offline
        mockNetwork.setOnline(false) // <-- Corrected here

        await viewModel.login()

        XCTAssertFalse(viewModel.state.loginSuccess)
        XCTAssertEqual(viewModel.state.errorMessage, LoginErrorMessage.noInternet)
    }

    // Cancellation handling
    func testLoginCancellationHandling() async {
        viewModel.state.username = "anne"
        viewModel.state.password = "gowthami"

        mockAuth.shouldSucceed = true
        mockAuth.delayNanoseconds = 3_000_000_000 // 3 seconds

        let loginTask = Task {
            await viewModel.login()
        }

        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        loginTask.cancel()

        await loginTask.value

        XCTAssertEqual(viewModel.state.errorMessage, "")
    }

    // Logout clears token
    func testLogoutClearsTokenAndResetsState() async {
        // Arrange: simulate a logged-in user
        viewModel.state.username = "anne"
        viewModel.state.password = "gowthami"
        viewModel.state.rememberMe = true
        mockAuth.shouldSucceed = true

        // Save token
        KeychainManager.shared.saveToken("mockToken123")

        // Make sure loginSuccess is true
        viewModel.state.loginSuccess = true

        // Act: logout
        viewModel.reset()

        // Assert
        XCTAssertFalse(viewModel.state.loginSuccess)
        XCTAssertEqual(viewModel.state.username, "")
        XCTAssertEqual(viewModel.state.password, "")
        XCTAssertNil(KeychainManager.shared.getToken(), "Token should be cleared from Keychain")
    }

    // Auto-login on app launch
    func testAutoLoginOnAppLaunch() {
        // Arrange: save a token to Keychain
        KeychainManager.shared.saveToken("mockToken123")

        // Act
        viewModel.restoreSessionIfPossible()

        // Assert
        XCTAssertTrue(viewModel.state.loginSuccess)
        XCTAssertEqual(viewModel.state.errorMessage, "")
    }
    
    // Lockout reset after time
    func testLockoutResetsAfterTime() async {
        // Arrange: simulate 3 failed attempts with a short lockout
        viewModel.state.failureCount = 3
        viewModel.state.lockoutExpiresAt = Date().addingTimeInterval(2) // 2-second lockout
        viewModel.state.errorMessage = "Too many failed attempts. Try again in 15 minutes."

        // Assert: initially, account is locked
        XCTAssertTrue(viewModel.state.isLocked)
        XCTAssertEqual(viewModel.state.failureCount, 3)
        XCTAssertFalse(viewModel.state.errorMessage.isEmpty)

        // Wait for lockout to expire
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

        // Act: reset lockout if expired
        viewModel.resetLockoutIfExpired()

        // Assert: lockout should be cleared
        XCTAssertFalse(viewModel.state.isLocked, "Lockout should be reset after time expires")
        XCTAssertEqual(viewModel.state.failureCount, 0, "Failure count should reset after lockout")
        XCTAssertEqual(viewModel.state.errorMessage, "", "Error message should be cleared after lockout")
    }
    
    // Offline login attempts
    func testOfflineLoginAttempt() async {
        // Arrange: Set the network to offline
        let networkMonitor = MockNetworkMonitor()
        networkMonitor.setOnline(false)

        viewModel = LoginViewModel(
            authService: mockAuth,
            networkMonitor: networkMonitor
        )

        // Enter valid credentials
        viewModel.state.username = "anne"
        viewModel.state.password = "gowthami"

        // Act: Attempt to login while offline
        await viewModel.login()

        // Assert: Login should be blocked
        XCTAssertFalse(viewModel.state.loginSuccess, "Login should not succeed when offline")
        XCTAssertEqual(
            viewModel.state.errorMessage,
            LoginErrorMessage.noInternet,
            "Error message should indicate no internet connection"
        )
    }
}


