import Foundation

protocol AuthServiceProtocol {
    func login(username: String, password: String) async throws -> String
}

enum AuthError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid username or password."
        case .serverError: return "Server error. Please try again."
        }
    }
}

class AuthService: AuthServiceProtocol {
    func login(username: String, password: String) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        if username == "anne" && password == "anne" {
            return "mockToken123"
        } else {
            throw AuthError.invalidCredentials
        }
    }
}

class MockAuthService: AuthServiceProtocol {
    var shouldSucceed = true
    var token = "mockToken123"
    var errorToThrow: Error?
    
    func login(username: String, password: String) async throws -> String {
        if let error = errorToThrow { throw error }
        if shouldSucceed { return token }
        throw AuthError.invalidCredentials
    }
}

