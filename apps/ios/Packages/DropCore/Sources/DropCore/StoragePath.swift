import Foundation

/// 첨부 파일의 저장 경로를 만든다.
///
/// **Flutter 앱과 같은 규칙이어야 한다** — 두 앱이 같은 버킷을 보는 기간이 있어서,
/// 규칙이 갈리면 한쪽에서 올린 파일을 다른 쪽이 못 찾는다.
///   `{user_id}/{note_id}/{고유값}.{확장자}`
public enum StoragePath {
    public static func make(
        userID: String,
        noteID: String,
        fileName: String,
        fallbackExtension: String,
        uniqueSuffix: String = StoragePath.uniqueSuffix()
    ) -> String {
        // 파일명에서 확장자만 취한다. 이름 자체는 경로에 쓰지 않으므로
        // `../` 같은 값이 들어와도 경로를 벗어날 수 없다.
        let ext = fileExtension(of: fileName) ?? fallbackExtension
        return "\(userID)/\(noteID)/\(uniqueSuffix).\(ext)"
    }

    /// Flutter의 `${microsecondsSinceEpoch}_${salt}`와 같은 모양.
    public static func uniqueSuffix() -> String {
        let microseconds = Int(Date().timeIntervalSince1970 * 1_000_000)
        return "\(microseconds)_\(UInt32.random(in: 0...UInt32.max))"
    }

    static func fileExtension(of fileName: String) -> String? {
        let lastComponent = fileName.split(separator: "/").last.map(String.init) ?? fileName
        guard let dotIndex = lastComponent.lastIndex(of: ".") else { return nil }
        let ext = String(lastComponent[lastComponent.index(after: dotIndex)...])
        return ext.isEmpty ? nil : ext
    }
}

public enum MIMEType {
    public static func forExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "webp": "image/webp"
        case "heic": "image/heic"
        case "m4a": "audio/m4a"
        case "mp3": "audio/mpeg"
        case "wav": "audio/wav"
        case "mp4": "video/mp4"
        case "mov": "video/quicktime"
        case "pdf": "application/pdf"
        case "txt": "text/plain"
        default: "application/octet-stream"
        }
    }
}

public enum TagName {
    /// 같은 태그가 대소문자·공백 때문에 둘로 갈라지지 않도록 Flutter와 같은 규칙으로 좁힌다.
    public static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
