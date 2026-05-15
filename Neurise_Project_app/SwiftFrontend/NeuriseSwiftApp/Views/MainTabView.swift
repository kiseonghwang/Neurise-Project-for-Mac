import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            PoseMonitorView()
                .tabItem {
                    Label("측정", systemImage: "figure.stand")
                }

            DashboardView()
                .tabItem {
                    Label("대시보드", systemImage: "chart.bar.xaxis")
                }

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape")
                }
        }
    }
}
