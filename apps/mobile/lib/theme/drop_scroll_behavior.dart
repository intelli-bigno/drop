/// 스크롤 동작 (BRU-207). 폰 화면을 브라우저에서 검수하거나 데스크톱 웹으로 쓸 때
/// 마우스 드래그로도 목록이 밀리게 하고, 스크롤바는 그리지 않는다 — 폰 화면에
/// 스크롤바가 서면 그 순간 "웹 페이지"로 읽힌다.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class DropScrollBehavior extends MaterialScrollBehavior {
  const DropScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
