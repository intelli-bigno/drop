/// 값 동등성 도우미 — `package:collection` 없이 쓰는 최소한.
library;

bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int listHash(List<Object?> values) => Object.hashAll(values);
