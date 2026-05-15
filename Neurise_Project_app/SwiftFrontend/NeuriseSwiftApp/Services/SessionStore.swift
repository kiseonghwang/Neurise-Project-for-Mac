import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published var user: AuthUser?

    private let userKey = "neurise.auth.user"

    init() {
        restore()
    }

    var isLoggedIn: Bool {
        user != nil
    }

    func signIn(user: AuthUser) {
        self.user = user

        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    func signOut() {
        user = nil
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let restoredUser = try? JSONDecoder().decode(AuthUser.self, from: data) else {
            return
        }

        user = restoredUser
    }
}
