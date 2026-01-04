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
        viewModel.username = ""
        viewModel.password = ""
        XCTAssertFalse(viewModel.isButtonEnabled)
        
        viewModel.username = "admin"
        viewModel.password = "1234"
        XCTAssertTrue(viewModel.isButtonEnabled)
    }

    // Success → loginSuccess true
    func testLoginSuccessUpdatesState() async {
        viewModel.username = "Anne"
        viewModel.password = "Anne"
        mockAuth.shouldSucceed = true
        
        await viewModel.login()
        XCTAssertTrue(viewModel.loginSuccess)
        XCTAssertEqual(viewModel.failureCount, 0)
        XCTAssertEqual(viewModel.errorMessage, "")
    }

    // Error increments failure count
    func testLoginFailureIncrementsCount() async {
        viewModel.username = "user"
        viewModel.password = "wrong"
        mockAuth.shouldSucceed = false
        
        await viewModel.login()
        XCTAssertEqual(viewModel.failureCount, 1)
        
        await viewModel.login()
        XCTAssertEqual(viewModel.failureCount, 2)
    }

    // Lockout after 3 failures
    func testLockoutAfterThreeFailures() async {
        viewModel.username = "user"
        viewModel.password = "wrong"
        mockAuth.shouldSucceed = false
        
        await viewModel.login()
        await viewModel.login()
        await viewModel.login()
        
        XCTAssertTrue(viewModel.isLocked)
        XCTAssertEqual(viewModel.errorMessage, "Too many failed attempts. Account locked.")
    }

   

    // Remember me persists token
    func testRememberMePersistsToken() async {
        viewModel.username = "anne"
        viewModel.password = "anne"
        viewModel.rememberMe = true
        mockAuth.shouldSucceed = true
        
        // Clear token
        UserDefaults.standard.removeObject(forKey: "authToken")
        
        await viewModel.login()
        let token = UserDefaults.standard.string(forKey: "authToken")
        XCTAssertEqual(token, "mockToken123")
    }
}

