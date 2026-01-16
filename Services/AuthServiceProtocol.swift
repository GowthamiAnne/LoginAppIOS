import Foundation

enum AuthError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case serverError
}

protocol AuthServiceProtocol {
    func login(username: String, password: String) async throws -> String
}

final class AuthService: AuthServiceProtocol {
    var shouldSucceed: Bool = true
    var delayNanoseconds: UInt64 = 0

    func login(username: String, password: String) async throws -> String {
        let interval: UInt64 = 100_000_000 // 0.1s chunks
        var elapsed: UInt64 = 0

        while elapsed < delayNanoseconds {
            try Task.checkCancellation() // check frequently
            try await Task.sleep(nanoseconds: interval)
            elapsed += interval
        }

        try Task.checkCancellation() // final check before returning

        if shouldSucceed && username == "anne" && password == "gowthami" {
            return "mockToken123"
        } else {
            throw AuthError.invalidCredentials
        }
    }
}


final class MockAuthService: AuthServiceProtocol {

    var shouldSucceed = true
    var delayNanoseconds: UInt64 = 0
    var isOffline = false  // ✅ simulate network down

    func login(username: String, password: String) async throws -> String {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }

        try Task.checkCancellation()

        if isOffline {
            throw AuthError.serverError  // represents network failure
        }

        if shouldSucceed {
            return "mockToken123"
        } else {
            throw AuthError.invalidCredentials
        }
    }
}

