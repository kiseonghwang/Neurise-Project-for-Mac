import Foundation
import AppKit

enum APIClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)
    case imageEncodingFailed
    case imageDecodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "서버 주소가 올바르지 않습니다."
        case .invalidResponse:
            return "서버 응답을 처리할 수 없습니다."
        case .server(let message):
            return message
        case .imageEncodingFailed:
            return "카메라 프레임을 JPEG로 변환하지 못했습니다."
        case .imageDecodingFailed:
            return "랜드마크 이미지를 표시할 수 없습니다."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    var baseURL = URL(string: "http://127.0.0.1:8000")!

    private init() {}

    func login(username: String, password: String) async throws -> AuthUser {
        let request = LoginRequest(username: username, password: password)
        let response: AuthResponse = try await postJSON(path: "/api/login", body: request)
        return response.user
    }

    func signup(username: String, displayName: String, password: String) async throws -> AuthUser {
        let request = SignupRequest(username: username, displayName: displayName, password: password)
        let response: AuthResponse = try await postJSON(path: "/api/signup", body: request)
        return response.user
    }

    func fetchDashboard(userId: String) async throws -> DashboardSnapshot {
        let request = URLRequest(url: baseURL.appendingPathComponent("api/dashboard/\(userId)"))
        return try await perform(request)
    }

    func fetchBaselineStatus(userId: String) async throws -> BaselineStatusResponse {
        let request = URLRequest(url: baseURL.appendingPathComponent("api/pose-baseline/\(userId)"))
        return try await perform(request)
    }

    func fetchPoseThreshold(userId: String) async throws -> ThresholdResponse {
        let request = URLRequest(url: baseURL.appendingPathComponent("api/pose-threshold/\(userId)"))
        return try await perform(request)
    }

    func updatePoseThreshold(userId: String, thresholdPercent: Double) async throws -> ThresholdResponse {
        let request = ThresholdUpdateRequest(userId: userId, thresholdPercent: thresholdPercent)
        return try await postJSON(path: "/api/pose-threshold", body: request)
    }

    func startCalibration(userId: String) async throws -> CalibrationResponse {
        let request = CalibrationRequest(userId: userId)
        return try await postJSON(path: "/api/pose-baseline/start", body: request)
    }

    func finishCalibration(userId: String) async throws -> CalibrationResponse {
        let request = CalibrationRequest(userId: userId)
        return try await postJSON(path: "/api/pose-baseline/finish", body: request)
    }

    func resetCalibration(userId: String) async throws -> CalibrationResponse {
        let request = CalibrationRequest(userId: userId)
        return try await postJSON(path: "/api/pose-baseline/reset", body: request)
    }

    func uploadFrame(_ image: NSImage, userId: String?, mode: String = "monitoring") async throws -> UploadFrameResult {
        guard let imageData = image.jpegData(compressionQuality: 0.72) else {
            throw APIClientError.imageEncodingFailed
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("upload"))
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fieldName: "file",
            fileName: "frame.jpg",
            mimeType: "image/jpeg",
            data: imageData,
            fields: multipartFields(userId: userId, mode: mode)
        )

        let response: UploadResponse = try await perform(request)
        guard let commaIndex = response.landmarkImage.firstIndex(of: ",") else {
            throw APIClientError.imageDecodingFailed
        }

        let base64 = String(response.landmarkImage[response.landmarkImage.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64), let image = NSImage(data: data) else {
            throw APIClientError.imageDecodingFailed
        }

        return UploadFrameResult(image: image, postureResult: response.result)
    }

    private func postJSON<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        return try await perform(request)
    }

    private func perform<ResponseBody: Decodable>(_ request: URLRequest) async throws -> ResponseBody {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIClientError.server(apiError.detail)
            }

            throw APIClientError.server("서버 오류가 발생했습니다. 상태 코드: \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }

    private func makeMultipartBody(
        boundary: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data,
        fields: [String: String] = [:]
    ) -> Data {
        var body = Data()
        for (name, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append(value)
            body.append("\r\n")
        }
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    private func multipartFields(userId: String?, mode: String) -> [String: String] {
        var fields = ["mode": mode]
        if let userId {
            fields["user_id"] = userId
        }
        return fields
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard
            let tiffData = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }
}
