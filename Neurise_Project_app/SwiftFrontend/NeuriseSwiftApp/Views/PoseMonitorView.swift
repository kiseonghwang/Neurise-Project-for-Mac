import AVFoundation
import AppKit
import SwiftUI

struct PoseMonitorView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var camera = CameraFrameService()

    @State private var landmarkImage: NSImage?
    @State private var status = "대기 중"
    @State private var isStreaming = false
    @State private var isUploading = false
    @State private var uploadTask: Task<Void, Never>?
    @State private var badPostureStartedAt: Date?
    @State private var isWarningVisible = false
    @State private var isCalibrating = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, .blue.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("AI Pose Estimation")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.cyan)
                                .textCase(.uppercase)
                            Text("Realtime Pose Landmark Streaming")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("카메라 프레임을 백엔드로 보내고 랜드마크 이미지를 실시간으로 받아옵니다.")
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        VStack(spacing: 14) {
                            HStack {
                                Label("Landmark Preview", systemImage: "circle.fill")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(isStreaming ? .green : .white.opacity(0.7))

                                Spacer()

                                Text("3 FPS")
                                    .font(.caption.weight(.black))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(.cyan.opacity(0.18), in: Capsule())
                                    .foregroundStyle(.cyan)
                            }

                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(.black.opacity(0.55))
                                    .aspectRatio(4 / 3, contentMode: .fit)
                                    .overlay {
                                        if let landmarkImage {
                                            Image(nsImage: landmarkImage)
                                                .resizable()
                                                .scaledToFit()
                                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                        } else {
                                            VStack(spacing: 12) {
                                                Image(systemName: "figure.stand")
                                                    .font(.system(size: 52))
                                                Text("Start 버튼을 누르면 랜드마크 이미지가 표시됩니다.")
                                                    .font(.subheadline.weight(.semibold))
                                            }
                                            .foregroundStyle(.white.opacity(0.58))
                                            .multilineTextAlignment(.center)
                                            .padding()
                                        }
                                    }

                                Text(status)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .padding(14)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    startStreaming()
                                } label: {
                                    Text("Start")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(isStreaming)

                                Button {
                                    stopStreaming()
                                } label: {
                                    Text("Stop")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .disabled(!isStreaming)
                            }
                        }
                        .padding(18)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .padding(20)
                }
            }
            .onAppear {
                camera.configure()
            }
            .onDisappear {
                stopStreaming()
            }
        }
    }

    private func startStreaming() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    status = "카메라 권한이 필요합니다."
                    return
                }

                isStreaming = true
                status = "모니터링을 준비하는 중..."
                camera.start()
                uploadTask = Task { await prepareAndUploadLoop() }
            }
        }
    }

    private func stopStreaming() {
        isStreaming = false
        uploadTask?.cancel()
        uploadTask = nil
        camera.stop()
        status = "스트리밍이 중지되었습니다."
        isCalibrating = false
        resetPostureWarning()
    }

    @MainActor
    private func prepareAndUploadLoop() async {
        guard let userId = session.user?.id, userId != "local-admin" else {
            status = "랜드마크 이미지 생성 중..."
            await uploadLoop(mode: "monitoring")
            return
        }

        do {
            let baselineStatus = try await APIClient.shared.fetchBaselineStatus(userId: userId)
            if !baselineStatus.hasBaseline {
                try await runCalibration(userId: userId)
            }

            guard isStreaming, !Task.isCancelled else { return }
            status = "랜드마크 이미지 생성 중..."
            await uploadLoop(mode: "monitoring")
        } catch {
            status = error.localizedDescription
            isStreaming = false
            isCalibrating = false
            camera.stop()
        }
    }

    @MainActor
    private func runCalibration(userId: String) async throws {
        isCalibrating = true
        resetPostureWarning()
        _ = try await APIClient.shared.startCalibration(userId: userId)

        let startedAt = Date()
        while isStreaming, !Task.isCancelled, Date().timeIntervalSince(startedAt) < 10 {
            let remaining = max(0, Int(ceil(10 - Date().timeIntervalSince(startedAt))))
            status = "좋은 자세를 유지해주세요. 기준 자세 수집 중... \(remaining)초"

            if let frame = camera.latestFrame, !isUploading {
                await upload(frame, mode: "calibration")
            }

            try? await Task.sleep(nanoseconds: 333_000_000)
        }

        guard isStreaming, !Task.isCancelled else {
            isCalibrating = false
            return
        }

        _ = try await APIClient.shared.finishCalibration(userId: userId)
        isCalibrating = false
        status = "기준 자세 저장 완료. 모니터링을 시작합니다."
    }

    private func uploadLoop(mode: String) async {
        while !Task.isCancelled {
            if let frame = camera.latestFrame, !isUploading {
                await upload(frame, mode: mode)
            }

            try? await Task.sleep(nanoseconds: 333_000_000)
        }
    }

    @MainActor
    private func upload(_ frame: NSImage, mode: String) async {
        isUploading = true
        defer { isUploading = false }

        do {
            let uploadResult = try await APIClient.shared.uploadFrame(
                frame,
                userId: session.user?.id,
                mode: mode
            )
            landmarkImage = uploadResult.image
            if mode == "calibration" {
                resetPostureWarning()
            } else {
                handlePostureResult(uploadResult.postureResult)
            }
        } catch {
            status = error.localizedDescription
        }
    }

    @MainActor
    private func handlePostureResult(_ result: String?) {
        guard result == "1" else {
            status = "랜드마크 프레임 수신 중"
            resetPostureWarning()
            return
        }

        let now = Date()
        let startedAt = badPostureStartedAt ?? now
        badPostureStartedAt = startedAt

        let elapsed = now.timeIntervalSince(startedAt)
        if elapsed >= 3 {
            status = "안 좋은 자세가 3초 이상 유지되었습니다."
            isWarningVisible = true
            PostureWarningOverlay.shared.show()
        } else {
            status = "안 좋은 자세 감지 중..."
        }
    }

    @MainActor
    private func resetPostureWarning() {
        badPostureStartedAt = nil
        if isWarningVisible {
            PostureWarningOverlay.shared.hide()
            isWarningVisible = false
        }
    }
}
struct PoseMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        PoseMonitorView()
            .environmentObject(SessionStore())
            .frame(width: 900, height: 720)
    }
}
