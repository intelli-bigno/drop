import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drop_mobile/data/services/audio_recorder_service.dart';
import 'package:drop_mobile/data/repositories/attachments_repository.dart';
import 'package:drop_mobile/data/services/whisper_service.dart';
import 'package:drop_mobile/presentation/providers/notes_provider.dart';

part 'recording_provider.g.dart';

/// Recording phase
enum RecordingPhase {
  idle,
  recording,
  transcribing,
}

/// Recording state
@immutable
class RecordingState {
  final RecordingPhase phase;
  final String? activeNoteId;
  final List<double> audioLevels;
  final double recordingTime;
  final String? error;
  final String? audioPath;

  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.activeNoteId,
    this.audioLevels = const [],
    this.recordingTime = 0,
    this.error,
    this.audioPath,
  });

  bool get isIdle => phase == RecordingPhase.idle;
  bool get isRecording => phase == RecordingPhase.recording;
  bool get isTranscribing => phase == RecordingPhase.transcribing;

  String get formattedTime {
    final minutes = (recordingTime ~/ 60).toString();
    final seconds = (recordingTime % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  RecordingState copyWith({
    RecordingPhase? phase,
    String? activeNoteId,
    List<double>? audioLevels,
    double? recordingTime,
    String? error,
    String? audioPath,
    bool clearActiveNoteId = false,
    bool clearError = false,
    bool clearAudioPath = false,
  }) {
    return RecordingState(
      phase: phase ?? this.phase,
      activeNoteId: clearActiveNoteId ? null : (activeNoteId ?? this.activeNoteId),
      audioLevels: audioLevels ?? this.audioLevels,
      recordingTime: recordingTime ?? this.recordingTime,
      error: clearError ? null : (error ?? this.error),
      audioPath: clearAudioPath ? null : (audioPath ?? this.audioPath),
    );
  }
}

/// Provider for managing audio recording and transcription
@Riverpod(keepAlive: true)
class RecordingNotifier extends _$RecordingNotifier {
  final AudioRecorderService _recorder = AudioRecorderService();
  final WhisperService _whisperService = WhisperService();
  Timer? _recordingTimer;
  Timer? _meteringTimer;

  @override
  RecordingState build() {
    ref.onDispose(() {
      _stopTimers();
      _recorder.dispose();
    });
    return const RecordingState();
  }

  /// Start recording and create a placeholder note
  Future<void> startRecording({String? parentId}) async {
    if (!state.isIdle) return;

    try {
      // Check permission first
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(
          error: '마이크 권한이 필요합니다',
        );
        return;
      }

      // Create placeholder note immediately
      final note = await ref.read(notesProvider.notifier).createNote(
        content: '',
        parentId: parentId,
      );

      // Start recording
      final path = await _recorder.startRecording();

      state = state.copyWith(
        phase: RecordingPhase.recording,
        activeNoteId: note.id,
        audioLevels: [],
        recordingTime: 0,
        audioPath: path,
        clearError: true,
      );

      _startTimers();
    } catch (e) {
      debugPrint('[RecordingProvider] Failed to start recording: $e');
      state = state.copyWith(
        error: '녹음을 시작할 수 없습니다: $e',
      );
    }
  }

  /// Stop recording and start transcription
  Future<void> stopRecording() async {
    if (!state.isRecording) return;

    _stopTimers();

    final noteId = state.activeNoteId;
    final audioPath = state.audioPath;

    if (noteId == null || audioPath == null) {
      state = const RecordingState();
      return;
    }

    try {
      await _recorder.stopRecording();

      state = state.copyWith(
        phase: RecordingPhase.transcribing,
        audioLevels: [],
      );

      // Transcribe audio
      String transcribedText;
      try {
        transcribedText = await _whisperService.transcribe(audioPath: audioPath);
      } catch (e) {
        debugPrint('[RecordingProvider] Transcription failed: $e');
        transcribedText = '[음성 메모 - 변환 실패]';
      }

      // Update note with transcribed text
      await ref.read(notesProvider.notifier).updateNote(noteId, transcribedText);

      // Attach audio to note
      await _attachAudioToNote(noteId, audioPath);

      // Clean up audio file (노트 업데이트 + 첨부 업로드가 모두 성공한 뒤에만 삭제)
      await AudioRecorderService.deleteAudioFile(audioPath);

      // Reset state
      state = const RecordingState();
    } catch (e) {
      debugPrint('[RecordingProvider] Failed to stop recording: $e');
      // 실패 시 로컬 오디오 파일은 보존 (녹음 유실 방지)
      state = state.copyWith(
        phase: RecordingPhase.idle,
        error: '녹음 처리 중 오류가 발생했습니다',
        clearActiveNoteId: true,
        clearAudioPath: true,
      );
    }
  }

  /// Cancel recording and delete the placeholder note
  Future<void> cancelRecording() async {
    if (!state.isRecording) return;

    _stopTimers();

    final noteId = state.activeNoteId;
    final audioPath = state.audioPath;

    try {
      await _recorder.cancelRecording();

      // Permanently delete the placeholder note (not soft-delete)
      if (noteId != null) {
        await ref.read(notesProvider.notifier).permanentlyDeleteNote(noteId);
      }

      // Clean up audio file
      if (audioPath != null) {
        await AudioRecorderService.deleteAudioFile(audioPath);
      }
    } catch (e) {
      debugPrint('[RecordingProvider] Failed to cancel recording: $e');
    } finally {
      state = const RecordingState();
    }
  }

  void _startTimers() {
    // Recording time timer (1 second interval)
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final newTime = state.recordingTime + 1;
      state = state.copyWith(recordingTime: newTime);

      // Auto-stop at max duration
      if (newTime >= AudioRecorderService.maxDuration) {
        stopRecording();
      }
    });

    // Audio metering timer (50ms interval)
    _meteringTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
      if (!state.isRecording) return;

      try {
        final amplitude = await _recorder.getAmplitude();
        if (amplitude == null) return;

        // Normalize from dB to 0-1 range
        final level = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);

        final newLevels = [...state.audioLevels, level];
        // Keep only last 50 samples
        if (newLevels.length > 50) {
          newLevels.removeAt(0);
        }

        state = state.copyWith(audioLevels: newLevels);
      } catch (e) {
        // Ignore amplitude errors
      }
    });
  }

  void _stopTimers() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _meteringTimer?.cancel();
    _meteringTimer = null;
  }

  Future<void> _attachAudioToNote(String noteId, String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final attachment = await ref
          .read(attachmentsRepositoryProvider)
          .createAudioAttachment(noteId: noteId, file: file);
      ref.read(notesProvider.notifier).addAttachmentToNote(noteId, attachment);
    } catch (e) {
      debugPrint('[RecordingProvider] Failed to attach audio: $e');
      // 첨부 실패는 상위(stopRecording)에서 처리하도록 전파
      rethrow;
    }
  }
}
