import SwiftUI

struct SignupView: View {
    @Binding var showsSignup: Bool

    @State private var displayName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var message = ""
    @State private var isSuccess = false
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Account")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                        .textCase(.uppercase)
                    Text("회원가입")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                    Text("자세 분석 기록을 저장할 계정을 만들어보세요.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    TextField("이름", text: $displayName)
                        .textContentType(.name)
                        .formFieldStyle()

                    TextField("아이디: 영문자 3~30자", text: $username)
                        .textContentType(.username)
                        .formFieldStyle()
                        .onChange(of: username) { _, newValue in
                            username = newValue.filter { $0.isLetter }
                        }

                    SecureField("비밀번호: 4자 이상", text: $password)
                        .textContentType(.newPassword)
                        .formFieldStyle()

                    SecureField("비밀번호 확인", text: $passwordConfirm)
                        .textContentType(.newPassword)
                        .formFieldStyle()

                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isSuccess ? .green : .red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 20)

                    Button {
                        Task { await signup() }
                    } label: {
                        Text(isLoading ? "생성 중..." : "계정 만들기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)
                }

                Button {
                    showsSignup = false
                } label: {
                    Text("이미 계정이 있으신가요? 로그인")
                        .font(.footnote.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.blue)
            }
            .padding(28)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .blue.opacity(0.12), radius: 30, y: 18)
            .padding(24)
        }
    }

    private func signup() async {
        isSuccess = false

        guard username.range(of: "^[A-Za-z]{3,30}$", options: .regularExpression) != nil else {
            message = "아이디는 영문자만 3~30자로 입력해주세요."
            return
        }

        guard password == passwordConfirm else {
            message = "비밀번호가 서로 일치하지 않습니다."
            return
        }

        isLoading = true
        message = "계정을 생성하는 중입니다..."

        do {
            _ = try await APIClient.shared.signup(
                username: username.trimmingCharacters(in: .whitespaces),
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                password: password
            )
            isSuccess = true
            message = "회원가입이 완료되었습니다. 로그인해주세요."

            try? await Task.sleep(nanoseconds: 900_000_000)
            showsSignup = false
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }
}
