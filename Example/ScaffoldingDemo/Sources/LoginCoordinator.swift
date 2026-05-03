import SwiftUI
import Scaffolding

@MainActor @Observable @Scaffoldable
final class LoginCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<LoginCoordinator>(root: .email)

    var pendingUsername: String = ""
    private let onComplete: @MainActor (AuthToken) -> Void

    init(onComplete: @escaping @MainActor (AuthToken) -> Void) {
        self.onComplete = onComplete
    }

    // MARK: - Routes

    func email() -> some View {
        NavigationStack {
            EmailEntryView()
                .navigationTitle("Sign in")
        }
    }

    func password(username: String) -> some View {
        PasswordEntryView(username: username)
            .navigationTitle("Password")
    }

    // MARK: - Flow

    func enterPassword(for username: String) {
        pendingUsername = username
        route(to: .password(username: username))
    }

    func submit() {
        // Classic coordinator pattern: deliver the result via the
        // callback the parent supplied at construction time, then
        // dismiss self. The parent's `await flow(.login(...))`
        // resumes when this destination goes away.
        onComplete(AuthToken(username: pendingUsername))
        dismissCoordinator()
    }
}

// MARK: - Login screens

private struct EmailEntryView: View {
    @Environment(LoginCoordinator.self) private var coordinator

    @State private var username: String = ""

    var body: some View {
        Form {
            Section("Email") {
                TextField("you@example.com", text: $username)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            Button("Continue") {
                coordinator.enterPassword(for: username.isEmpty ? "guest" : username)
            }
            .disabled(username.isEmpty)
        }
    }
}

private struct PasswordEntryView: View {
    @Environment(LoginCoordinator.self) private var coordinator

    let username: String
    @State private var password: String = ""

    var body: some View {
        Form {
            Section("Welcome, \(username)") {
                SecureField("Password", text: $password)
            }
            Button("Sign in") {
                coordinator.submit()
            }
            .disabled(password.isEmpty)
        }
    }
}
