import Foundation
import Testing

@testable import DropCore

/// 구성값은 xcconfig → Info.plist → 런타임 순으로 흘러온다.
/// Info.plist를 읽는 부분은 사전(dictionary) 하나로 좁혀 두어 테스트 가능하게 만든다.
@Suite("빌드 구성 로딩")
struct DropConfigurationTests {
    private let validPlist: [String: Any] = [
        "SUPABASE_URL": "https://abcdefgh.supabase.co",
        "SUPABASE_ANON_KEY": "anon-key-value",
        "DROP_ENVIRONMENT": "remote",
        "GOOGLE_WEB_CLIENT_ID": "web-client.apps.googleusercontent.com",
        "GOOGLE_IOS_CLIENT_ID": "ios-client.apps.googleusercontent.com",
    ]

    @Test("Info.plist 값으로 구성을 만든다")
    func loadsFromPlist() throws {
        let config = try DropConfiguration(plist: validPlist)

        #expect(config.supabaseURL == URL(string: "https://abcdefgh.supabase.co"))
        #expect(config.supabaseAnonKey == "anon-key-value")
        #expect(config.environment == .remote)
        #expect(config.googleWebClientID == "web-client.apps.googleusercontent.com")
        #expect(config.googleIOSClientID == "ios-client.apps.googleusercontent.com")
    }

    /// 웹 클라이언트 ID(serverClientId)를 빠뜨리면 id_token의 audience가
    /// iOS 클라이언트 ID가 되어 Supabase가 `Unacceptable audience`로 거부한다.
    /// 런타임에 로그인 실패로 드러나기 전에 여기서 끊는다.
    @Test("웹 클라이언트 ID가 없으면 실행 전에 실패한다")
    func missingWebClientIDThrows() {
        var plist = validPlist
        plist.removeValue(forKey: "GOOGLE_WEB_CLIENT_ID")

        #expect(throws: DropConfigurationError.missingValue("GOOGLE_WEB_CLIENT_ID")) {
            try DropConfiguration(plist: plist)
        }
    }

    @Test("iOS 클라이언트 ID가 없으면 실행 전에 실패한다")
    func missingIOSClientIDThrows() {
        var plist = validPlist
        plist.removeValue(forKey: "GOOGLE_IOS_CLIENT_ID")

        #expect(throws: DropConfigurationError.missingValue("GOOGLE_IOS_CLIENT_ID")) {
            try DropConfiguration(plist: plist)
        }
    }

    /// 두 값이 같다면 웹 클라이언트 ID 자리에 iOS 것을 잘못 넣은 것이다.
    /// 이 실수는 정확히 #17에서 겪은 `Unacceptable audience`로 이어진다.
    @Test("웹·iOS 클라이언트 ID가 같으면 잘못 넣은 것으로 본다")
    func identicalClientIDsThrow() {
        var plist = validPlist
        plist["GOOGLE_WEB_CLIENT_ID"] = "ios-client.apps.googleusercontent.com"

        #expect(throws: DropConfigurationError.webAndIOSClientIDsIdentical) {
            try DropConfiguration(plist: plist)
        }
    }

    @Test("환경 키가 없으면 localdev로 본다")
    func defaultsToLocaldev() throws {
        var plist = validPlist
        plist.removeValue(forKey: "DROP_ENVIRONMENT")

        #expect(try DropConfiguration(plist: plist).environment == .localdev)
    }

    @Test("URL이 없으면 명확한 오류를 낸다")
    func missingURLThrows() {
        var plist = validPlist
        plist.removeValue(forKey: "SUPABASE_URL")

        #expect(throws: DropConfigurationError.missingValue("SUPABASE_URL")) {
            try DropConfiguration(plist: plist)
        }
    }

    /// xcconfig 값이 비어 있을 때 빈 문자열이 Info.plist에 그대로 실린다.
    /// 이걸 통과시키면 런타임에 "왜 인증이 안 되지"로 시간을 날리게 된다.
    @Test("빈 문자열은 값이 없는 것으로 취급한다")
    func emptyStringIsMissing() {
        var plist = validPlist
        plist["SUPABASE_ANON_KEY"] = "   "

        #expect(throws: DropConfigurationError.missingValue("SUPABASE_ANON_KEY")) {
            try DropConfiguration(plist: plist)
        }
    }

    @Test("URL 형식이 아니면 오류를 낸다")
    func malformedURLThrows() {
        var plist = validPlist
        plist["SUPABASE_URL"] = "not a url"

        #expect(throws: DropConfigurationError.malformedURL("not a url")) {
            try DropConfiguration(plist: plist)
        }
    }

    /// xcconfig는 `//`를 주석으로 해석하기 때문에 URL의 스킴 구분자가 잘린다.
    /// 그래서 값에는 스킴 없이 넣고 빌드 설정에서 다시 붙이는 우회가 흔한데,
    /// 그 결과 호스트만 남은 값이 들어오는 사고가 잦다. 여기서 걸러낸다.
    @Test("스킴 없는 호스트 값은 오류로 걸러낸다")
    func hostWithoutSchemeThrows() {
        var plist = validPlist
        plist["SUPABASE_URL"] = "abcdefgh.supabase.co"

        #expect(throws: DropConfigurationError.malformedURL("abcdefgh.supabase.co")) {
            try DropConfiguration(plist: plist)
        }
    }
}
