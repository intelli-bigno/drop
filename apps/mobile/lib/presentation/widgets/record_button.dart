import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drop_mobile/data/services/audio_recorder_service.dart';
import 'package:drop_mobile/presentation/widgets/waveform_view.dart';

/// Recording button with waveform visualization
class RecordButton extends ConsumerStatefulWidget {
  final void Function(String audioPath)? onRecordingComplete;
  final VoidCallback? onRecordingStart;
  final VoidCallback? onRecordingCancel;
  final bool enabled;

  const RecordButton({
    super.key,
    this.onRecordingComplete,
    this.onRecordingStart,
    this.onRecordingCancel,
    this.enabled = true,
  });

  @override
  ConsumerState<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends ConsumerState<RecordButton>
    with SingleTickerProviderStateMixin {
  final AudioRecorderService _recorder = AudioRecorderService();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _recorder.onStateChanged = () {
      if (mounted) setState(() {});
    };

    _recorder.onMaxDurationReached = () {
      _onRecordingComplete();
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!widget.enabled) return;
    HapticFeedback.mediumImpact();

    if (_recorder.isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.startRecording();
      _animationController.forward();
      widget.onRecordingStart?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('녹음을 시작할 수 없습니다')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stopRecording();
    _animationController.reverse();

    if (path != null) {
      _onRecordingComplete(path);
    }
  }

  void _onRecordingComplete([String? path]) {
    if (path != null) {
      widget.onRecordingComplete?.call(path);
    }
  }

  Future<void> _cancelRecording() async {
    await _recorder.cancelRecording();
    _animationController.reverse();
    widget.onRecordingCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Waveform and time display (when recording)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _recorder.isRecording ? _buildRecordingView() : const SizedBox.shrink(),
        ),

        const SizedBox(height: 12),

        // Record button
        GestureDetector(
          onTap: widget.enabled ? _handleTap : null,
          onLongPress:
              _recorder.isRecording && widget.enabled ? _cancelRecording : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? (_recorder.isRecording
                      ? Colors.red
                      : const Color(0xFF4A9EFF))
                  : const Color(0xFF3A3A3A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _recorder.isRecording
                    ? Container(
                        key: const ValueKey('stop'),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : const Icon(
                        key: ValueKey('mic'),
                        Icons.mic,
                        color: Colors.white,
                        size: 40,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingView() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform
          SizedBox(
            height: 40,
            child: WaveformView(
              levels: _recorder.audioLevels,
              color: const Color(0xFF4A9EFF),
            ),
          ),

          const SizedBox(height: 8),

          // Time display
          Text(
            _recorder.formattedTime,
            style: const TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: 4),

          // Cancel hint
          Text(
            '길게 눌러서 취소',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
