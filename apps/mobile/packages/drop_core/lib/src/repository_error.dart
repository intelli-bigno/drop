/// 리포지토리 오류 경계. DropCore `NotesRepository.swift`의
/// `NotesRepositoryError` + `CancellationCheck.swift` + `RepositoryErrorMessage.swift` 대응.
library;

/// 노트·댓글·첨부 리포지토리가 실패하는 네 가지 이유.
sealed class NotesRepositoryError implements Exception {
  const NotesRepositoryError();

  const factory NotesRepositoryError.notAuthenticated() = NotAuthenticatedError;
  const factory NotesRepositoryError.network(String message) = NetworkError;
  const factory NotesRepositoryError.decoding(String message) = DecodingError;
  const factory NotesRepositoryError.rejected(String reason) = RejectedError;
}

class NotAuthenticatedError extends NotesRepositoryError {
  const NotAuthenticatedError();

  @override
  bool operator ==(Object other) => other is NotAuthenticatedError;

  @override
  int get hashCode => (NotAuthenticatedError).hashCode;
}

class NetworkError extends NotesRepositoryError {
  final String message;

  const NetworkError(this.message);

  @override
  bool operator ==(Object other) =>
      other is NetworkError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

class DecodingError extends NotesRepositoryError {
  final String message;

  const DecodingError(this.message);

  @override
  bool operator ==(Object other) =>
      other is DecodingError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

class RejectedError extends NotesRepositoryError {
  final String reason;

  const RejectedError(this.reason);

  @override
  bool operator ==(Object other) =>
      other is RejectedError && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// 취소는 장애가 아니다.
///
/// 당겨서 새로고침이나 화면 이탈로 요청이 취소되면 이 예외로 끝난다. 이것을
/// 네트워크 오류로 다루면 사용자에게는 아무 잘못 없이
/// "네트워크에 연결하지 못했습니다"가 뜬다.
/// Swift의 `CancellationError` / `URLError.cancelled` 판정 대응.
class RequestCancelled implements Exception {
  const RequestCancelled();
}

bool isCancellationError(Object error) => error is RequestCancelled;

/// 리포지토리 오류를 화면에 띄울 문장으로 바꾼다.
///
/// 상태(store)마다 같은 오류를 다른 말로 보여 주면 같은 장애가 화면에 따라
/// 달라 보인다 — 그래서 한 곳에 둔다.
class RepositoryErrorMessage {
  RepositoryErrorMessage._();

  static String text(Object error) => switch (error) {
        NotAuthenticatedError() => '로그인이 필요합니다.',
        RejectedError(:final reason) => '서버가 요청을 거절했습니다: $reason',
        NetworkError() => '네트워크에 연결하지 못했습니다.',
        DecodingError() => '응답을 이해하지 못했습니다.',
        _ => error.toString(),
      };
}
