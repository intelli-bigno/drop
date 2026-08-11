import DropCore
import DropUI
import SwiftUI

/// `screens/auth_screen.dart` 대응.
struct AuthView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        VStack(spacing: DropTheme.Spacing.loose) {
            Spacer()

            VStack(spacing: DropTheme.Spacing.base) {
                Text("DROP")
                    .font(.system(size: 44, weight: .bold))
                Text("떠오르면 바로 던져넣기")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case let .failed(message) = auth.state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DropTheme.Spacing.loose)
            }

            Button {
                Task { await auth.signInWithGoogle() }
            } label: {
                HStack(spacing: DropTheme.Spacing.base) {
                    if auth.state == .working {
                        ProgressView()
                    }
                    Text("Google로 계속하기")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DropTheme.Spacing.comfortable)
            }
            .buttonStyle(.borderedProminent)
            .disabled(auth.state == .working)
            .padding(.horizontal, DropTheme.Spacing.loose)
            .padding(.bottom, DropTheme.Spacing.loose)
        }
    }
}
