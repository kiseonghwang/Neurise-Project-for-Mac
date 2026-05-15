import AppKit
import SwiftUI

@MainActor
final class PostureWarningOverlay {
    static let shared = PostureWarningOverlay()

    private var panel: NSPanel?

    private init() {}

    func show(message: String = "자세 경고: 몸을 펴고 화면과 거리를 조정하세요") {
        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(rootView: PostureWarningBanner(message: message))
        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let width: CGFloat = min(560, max(320, screenFrame.width - 40))
        let height: CGFloat = 78
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height - 18
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

private struct PostureWarningBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 3) {
                Text("안 좋은 자세가 2초 이상 유지되고 있습니다")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.96), Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
