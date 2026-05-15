import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var serverURL = APIClient.shared.baseURL.absoluteString
    @State private var thresholdPercent = "10"
    @State private var thresholdMessage = ""
    @State private var isSavingThreshold = false
    @State private var calibrationMessage = ""
    @State private var isResettingCalibration = false

    var body: some View {
        NavigationStack {
            Form {
                Section("서버") {
                    TextField("FastAPI 서버 주소", text: $serverURL)

                    Button("서버 주소 적용") {
                        if let url = URL(string: serverURL) {
                            APIClient.shared.baseURL = url
                        }
                    }
                }

                Section("자세 판정") {
                    TextField("임계값 (%)", text: $thresholdPercent)
                    Text("기준 자세와 현재 pose point의 평균 차이가 이 값 이상이면 안 좋은 자세로 판정합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(isSavingThreshold ? "저장 중..." : "임계값 저장") {
                        Task { await saveThreshold() }
                    }
                    .disabled(isSavingThreshold || session.user?.id == "local-admin")

                    if !thresholdMessage.isEmpty {
                        Text(thresholdMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("기준 자세") {
                    Text("카메라 위치, 책상 높이, 의자 환경이 바뀌면 기준 자세를 다시 측정하세요. 다음 자세 측정 시작 시 10초 동안 좋은 자세를 수집합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(isResettingCalibration ? "초기화 중..." : "기준 자세 다시 측정") {
                        Task { await resetCalibration() }
                    }
                    .disabled(isResettingCalibration || session.user?.id == "local-admin")

                    if !calibrationMessage.isEmpty {
                        Text(calibrationMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("계정") {
                    if let user = session.user {
                        LabeledContent("아이디", value: user.username)
                        LabeledContent("이름", value: user.displayName)
                    }

                    Button(role: .destructive) {
                        session.signOut()
                    } label: {
                        Text("로그아웃")
                    }
                }
            }
            .navigationTitle("설정")
            .task(id: session.user?.id) {
                await loadThreshold()
            }
        }
    }

    @MainActor
    private func loadThreshold() async {
        guard let userId = session.user?.id, userId != "local-admin" else {
            thresholdPercent = "10"
            thresholdMessage = "admin 테스트 계정은 자세 임계값을 저장하지 않습니다."
            return
        }

        do {
            let response = try await APIClient.shared.fetchPoseThreshold(userId: userId)
            thresholdPercent = formattedPercent(response.thresholdPercent)
            thresholdMessage = "현재 임계값: \(formattedPercent(response.thresholdPercent))%"
        } catch {
            thresholdMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveThreshold() async {
        guard let userId = session.user?.id, userId != "local-admin" else {
            thresholdMessage = "admin 테스트 계정은 자세 임계값을 저장하지 않습니다."
            return
        }

        guard let value = Double(thresholdPercent.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            thresholdMessage = "숫자를 입력해주세요. 예: 10"
            return
        }

        isSavingThreshold = true
        defer { isSavingThreshold = false }

        do {
            let response = try await APIClient.shared.updatePoseThreshold(userId: userId, thresholdPercent: value)
            thresholdPercent = formattedPercent(response.thresholdPercent)
            thresholdMessage = "임계값을 \(formattedPercent(response.thresholdPercent))%로 저장했습니다."
        } catch {
            thresholdMessage = error.localizedDescription
        }
    }

    @MainActor
    private func resetCalibration() async {
        guard let userId = session.user?.id, userId != "local-admin" else {
            calibrationMessage = "admin 테스트 계정은 기준 자세를 저장하지 않습니다."
            return
        }

        isResettingCalibration = true
        defer { isResettingCalibration = false }

        do {
            _ = try await APIClient.shared.resetCalibration(userId: userId)
            calibrationMessage = "기준 자세를 초기화했습니다. 자세 측정 Start를 누르면 10초간 다시 수집합니다."
        } catch {
            calibrationMessage = error.localizedDescription
        }
    }

    private func formattedPercent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
