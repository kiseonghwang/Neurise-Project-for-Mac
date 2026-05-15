import SwiftUI

struct NeuriseSwiftRootView: View {
    @StateObject private var session = SessionStore()

    var body: some View {
        RootView()
            .environmentObject(session)
    }
}
