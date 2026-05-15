import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        if session.isLoggedIn {
            MainTabView()
        } else {
            AuthView()
        }
    }
}
