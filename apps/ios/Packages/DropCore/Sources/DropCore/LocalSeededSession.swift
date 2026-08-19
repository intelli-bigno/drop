#if DEBUG
import Foundation
import Supabase

/// 로컬 Supabase의 시드 사용자로 붙는 **디버그 전용** 경로.
///
/// 데스크톱이 `VITE_DROP_PREVIEW=1`에서 하는 것과 같다(BRU-71) — 시드 사용자는
/// `supabase/seed.sql`이 만들고 로컬 컨테이너 안에만 있다.
///
/// 왜 필요한가: iOS의 유일한 로그인 경로가 Google이라, **실제 DB를 보는 앱**을
/// 시뮬레이터에서 띄울 방법이 없었다. 그래서 "뷰어를 열었다 닫아도 DB가 그대로인가"
/// 같은 것을 앱으로 확인하지 못하고 추정만 하게 된다 (BRU-77 완료 기준).
///
/// 릴리스 빌드에는 이 파일 자체가 들어가지 않고, 디버그 빌드에서도
/// `-dropLocalSession` 인자를 준 실행에서만 불린다.
public extension DropEnvironmentContainer {
    /// `supabase/seed.sql`이 심어 둔 로컬 전용 계정. 리모트에는 없다.
    static let seededLocalEmail = "preview@drop.local"
    static let seededLocalPassword = "drop-preview-password"

    @discardableResult
    func signInWithSeededLocalUser(
        email: String = DropEnvironmentContainer.seededLocalEmail,
        password: String = DropEnvironmentContainer.seededLocalPassword
    ) async throws -> DropUser {
        let session = try await supabase.auth.signIn(email: email, password: password)
        return DropUser(supabaseUser: session.user)
    }
}
#endif
