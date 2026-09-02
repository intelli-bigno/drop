/// 목록 행을 왼쪽으로 밀면 오른쪽에서 동작이 나오는 줄 (BRU-207).
/// iOS `HomeView`의 `.swipeActions(edge: .trailing)` 대응.
///
/// 패키지를 쓰지 않고 손으로 만든 이유는 둘이다 — 이번 개편에서 세그먼트·토스트·
/// 시트를 전부 손으로 만들어 시각 언어를 하나로 맞췄고, 스와이프 패키지는 자기
/// 시각 언어(색·모서리·전체 스와이프)를 끌고 들어온다.
///
/// **전체 스와이프는 없다** — 끝까지 밀어도 버튼을 한 번 더 눌러야 실행된다
/// (iOS `allowsFullSwipe: false`와 같다). 고정은 되돌리기 쉬운 동작이지만,
/// 나중에 삭제가 같은 자리에 붙을 때 규칙이 갈리면 손이 먼저 배운 대로 움직인다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';
import 'drop_feedback.dart';

/// 손을 뗐을 때 열지 닫을지.
enum SwipeSettle { open, closed }

/// 이 속도를 넘겨 튕기면 끌린 거리와 무관하게 방향이 정한다 (px/s).
/// 음수가 여는 방향(왼쪽)이다.
const double _flingVelocity = 400;

/// 손을 뗀 순간의 판정. [offset]은 드러난 폭(0 이상), [velocity]는 가로 속도다.
///
/// 위젯이 아니라 함수인 이유: 제스처는 화면 몫이어도 "그래서 열리나"는 규칙이고,
/// 규칙은 위젯 트리 없이 검증할 수 있어야 한다 (`resolveNoteTap`과 같은 태도).
SwipeSettle resolveSwipeSettle({
  required double offset,
  required double actionExtent,
  required double velocity,
}) {
  if (actionExtent <= 0) return SwipeSettle.closed;
  // 튕김이 먼저다 — 손가락이 이미 방향을 말했으면 거리는 묻지 않는다.
  if (velocity <= -_flingVelocity) return SwipeSettle.open;
  if (velocity >= _flingVelocity) return SwipeSettle.closed;
  // 애매한 자리(정확히 절반)는 사용자가 의도한 쪽 — 미는 쪽으로 민다.
  return offset >= actionExtent / 2 ? SwipeSettle.open : SwipeSettle.closed;
}

/// 한 번에 한 줄만 열려 있게 하는 조정자.
///
/// 여러 줄이 동시에 열려 있으면 "지금 무엇을 하려던 참인가"가 흐려지고, 닫으려면
/// 줄마다 따로 밀어야 한다. 화면이 하나 만들어 목록에 나눠 준다.
class DropSwipeCoordinator extends ChangeNotifier {
  Object? _openId;

  Object? get openId => _openId;

  void open(Object id) {
    if (_openId == id) return;
    _openId = id;
    notifyListeners();
  }

  void closeAll() {
    if (_openId == null) return;
    _openId = null;
    notifyListeners();
  }
}

/// 스와이프로 드러나는 동작 하나.
class DropSwipeAction {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  const DropSwipeAction({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });
}

class DropSwipeRow extends StatefulWidget {
  /// 조정자에서 이 줄을 가리키는 값. 목록 안에서 유일해야 한다.
  final Object id;
  final DropSwipeCoordinator coordinator;

  /// 왼쪽으로 밀면 오른쪽에서 나오는 동작들.
  final List<DropSwipeAction> actions;

  /// 꺼지면 아무 일도 하지 않고 [child]만 그린다 (선택 모드 등).
  final bool enabled;

  final Widget child;

  const DropSwipeRow({
    super.key,
    required this.id,
    required this.coordinator,
    required this.actions,
    required this.child,
    this.enabled = true,
  });

  /// 동작 한 칸의 폭. 아이콘 위 글자 아래로 쌓이고, 44 터치 최소를 넉넉히 넘는다.
  static const double actionWidth = 88;

  @override
  State<DropSwipeRow> createState() => _DropSwipeRowState();
}

class _DropSwipeRowState extends State<DropSwipeRow>
    with SingleTickerProviderStateMixin {
  /// `late final ... =` 로 두면 **한 번도 그려지지 않은 줄**(휴지통처럼 동작이
  /// 없어 일찍 돌아가는 경우)이 dispose에서 처음 이 값을 건드리며 컨트롤러를
  /// 그제서야 만든다 — 이미 트리에서 떨어진 뒤라 vsync를 찾다 죽는다.
  late final AnimationController _slide;

  double get _extent => widget.actions.length * DropSwipeRow.actionWidth;

  bool get _isOpen => _slide.value > 0;

  /// 이번 드래그가 시작될 때 이미 열려 있었는가. 끝까지 밀면 드래그 도중에
  /// 값이 1로 붙어 버려, 놓는 순간의 값만으로는 "새로 열렸나"를 알 수 없다.
  bool _openAtDragStart = false;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    widget.coordinator.addListener(_followCoordinator);
  }

  @override
  void didUpdateWidget(DropSwipeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      oldWidget.coordinator.removeListener(_followCoordinator);
      widget.coordinator.addListener(_followCoordinator);
    }
    // 선택 모드로 들어가는 등 도중에 꺼지면 열린 채로 남기지 않는다.
    if (!widget.enabled && _isOpen) _close();
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_followCoordinator);
    _slide.dispose();
    super.dispose();
  }

  /// 다른 줄이 열렸으면 나는 닫는다.
  void _followCoordinator() {
    if (widget.coordinator.openId != widget.id && _isOpen) _close();
  }

  void _close() {
    _slide.animateTo(0, curve: Curves.easeOutCubic);
  }

  /// [withHaptic]은 **이번 스와이프로 비로소 열렸을 때만** 참이다 —
  /// 이미 열린 줄을 다시 밀었다고 손끝에 또 답하면 같은 말을 두 번 하는 셈이다.
  void _open({required bool withHaptic}) {
    if (withHaptic) DropHaptics.select();
    // 알리는 일을 애니메이션보다 먼저 한다 — 다른 줄이 닫히는 것과 이 줄이
    // 열리는 것이 같은 프레임에서 일어나야 한 줄만 열려 보인다.
    widget.coordinator.open(widget.id);
    _slide.animateTo(1, curve: Curves.easeOutCubic);
  }

  void _onDragStart(DragStartDetails details) {
    _openAtDragStart = _slide.value >= 1;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_extent <= 0) return;
    // 왼쪽으로 미는 것이 여는 방향이라 부호를 뒤집는다.
    _slide.value = (_slide.value - details.delta.dx / _extent).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final settle = resolveSwipeSettle(
      offset: _slide.value * _extent,
      actionExtent: _extent,
      velocity: details.velocity.pixelsPerSecond.dx,
    );
    switch (settle) {
      case SwipeSettle.open:
        _open(withHaptic: !_openAtDragStart);
      case SwipeSettle.closed:
        widget.coordinator.closeAll();
        _close();
    }
  }

  /// 동작을 눌렀으면 줄부터 닫고 실행한다 — 열린 채로 목록이 다시 정렬되면
  /// 방금 민 줄이 다른 자리로 가 버려 무엇이 열려 있는지 알 수 없다.
  void _perform(DropSwipeAction action) {
    widget.coordinator.closeAll();
    _close();
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.actions.isEmpty) return widget.child;
    final colors = DropColors.of(context);

    return GestureDetector(
      // 세로 스크롤은 목록이 가져가고, 가로만 이 줄이 받는다.
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) => Stack(
          children: [
            // 뒤에 깔린 동작. 자리는 늘 오른쪽 끝이고, 줄이 비켜서면 드러난다.
            // 닫혀 있을 때는 아예 만들지 않는다 — 가려져 안 보일 뿐인 버튼은
            // 스크린리더에는 그대로 읽히고, 테스트에도 잡힌다.
            if (_isOpen)
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final action in widget.actions) _button(action),
                  ],
                ),
              ),
            Transform.translate(
              offset: Offset(-_slide.value * _extent, 0),
              // 줄은 제 바탕을 들고 움직인다 — 없으면 뒤에 깔린 동작이 글자 사이로 비친다.
              child: Material(color: colors.surfaceCard, child: child),
            ),
            // 열려 있는 동안 줄을 누르면 뷰어가 아니라 닫힘이다.
            if (_isOpen)
              Positioned.fill(
                right: _extent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.coordinator.closeAll();
                    _close();
                  },
                ),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }

  Widget _button(DropSwipeAction action) => SizedBox(
    width: DropSwipeRow.actionWidth,
    child: Material(
      color: action.background,
      child: InkWell(
        onTap: () => _perform(action),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.icon,
              size: DropIconSize.action,
              color: action.foreground,
            ),
            const SizedBox(height: DropTokenSpace.x1),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DropText.caption.copyWith(color: action.foreground),
            ),
          ],
        ),
      ),
    ),
  );
}
