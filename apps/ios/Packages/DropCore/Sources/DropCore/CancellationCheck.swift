import Foundation

/// 취소는 장애가 아니다.
///
/// 당겨서 새로고침이나 화면 이탈로 Task가 취소되면 진행 중이던 요청은
/// `CancellationError` 또는 `URLError.cancelled`로 끝난다. 이것을 네트워크 오류로
/// 다루면 사용자에게는 아무 잘못 없이 "네트워크에 연결하지 못했습니다"가 뜬다.
public extension Error {
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
