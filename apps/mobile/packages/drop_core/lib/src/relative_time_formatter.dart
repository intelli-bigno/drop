/// 노트 목록에 붙는 상대 시간 문구. DropCore `RelativeTimeFormatter.swift` 대응.
///
/// 문구는 iOS 네이티브와 1:1로 같아야 한다 — 두 앱이 같은 데이터를 병렬로
/// 보여주는 기간이 있기 때문이다. 스펙은 Swift 테스트 스위트(상대 시간 표기).
String relativeTimeString(DateTime date, {required DateTime now}) {
  final local = date.toLocal();
  final localNow = now.toLocal();

  var elapsed = localNow.difference(local);
  if (elapsed.isNegative) elapsed = Duration.zero;

  final seconds = elapsed.inSeconds;
  if (seconds < 60) return '$seconds초전';

  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes분전';

  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(localNow.year, localNow.month, localNow.day);

  String clockTime() {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  if (day == today) return '오늘 ${clockTime()}';
  if (day == today.subtract(const Duration(days: 1))) return '어제 ${clockTime()}';

  return '${local.year}. ${local.month}. ${local.day}.';
}
