import Foundation
import Testing

@testable import DropCore

/// 두 앱이 같은 버킷을 쓰는 동안 **저장 경로 규칙이 어긋나면 안 된다.**
/// Flutter: `{user_id}/{note_id}/{microsecondsSinceEpoch}_{salt}.{ext}`
@Suite("첨부 저장 경로")
struct AttachmentUploadTests {
    @Test("경로는 사용자·노트·파일명 순으로 만든다")
    func buildsPathInFlutterShape() {
        let path = StoragePath.make(
            userID: "u-1",
            noteID: "n-1",
            fileName: "메모.PNG",
            fallbackExtension: "png",
            uniqueSuffix: "1770000000000000_42"
        )

        #expect(path == "u-1/n-1/1770000000000000_42.PNG")
    }

    @Test("확장자가 없으면 기본값을 붙인다")
    func usesFallbackExtension() {
        let path = StoragePath.make(
            userID: "u", noteID: "n", fileName: "녹음", fallbackExtension: "m4a", uniqueSuffix: "s"
        )

        #expect(path == "u/n/s.m4a")
    }

    /// "file." 처럼 점으로 끝나는 이름은 확장자가 빈 문자열이 된다 —
    /// 그대로 두면 `s.` 같은 경로가 만들어져 다운로드 시 형식을 못 알아본다.
    @Test("점으로 끝나는 이름도 기본 확장자를 쓴다")
    func trailingDotUsesFallback() {
        let path = StoragePath.make(
            userID: "u", noteID: "n", fileName: "file.", fallbackExtension: "bin", uniqueSuffix: "s"
        )

        #expect(path == "u/n/s.bin")
    }

    @Test("경로 구분자가 든 파일명이 경로를 탈출하지 못한다")
    func fileNameCannotEscapePath() {
        let path = StoragePath.make(
            userID: "u", noteID: "n", fileName: "../../etc/passwd.png", fallbackExtension: "bin",
            uniqueSuffix: "s"
        )

        #expect(path == "u/n/s.png")
        #expect(!path.contains(".."))
    }

    @Test("확장자로 MIME 타입을 고른다")
    func mapsMIMETypes() {
        #expect(MIMEType.forExtension("png") == "image/png")
        #expect(MIMEType.forExtension("JPG") == "image/jpeg")
        #expect(MIMEType.forExtension("m4a") == "audio/m4a")
        #expect(MIMEType.forExtension("mp4") == "video/mp4")
        #expect(MIMEType.forExtension("듣도보도못한") == "application/octet-stream")
    }
}

@Suite("태그 이름 정규화")
struct TagNameTests {
    /// Flutter는 trim + 소문자화 후 저장한다. 같은 태그가 둘로 갈라지지 않게 맞춘다.
    @Test("앞뒤 공백을 없애고 소문자로 만든다")
    func trimsAndLowercases() {
        #expect(TagName.normalized("  Work ") == "work")
        #expect(TagName.normalized("업무") == "업무")
    }

    @Test("공백뿐인 이름은 태그로 보지 않는다")
    func blankIsRejected() {
        #expect(TagName.normalized("   ") == nil)
        #expect(TagName.normalized("") == nil)
    }
}
