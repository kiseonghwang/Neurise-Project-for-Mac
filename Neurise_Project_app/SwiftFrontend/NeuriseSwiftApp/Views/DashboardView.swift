import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var snapshot: DashboardSnapshot?
    @State private var isLoading = false
    @State private var message = ""

    private var displaySnapshot: DashboardSnapshot {
        snapshot ?? DashboardSnapshot.sample(userName: session.user?.displayName ?? "사용자")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let snapshot = displaySnapshot

                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 54, height: 54)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Personal Posture Report")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.blue)
                                .textCase(.uppercase)
                            Text("\(snapshot.userName)님의 자세 대시보드")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(DashboardPalette.primaryText)
                            Text("최근 7일 사용 시간과 좋은 자세 유지 시간을 한눈에 확인하세요.")
                                .font(.subheadline)
                                .foregroundStyle(DashboardPalette.secondaryText)
                        }
                    }

                    HStack {
                        Text(message.isEmpty ? "PostgreSQL에 저장된 사용자 데이터를 표시합니다." : message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DashboardPalette.secondaryText)

                        Spacer()

                        Button {
                            Task { await loadDashboard() }
                        } label: {
                            Label(isLoading ? "불러오는 중" : "새로고침", systemImage: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 2)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SummaryCard(title: "이번 주 총 사용", value: formatHours(snapshot.totalMinutes), caption: "일주일 누적")
                        SummaryCard(title: "좋은 자세 유지율", value: "\(snapshot.goodPostureRate)%", caption: "목표 80%", accent: true)
                        SummaryCard(title: "좋은 자세 시간", value: formatHours(snapshot.totalGoodMinutes), caption: "일주일 누적")
                        SummaryCard(title: "이전 작업 분석", value: "\(snapshot.lastSessionTotalMinutes)분", caption: "좋은 자세 \(snapshot.lastSessionGoodMinutes)분")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Latest Session")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                            .textCase(.uppercase)
                        Text("바로 이전 작업에서 총 \(snapshot.lastSessionTotalMinutes)분 작업하셨고, \(snapshot.lastSessionGoodMinutes)분동안 좋은 자세를 유지하셨습니다.")
                            .font(.headline)
                            .foregroundStyle(DashboardPalette.primaryText)
                    }
                    .dashboardCard()

                    VStack(alignment: .leading, spacing: 18) {
                        Text("최근 7일 사용 시간")
                            .font(.title3.weight(.black))
                            .foregroundStyle(DashboardPalette.primaryText)
                        BarChartView(
                            logs: snapshot.logs,
                            value: { Double($0.totalMinutes) / 60.0 },
                            label: { String(format: "%.1fh", Double($0.totalMinutes) / 60.0) },
                            color: .blue
                        )
                        .frame(height: 230)
                    }
                    .dashboardCard()

                    VStack(alignment: .leading, spacing: 18) {
                        Text("좋은 자세 유지 시간")
                            .font(.title3.weight(.black))
                            .foregroundStyle(DashboardPalette.primaryText)
                        BarChartView(
                            logs: snapshot.logs,
                            value: { Double($0.goodPostureMinutes) },
                            label: { "\($0.goodPostureMinutes)m" },
                            color: .cyan
                        )
                        .frame(height: 230)
                    }
                    .dashboardCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("오늘의 제안")
                            .font(.title3.weight(.black))
                            .foregroundStyle(DashboardPalette.primaryText)
                        RecommendationRow(text: "50분 작업 후 5분 스트레칭을 예약해보세요.")
                        RecommendationRow(text: "목이 앞으로 나오면 턱을 살짝 당기고 어깨를 낮춰보세요.")
                        RecommendationRow(text: snapshot.goodPostureRate >= 80 ? "이번 주 자세 흐름이 좋아요." : "좋은 자세 목표를 80%로 두고 짧은 세션부터 안정화해보세요.")
                    }
                    .dashboardCard()
                }
                .frame(maxWidth: 980)
                .padding(24)
            }
            .background(DashboardPalette.background)
            .environment(\.colorScheme, .light)
            .task(id: session.user?.id) {
                await loadDashboard()
            }
        }
    }

    @MainActor
    private func loadDashboard() async {
        guard let userId = session.user?.id, userId != "local-admin" else {
            snapshot = DashboardSnapshot.sample(userName: session.user?.displayName ?? "관리자")
            message = "admin 테스트 계정은 DB에 저장하지 않는 로컬 계정입니다."
            return
        }

        isLoading = true
        message = "대시보드 데이터를 불러오는 중입니다..."

        do {
            snapshot = try await APIClient.shared.fetchDashboard(userId: userId)
            message = "최근 업데이트 완료"
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }

    private func formatHours(_ minutes: Int) -> String {
        String(format: "%.1f시간", Double(minutes) / 60.0)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let caption: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent ? Color.white.opacity(0.82) : DashboardPalette.secondaryText)
            Text(value)
                .font(.title2.weight(.black))
                .foregroundStyle(accent ? Color.white : DashboardPalette.primaryText)
            Text(caption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent ? Color.white.opacity(0.78) : DashboardPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(accent ? AnyShapeStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(DashboardPalette.card))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent ? Color.white.opacity(0.2) : DashboardPalette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

struct BarChartView: View {
    let logs: [WeeklyPoseLog]
    let value: (WeeklyPoseLog) -> Double
    let label: (WeeklyPoseLog) -> String
    let color: Color

    private var maxValue: Double {
        max(logs.map(value).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(logs) { log in
                VStack(spacing: 8) {
                    Text(label(log))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(DashboardPalette.secondaryText)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.gradient)
                        .frame(height: max(14, CGFloat(value(log) / maxValue) * 160))
                    Text(log.day)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DashboardPalette.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct RecommendationRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DashboardPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(DashboardPalette.softCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardPalette.border, lineWidth: 1)
            )
    }
}

private extension View {
    func dashboardCard() -> some View {
        self
            .padding(20)
            .background(DashboardPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DashboardPalette.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 14, y: 8)
    }
}

private enum DashboardPalette {
    static let background = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let card = Color.white
    static let softCard = Color(red: 0.96, green: 0.98, blue: 1.0)
    static let border = Color.black.opacity(0.08)
    static let primaryText = Color.black.opacity(0.88)
    static let secondaryText = Color.black.opacity(0.58)
}
