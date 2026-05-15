import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var showsSignup: Bool

    @State private var username = ""
    @State private var password = ""
    @State private var message = ""
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "figure.stand.line.dotted.figure.stand")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Neurise Pose Monitor")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                        .textCase(.uppercase)
                    Text("로그인")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.88))
                    Text("Mac에서 자세 추정 모니터링을 시작하세요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.58))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("아이디")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.62))
                    TextField("admin", text: $username)
                        .textContentType(.username)
                        .formFieldStyle()
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("비밀번호")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.62))
                    SecureField("1234", text: $password)
                        .textContentType(.password)
                        .formFieldStyle()
                }

                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 20)

                Button {
                    Task { await login() }
                } label: {
                    Text(isLoading ? "로그인 중..." : "로그인")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)
            }

            Button {
                showsSignup = true
            } label: {
                Text("계정이 없으신가요? 회원가입")
                    .font(.footnote.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.blue)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("테스트 계정은 admin / 1234 입니다.")
                    .foregroundStyle(Color.black.opacity(0.58))
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .frame(width: 430)
        .padding(30)
        .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .blue.opacity(0.12), radius: 26, y: 14)
        .environment(\.colorScheme, .light)
        .padding(24)
    }

    private func login() async {
        isLoading = true
        message = "로그인 중입니다..."

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUsername == "admin", password == "1234" {
            session.signIn(user: AuthUser(id: "local-admin", username: "admin", displayName: "관리자"))
            isLoading = false
            return
        }

        do {
            let user = try await APIClient.shared.login(username: trimmedUsername, password: password)
            session.signIn(user: user)
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }
}
