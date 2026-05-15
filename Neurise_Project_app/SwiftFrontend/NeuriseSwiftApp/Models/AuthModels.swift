import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct SignupRequest: Encodable {
    let username: String
    let displayName: String
    let password: String
}

struct CalibrationRequest: Encodable {
    let userId: String
}

struct ThresholdUpdateRequest: Encodable {
    let userId: String
    let thresholdPercent: Double
}

struct BaselineStatusResponse: Decodable {
    let hasBaseline: Bool
}

struct ThresholdResponse: Decodable {
    let threshold: Double
    let thresholdPercent: Double
}

struct CalibrationResponse: Decodable {
    let message: String
    let sampleCount: Int?
}

struct AuthResponse: Decodable {
    let message: String
    let user: AuthUser
}

struct AuthUser: Codable, Identifiable {
    let id: String
    let username: String
    let displayName: String
}

struct APIErrorResponse: Decodable {
    let detail: String
}
