import SwiftUI

struct AuthView: View {
    @State private var showsSignup = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.18), Color.cyan.opacity(0.16), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if showsSignup {
                    SignupView(showsSignup: $showsSignup)
                } else {
                    LoginView(showsSignup: $showsSignup)
                }
            }
        }
    }
}
