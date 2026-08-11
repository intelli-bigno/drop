import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

const _fabBackgroundColor = Color(0xFF4A9EFF);
const _expandDuration = Duration(milliseconds: 180);

/// Slightly underdamped so the actions overshoot a touch on the way out.
const _dialSpring = SpringDescription(mass: 1, stiffness: 520, damping: 26);

/// Each action starts this much later than the one below it.
const _staggerPerItem = 0.08;

/// How far below its resting place an action starts, in logical pixels.
const _riseDistance = 16.0;

/// Speed-dial FAB for the home screen.
///
/// Collapsed it shows a single trigger button; tapping it reveals the
/// capture actions (record / camera / gallery) with labels.
class ActionButtons extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onAddPressed;
  final VoidCallback onRecordPressed;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;

  /// Called whenever the dial opens or closes, so the host screen can
  /// dim the content behind it.
  final ValueChanged<bool>? onExpandedChanged;

  const ActionButtons({
    super.key,
    required this.isRecording,
    required this.onAddPressed,
    required this.onRecordPressed,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    this.onExpandedChanged,
  });

  @override
  ActionButtonsState createState() => ActionButtonsState();
}

class ActionButtonsState extends State<ActionButtons>
    with SingleTickerProviderStateMixin {
  // Unbounded so the spring may overshoot past 1.0 and settle back.
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );
  bool _isExpanded = false;

  @override
  void didUpdateWidget(ActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A running recording takes over the screen; the dial must not stay open.
    if (widget.isRecording && _isExpanded) {
      _setExpanded(false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Closes the dial from outside (e.g. tapping the scrim behind it).
  void collapse() => _setExpanded(false);

  void _setExpanded(bool value) {
    if (_isExpanded == value) return;
    setState(() => _isExpanded = value);
    // Carry the current position and velocity into the new spring so an
    // interrupted animation continues from where the finger left it.
    _controller.animateWith(
      SpringSimulation(
        _dialSpring,
        _controller.value,
        value ? 1.0 : 0.0,
        _controller.velocity,
      ),
    );
    widget.onExpandedChanged?.call(value);
  }

  void _onTriggerPressed() {
    // While recording the trigger is a plain "new note" button.
    if (widget.isRecording) {
      widget.onAddPressed();
      return;
    }
    _setExpanded(!_isExpanded);
  }

  void _run(VoidCallback action) {
    _setExpanded(false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final actions = <_DialAction>[
      _DialAction(
        icon: Icons.photo_library,
        label: '갤러리',
        onPressed: () => _run(widget.onGalleryPressed),
      ),
      _DialAction(
        icon: Icons.camera_alt,
        label: '카메라',
        onPressed: () => _run(widget.onCameraPressed),
      ),
      _DialAction(
        icon: Icons.mic,
        label: '녹음',
        onPressed: () => _run(widget.onRecordPressed),
      ),
      _DialAction(
        icon: Icons.edit,
        label: '메모',
        onPressed: () => _run(widget.onAddPressed),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          _DialItem(
            action: actions[i],
            progress: _controller,
            // Items closest to the trigger lead the animation.
            delay: (actions.length - 1 - i) * _staggerPerItem,
          ),
          const SizedBox(height: 12),
        ],
        _TriggerFab(isExpanded: _isExpanded, onPressed: _onTriggerPressed),
      ],
    );
  }
}

class _DialAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _DialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// A single labeled action that springs out of the trigger.
class _DialItem extends StatelessWidget {
  final _DialAction action;
  final Animation<double> progress;
  final double delay;

  const _DialItem({
    required this.action,
    required this.progress,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        // Remap the shared spring onto this item's own slice of the run.
        final t = (progress.value - delay) / (1 - delay);
        // Fully collapsed: keep the actions out of the tree entirely.
        if (t <= 0.001) return const SizedBox.shrink();
        // Layout follows the clamped value so the column doesn't jitter while
        // the spring overshoots; the scale keeps the overshoot visible.
        final settled = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: settled,
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            heightFactor: settled,
            child: Transform.translate(
              offset: Offset(0, (1 - settled) * _riseDistance),
              child: Transform.scale(
                alignment: Alignment.centerRight,
                scale: t.clamp(0.0, 1.15),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialLabel(text: action.label, onTap: action.onPressed),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            height: 44,
            child: FloatingActionButton(
              heroTag: 'dial_${action.label}',
              onPressed: action.onPressed,
              backgroundColor: _fabBackgroundColor,
              elevation: 2,
              child: Icon(action.icon, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialLabel extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _DialLabel({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TriggerFab extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;

  const _TriggerFab({required this.isExpanded, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'dial_trigger',
      onPressed: onPressed,
      backgroundColor: _fabBackgroundColor,
      child: AnimatedSwitcher(
        duration: _expandDuration,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isExpanded ? Icons.close : Icons.add,
          key: ValueKey(isExpanded),
        ),
      ),
    );
  }
}
