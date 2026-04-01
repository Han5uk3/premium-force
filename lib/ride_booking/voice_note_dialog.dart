import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'dart:io';
import 'dart:async';

class VoiceNoteDialog extends StatefulWidget {
  final String? initialAudioPath;
  const VoiceNoteDialog({super.key, this.initialAudioPath});

  @override
  State<VoiceNoteDialog> createState() => _VoiceNoteDialogState();
}

class _VoiceNoteDialogState extends State<VoiceNoteDialog> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _audioPath;

  Timer? _timer;
  int _recordDuration = 0;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPath = widget.initialAudioPath;
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _audioPosition = Duration.zero;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _audioDuration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() => _recordDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final mins = twoDigits(seconds ~/ 60);
    final secs = twoDigits(seconds % 60);
    return "$mins:$secs";
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath =
            '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _audioPath = null;
          _recordDuration = 0;
        });
        _startTimer();
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _playPauseAudio() async {
    if (_audioPath == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_audioPath!));
    }
  }

  Future<void> _deleteRecording() async {
    if (_audioPath != null) {
      final file = File(_audioPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    setState(() {
      _audioPath = null;
      _isPlaying = false;
      _recordDuration = 0;
      _audioDuration = Duration.zero;
      _audioPosition = Duration.zero;
    });
    await _audioPlayer.stop();
    if (mounted) Navigator.pop(context, 'DELETED');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: const Color(0xFF141313),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.voiceNote,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white60),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Content
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  if (_audioPath != null) ...[
                    GestureDetector(
                      onTap: _playPauseAudio,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: const Color(0xFFE4A46B),
                        size: 28,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          activeColor: const Color(0xFFE4A46B),
                          inactiveColor: Colors.white24,
                          value: _audioPosition.inMilliseconds.toDouble().clamp(
                            0.0,
                            _audioDuration.inMilliseconds > 0
                                ? _audioDuration.inMilliseconds.toDouble()
                                : 1.0,
                          ),
                          max: _audioDuration.inMilliseconds > 0
                              ? _audioDuration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (value) {
                            _audioPlayer.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                      ),
                    ),
                    Text(
                      _audioDuration.inMilliseconds > 0
                          ? _formatDuration(_audioPosition.inSeconds)
                          : _formatDuration(_recordDuration),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _deleteRecording,
                      child: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFCF6679),
                        size: 24,
                      ),
                    ),
                  ] else if (_isRecording) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.mic, color: Color(0xFFCF6679), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _stopRecording,
                      child: Container(
                        height: 36,
                        width: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE4A46B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stop,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          loc.recordVoiceNote,
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _startRecording,
                      child: Container(
                        height: 36,
                        width: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE4A46B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            if (_audioPath != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _audioPath);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE4A46B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  loc.saveVoiceNote,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
