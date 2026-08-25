import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'dart:async';

class VoicePlayer extends StatefulWidget {
  final String audioUrl;
  const VoicePlayer({super.key, required this.audioUrl});

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (widget.audioUrl.isEmpty || !widget.audioUrl.startsWith('http')) {
          throw Exception("Invalid audio URL");
        }
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      if (mounted) {
        AnimatedSnackBar.show(
          context,
          AppLocalizations.of(context)!.couldNotPlayAudio,
          'E',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _playPause,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                // On the gold disc, so it takes the on-gold ink rather than the
                // page's.
                color: c.onAccent,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: c.accent,
                inactiveTrackColor: c.border,
                thumbColor: c.accent,
              ),
              child: Slider(
                min: 0,
                max: _duration.inMilliseconds.toDouble() > 0
                    ? _duration.inMilliseconds.toDouble()
                    : 1.0,
                value: _position.inMilliseconds.toDouble().clamp(
                  0,
                  _duration.inMilliseconds.toDouble() > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                ),
                onChanged: (value) async {
                  await _audioPlayer.seek(
                    Duration(milliseconds: value.toInt()),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Position, then total: the elapsed side is the one being read, so it
          // carries the stronger ink.
          Text(
            _formatDuration(_position),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(" / ", style: TextStyle(color: c.textTertiary, fontSize: 10)),
          Text(
            _formatDuration(_duration),
            style: TextStyle(color: c.textTertiary, fontSize: 10),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
