import Foundation

/// 프로젝트 전체가 쓰는 인코더/디코더.
///
/// 두 가지를 여기서 한 번만 정한다:
/// - snake_case ↔ camelCase 변환
/// - Postgres `timestamptz` 파싱. 분수초가 붙은 값과 안 붙은 값이 **둘 다** 오는데,
///   `.iso8601` 기본 전략은 분수초가 붙은 쪽에서 실패한다.
public enum DropJSON {
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = postgresTimestamp(from: raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "시각 형식을 알 수 없습니다: \(raw)")
                )
            }
            return date
        }
        return decoder
    }()

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
        return encoder
    }()

    // 만든 뒤 설정을 바꾸지 않으므로 여러 스레드에서 파싱해도 안전하다
    // (Foundation의 날짜 포매터는 변경만 하지 않으면 스레드 안전).
    // 목록 하나에 수백 번 호출되는 경로라 매번 새로 만들지 않는다.
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func postgresTimestamp(from raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
    }
}
