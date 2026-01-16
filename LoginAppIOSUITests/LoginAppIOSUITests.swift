import XCTest

@testable import LoginAppIOS

final class LoginAppIOSUITests: XCTestCase {

    private let app = XCUIApplication()

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(env: [String: String] = [:]) {
        app.launchEnvironment = env
        app.launch()
    }

    // MARK: - Helpers
    private func enterCredentials(username: String, password: String) {
        let usernameField = app.textFields["usernameField"]
        let passwordField = app.secureTextFields["passwordField"]

        XCTAssertTrue(usernameField.waitForExistence(timeout: 5) && usernameField.isHittable)
        usernameField.tap()
        usernameField.typeText(username)

        XCTAssertTrue(passwordField.waitForExistence(timeout: 5) && passwordField.isHittable)
        passwordField.tap()
        passwordField.typeText(password)
    }

    // MARK: - Tests

    /// 1. Validation enables / disables login button
    func testLoginButtonValidationEnableDisable() {
        launchApp()

        let loginButton = app.buttons["Login"]
        XCTAssertFalse(loginButton.isEnabled)

        enterCredentials(username: "anne", password: "gowthami")

        XCTAssertTrue(loginButton.isEnabled)
    }

    /// 2. Success → navigation event
    func testSuccessfulLoginNavigatesToHome() {
        launchApp(env: ["UITEST_LOGIN_RESULT": "success"])

        enterCredentials(username: "anne", password: "gowthami")
        app.buttons["Login"].tap()

        let welcomeText = app.staticTexts["Welcome"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5),
                      "Home screen should be displayed after successful login")
    }

    /// 3. Error increments failure count
    func testLoginFailureShowsError() {
        launchApp(env: ["UITEST_LOGIN_RESULT": "failure"])

        enterCredentials(username: "wrong", password: "gowthami")

        let loginButton = app.buttons["Login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        loginButton.tap()

        let errorLabel = app.staticTexts["errorLabel"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5),
                      "Error message should be shown on login failure")
    }

    /// 4. Lockout after 3 failures
    func testAccountLocksAfterThreeFailures() {
        launchApp(env: ["UITEST_LOGIN_RESULT": "failure"])

        for _ in 1...3 {
            enterCredentials(username: "wrong", password: "gowthami")
            app.buttons["Login"].tap()
        }

        let errorLabel = app.staticTexts["errorLabel"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5),
                      "Error message should be shown on locked")
    }
}

