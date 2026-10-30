import 'dart:async';

import '../common/kinetic_image_provider.dart';

import 'package:material_ui/material_ui.dart';

import '../common/common_audio_track.dart';
import '../common/common_player_state.dart';
import '../gsy/gsy_chrome_strings.dart';
import '../gsy/gsy_video_features.dart';
import 'mpv_video_controller_impl.dart';
import 'mpv_video_features.dart';
import 'mpv_chrome_config.dart';

import 'package:flutter/services.dart';

export 'mpv_chrome_config.dart';

/// Bilibili-style overlay aligned with macOS (no pan gestures).
class MpvChromeOverlay extends StatefulWidget {
  const MpvChromeOverlay({
    super.key,
    required this.controller,
    required this.config,
  });

  final MpvVideoControllerImpl controller;
  final MpvChromeConfig config;

  @override
  State<MpvChromeOverlay> createState() => _MpvChromeOverlayState();
}

class _MpvChromeOverlayState extends State<MpvChromeOverlay> {
  static const _rates = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];

  bool _controlsVisible = true;
  bool _locked = false;
  double? _dragPosition;
  final FocusNode _focus = FocusNode();
  MpvChromeConfig get _config => _c.chromeConfig.value ?? widget.config;
  bool _volumeOpen = false;
  bool _settingsOpen = false;
  bool _rateOpen = false;
  bool _qualityOpen = false;
  bool _looping = false;
  bool _muted = false;
  bool _fullscreen = false;
  bool _mirror = false;
  bool _autoPlayNext = true;
  bool _settingsMore = false;
  int _aspectMode = 0;
  double _volume = 1;
  double _rate = 1;
  Timer? _hideTimer;
  List<CommonAudioTrack> _tracks = const [];
  List<MpvVideoTrack> _videoTracks = const [];

  MpvVideoControllerImpl get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _looping = _config.looping;
    _rate = _config.speed;
    _c.chromeConfig.addListener(_onConfig);
    for (final state in [
      _c.playbackRate,
      _c.volume,
      _c.muted,
      _c.looping,
      _c.mirrorHorizontal,
      _c.autoPlayNext,
    ]) {
      state.addListener(_onPlaybackSettings);
    }
    _c.playerState.addListener(_onState);
    _c.chromeLocale.addListener(_onLocale);
    _c.coverUrl.addListener(_onChromeData);
    _c.watermarkUrl.addListener(_onChromeData);
    _c.purePlayMode.addListener(_onChromeData);
    _c.videoTitle.addListener(_onChromeData);
    _c.subtitleEnabled.addListener(_onChromeData);
    _scheduleHide();
  }

  @override
  void dispose() {
    _focus.dispose();
    _hideTimer?.cancel();
    _c.chromeConfig.removeListener(_onConfig);
    for (final state in [
      _c.playbackRate,
      _c.volume,
      _c.muted,
      _c.looping,
      _c.mirrorHorizontal,
      _c.autoPlayNext,
    ]) {
      state.removeListener(_onPlaybackSettings);
    }
    _c.playerState.removeListener(_onState);
    _c.chromeLocale.removeListener(_onLocale);
    _c.coverUrl.removeListener(_onChromeData);
    _c.watermarkUrl.removeListener(_onChromeData);
    _c.purePlayMode.removeListener(_onChromeData);
    _c.videoTitle.removeListener(_onChromeData);
    _c.subtitleEnabled.removeListener(_onChromeData);
    super.dispose();
  }

  void _onConfig() {
    _rate = _config.speed;
    _looping = _config.looping;
    _scheduleHide();
    if (mounted) setState(() {});
  }

  void _onPlaybackSettings() {
    if (!mounted) return;
    setState(() {
      _rate = _c.playbackRate.value;
      _volume = _c.volume.value;
      _muted = _c.muted.value;
      _looping = _c.looping.value;
      _mirror = _c.mirrorHorizontal.value;
      _autoPlayNext = _c.autoPlayNext.value;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_config.enableNativeControls ||
        _c.purePlayMode.value ||
        event is! KeyDownEvent ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _c.mpvExitFullscreen().then((_) async {
        final fullscreen = await _c.mpvIsFullscreen();
        if (mounted) setState(() => _fullscreen = fullscreen);
      });
    } else if (key == LogicalKeyboardKey.keyL && _config.showLockButton) {
      if (!mounted) return KeyEventResult.ignored;
      setState(() {
        _locked = !_locked;
        _controlsVisible = true;
      });
    } else if (_locked) {
      return KeyEventResult.ignored;
    } else if (key == LogicalKeyboardKey.space) {
      _togglePlay();
    } else if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final delta = Duration(
        seconds: HardwareKeyboard.instance.isShiftPressed ? 30 : 5,
      );
      final target =
          _c.position.value +
          (key == LogicalKeyboardKey.arrowRight ? delta : -delta);
      final end = _c.duration.value;
      if (end > Duration.zero) {
        _c.seekTo(
          Duration(
            milliseconds: target.inMilliseconds.clamp(0, end.inMilliseconds),
          ),
        );
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  void _onChromeData() {
    if (mounted) setState(() {});
  }

  void _onState() {
    final state = _c.playerState.value;
    if (state == CommonPlayerState.paused ||
        state == CommonPlayerState.completed ||
        state == CommonPlayerState.idle) {
      _hideTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else if (state == CommonPlayerState.playing) {
      _scheduleHide();
    }
    if (state == CommonPlayerState.ready ||
        state == CommonPlayerState.playing) {
      _refreshVideoTracks();
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshVideoTracks() async {
    try {
      final tracks = await _c.mpvListVideoTracks();
      if (!mounted) return;
      if (!mounted) return;
      setState(() => _videoTracks = tracks);
    } catch (_) {}
  }

  Map<String, String> get _strings =>
      KineticChromeStrings.forLocale(_c.chromeLocale.value);

  String _t(String key) => _strings[key] ?? key;

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_locked ||
        _dragPosition != null ||
        _config.dismissControlTime <= 0 ||
        _c.playerState.value != CommonPlayerState.playing) {
      return;
    }
    if (_volumeOpen || _settingsOpen || _rateOpen || _qualityOpen) return;
    _hideTimer = Timer(Duration(milliseconds: _config.dismissControlTime), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (!_controlsVisible) {
        _volumeOpen = false;
        _settingsOpen = false;
        _rateOpen = false;
        _qualityOpen = false;
      }
    });
    if (_controlsVisible) _scheduleHide();
  }

  Future<void> _togglePlay() async {
    final state = _c.playerState.value;
    if (state == CommonPlayerState.playing) {
      await _c.pause();
    } else {
      await _c.play();
    }
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _c.setMute(_muted);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setVolume(double value) async {
    _volume = value.clamp(0, 1);
    if (_muted && _volume > 0) {
      _muted = false;
      await _c.setMute(false);
    }
    await _c.setVolume(_volume);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setRate(double rate) async {
    _rate = rate;
    _rateOpen = false;
    await _c.setRate(rate);
    if (!mounted) return;
    setState(() {});
    _scheduleHide();
  }

  Future<void> _toggleFullscreen() async {
    final current = await _c.mpvIsFullscreen();
    if (current) {
      await _c.mpvExitFullscreen();
    } else {
      await _c.bridgeChannel.invokeMethod<void>('mpvEnterFullscreen');
    }
    final fullscreen = await _c.mpvIsFullscreen();
    if (mounted) setState(() => _fullscreen = fullscreen);
  }

  Future<void> _openSettings() async {
    _tracks = await _c.getAudioTracks();
    _videoTracks = await _c.mpvListVideoTracks();
    if (!mounted) return;
    setState(() {
      _settingsOpen = !_settingsOpen;
      _settingsMore = false;
      _volumeOpen = false;
      _rateOpen = false;
      _qualityOpen = false;
    });
    _scheduleHide();
  }

  Future<void> _openQuality() async {
    _videoTracks = await _c.mpvListVideoTracks();
    if (!mounted) return;
    setState(() {
      _qualityOpen = !_qualityOpen;
      _settingsOpen = false;
      _volumeOpen = false;
      _rateOpen = false;
    });
    _scheduleHide();
  }

  Future<void> _selectVideoTrack(int index) async {
    await _c.mpvSelectVideoTrack(index);
    _videoTracks = await _c.mpvListVideoTracks();
    if (!mounted) return;
    setState(() => _qualityOpen = false);
    _scheduleHide();
  }

  Future<void> _selectTrack(int index) async {
    await _c.selectAudioTrack(index);
    _tracks = await _c.getAudioTracks();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleLoop() async {
    _looping = !_looping;
    if (_looping) {
      _autoPlayNext = false;
      await _c.mpvSetAutoPlayNext(enabled: false);
    }
    await _c.setLooping(_looping);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleMirror() async {
    _mirror = !_mirror;
    await _c.mpvSetMirrorHorizontal(enabled: _mirror);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleSubtitle() async {
    await _c.mpvSetSubtitleEnabled(enabled: !_c.subtitleEnabled.value);
  }

  Future<void> _setAspect(int mode) async {
    _aspectMode = mode;
    final types = GsyShowType.values;
    if (mode >= 0 && mode < types.length) {
      await _c.mpvSetShowType(types[mode]);
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _screenshot() async {
    final bytes = await _c.captureFrame();
    _c.onScreenshotCaptured?.call(bytes);
    if (!mounted) return;
    setState(() => _settingsOpen = false);
  }

  String _fmt(Duration d) {
    final t = d.isNegative ? Duration.zero : d;
    final h = t.inHours;
    final m = t.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = t.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  bool get _showCover {
    final state = _c.playerState.value;
    final url = _c.coverUrl.value;
    final hasCover = (url ?? '').isNotEmpty;
    switch (state) {
      case CommonPlayerState.playing:
      case CommonPlayerState.buffering:
      case CommonPlayerState.paused:
        return false;
      case CommonPlayerState.completed:
        return !_config.keepLastFrameWhenComplete;
      case CommonPlayerState.idle:
      case CommonPlayerState.ready:
      case CommonPlayerState.error:
        return hasCover;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => _buildChrome(context, bounds),
  );

  Widget _buildChrome(BuildContext context, BoxConstraints bounds) {
    final popupBottom = bounds.maxWidth < 560 ? 100.0 : 56.0;
    Widget popup(Widget child) => ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (bounds.maxWidth - 24).clamp(0, double.infinity),
        maxHeight: (bounds.maxHeight - popupBottom - 8).clamp(
          0,
          double.infinity,
        ),
      ),
      child: child,
    );
    final watermark = _c.watermarkUrl.value;
    final purePlay = _c.purePlayMode.value;
    final showChrome = _config.enableNativeControls && !purePlay && !_locked;

    final playing = _c.playerState.value == CommonPlayerState.playing;
    final buffering = _c.playerState.value == CommonPlayerState.buffering;
    final accent = _config.accentColor;
    final title = _c.videoTitle.value;

    return Material(
      type: MaterialType.transparency,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onHover: showChrome
              ? (_) {
                  if (!_controlsVisible && mounted) {
                    if (!mounted) return;
                    setState(() => _controlsVisible = true);
                  }
                  _scheduleHide();
                }
              : null,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _config.enableNativeControls && !purePlay
                ? (_) => _focus.requestFocus()
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: showChrome ? _toggleControls : null,
                    onDoubleTap: showChrome ? _togglePlay : null,
                  ),
                ),
                if (_showCover) _cover(),
                if (watermark != null && watermark.isNotEmpty)
                  _watermark(watermark),
                if (buffering)
                  const Center(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                if (showChrome && _controlsVisible) ...[
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                          stops: const [0.55, 1],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  if (title.isNotEmpty)
                    Positioned(
                      left: 12,
                      top: 10,
                      right: 12,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ),
                  Center(
                    child: _iconButton(
                      playing ? Icons.pause : Icons.play_arrow,
                      size: 56,
                      tooltip: _t('kinetic_play_pause_icon'),
                      onPressed: _togglePlay,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _bottomBar(playing, accent),
                  ),
                  if (_volumeOpen && _config.showVolumeToolbar)
                    Positioned(
                      right: _config.showFullscreenButton ? 96 : 56,
                      bottom: popupBottom,
                      child: popup(_volumePopup(accent)),
                    ),
                  if (_settingsOpen && _config.showSettingsButton)
                    Positioned(
                      right: 12,
                      bottom: popupBottom,
                      child: popup(_settingsPopup(accent)),
                    ),
                  if (_rateOpen)
                    Positioned(
                      right: _config.showFullscreenButton ? 48 : 8,
                      bottom: popupBottom,
                      child: popup(_ratePopup(accent)),
                    ),
                  if (_qualityOpen)
                    Positioned(
                      right: 12,
                      bottom: popupBottom,
                      child: popup(_qualityPopup(accent)),
                    ),
                ],
                if (_config.enableNativeControls &&
                    !purePlay &&
                    _config.showLockButton &&
                    (_locked || _controlsVisible))
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: _barIcon(
                          _locked ? Icons.lock : Icons.lock_open,
                          _locked ? 'Unlock (L)' : 'Lock (L)',
                          () => setState(() {
                            _locked = !_locked;
                            _volumeOpen = false;
                            _settingsOpen = false;
                            _rateOpen = false;
                            _qualityOpen = false;
                          }),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover() {
    final url = _c.coverUrl.value;
    return GestureDetector(
      onTap: _config.thumbPlay ? _togglePlay : null,
      child: ColoredBox(
        color: Colors.black,
        child: url == null || url.isEmpty
            ? const SizedBox.expand()
            : Image(
                image: kineticImageProvider(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return const SizedBox.expand();
                },
              ),
      ),
    );
  }

  Widget _watermark(String url) {
    return Positioned(
      right: 12,
      bottom: 56,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.7,
          child: Image(
            image: kineticImageProvider(url),
            width: 96,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(bool playing, Color accent) {
    Widget time(Duration value) => Text(
      _fmt(value),
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );
    Widget timeline() => ValueListenableBuilder<Duration>(
      valueListenable: _c.position,
      builder: (context, pos, _) {
        final duration = _c.duration.value;
        final max = duration.inMilliseconds <= 0
            ? 1.0
            : duration.inMilliseconds.toDouble();
        final value = (_dragPosition ?? pos.inMilliseconds.toDouble())
            .clamp(0, max)
            .toDouble();
        return Row(
          children: [
            time(pos),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: accent,
                ),
                child: Slider(
                  min: 0,
                  max: max,
                  value: value,
                  onChangeStart: (_) => _hideTimer?.cancel(),
                  onChanged: duration <= Duration.zero
                      ? null
                      : (v) => setState(() => _dragPosition = v),
                  onChangeEnd: (v) async {
                    await _c.seekTo(Duration(milliseconds: v.round()));
                    if (mounted) setState(() => _dragPosition = null);
                    _scheduleHide();
                  },
                ),
              ),
            ),
            time(duration),
          ],
        );
      },
    );
    Widget play() => _barIcon(
      playing ? Icons.pause : Icons.play_arrow,
      _t('kinetic_play_pause_icon'),
      _togglePlay,
    );
    List<Widget> actions() => [
      SizedBox(
        width: 44,
        height: 44,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          onPressed: () {
            setState(() {
              _rateOpen = !_rateOpen;
              _volumeOpen = false;
              _settingsOpen = false;
              _qualityOpen = false;
            });
            _scheduleHide();
          },
          child: Text(
            '${_rate.toStringAsFixed((_rate * 10).roundToDouble() == _rate * 10 ? 1 : 2)}x',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
      if (_config.showSettingsButton)
        _barIcon(Icons.settings, _t('kinetic_settings_icon'), _openSettings),
      if (_config.showVolumeToolbar)
        _barIcon(
          _muted || _volume <= 0 ? Icons.volume_off : Icons.volume_up,
          _t('kinetic_volume_icon'),
          () {
            setState(() {
              _volumeOpen = !_volumeOpen;
              _settingsOpen = false;
              _rateOpen = false;
              _qualityOpen = false;
            });
            _scheduleHide();
          },
        ),
      if (_config.showFullscreenButton)
        _barIcon(
          _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          _t('kinetic_fullscreen_icon'),
          _toggleFullscreen,
        ),
    ];
    return ColoredBox(
      color: const Color(0x99000000),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: LayoutBuilder(
          builder: (context, box) => box.maxWidth < 544
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 44, child: timeline()),
                    Row(children: [play(), const Spacer(), ...actions()]),
                  ],
                )
              : Row(
                  children: [
                    play(),
                    Expanded(child: timeline()),
                    ...actions(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _barIcon(IconData icon, String tooltip, VoidCallback onPressed) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 22),
        iconSize: 36,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _iconButton(
    IconData icon, {
    required double size,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: size * 0.7),
      iconSize: size,
    );
  }

  Widget _panel(Widget child) {
    return Material(
      color: const Color(0xE6101010),
      borderRadius: BorderRadius.circular(8),
      elevation: 8,
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }

  Widget _volumePopup(Color accent) {
    return _panel(
      SizedBox(
        height: 140,
        width: 56,
        child: Column(
          children: [
            Text(
              '${(_volume * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: RotatedBox(
                quarterTurns: -1,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    thumbColor: accent,
                    inactiveTrackColor: Colors.white24,
                  ),
                  child: Slider(value: _volume, onChanged: _setVolume),
                ),
              ),
            ),
            IconButton(
              onPressed: _toggleMute,
              icon: Icon(
                _muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratePopup(Color accent) {
    return _panel(
      SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('kinetic_rate_title'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            for (final rate in _rates)
              TextButton(
                onPressed: () => _setRate(rate),
                child: Text(
                  '${rate}x',
                  style: TextStyle(
                    color: _rate == rate ? accent : Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _settingsPopup(Color accent) {
    return _panel(
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_settingsMore)
                TextButton(
                  onPressed: () => setState(() => _settingsMore = false),
                  child: Text(
                    _t('kinetic_settings_more_back'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                )
              else
                Text(
                  _t('kinetic_settings_title'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              const SizedBox(height: 8),
              if (!_settingsMore) ...[
                TextButton(
                  onPressed: _toggleSubtitle,
                  child: Text(
                    _t('kinetic_subtitle_toggle'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _openQuality,
                  child: Text(
                    _t('kinetic_quality_icon'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
              if (_settingsMore) ...[
                Text(
                  _t('kinetic_settings_playback_mode'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                TextButton(
                  onPressed: () async {
                    _autoPlayNext = false;
                    await _c.mpvSetAutoPlayNext(enabled: false);
                    if (!mounted) return;
                    setState(() {});
                  },
                  child: Text(
                    _t('kinetic_settings_mode_pause'),
                    style: TextStyle(
                      color: !_autoPlayNext ? accent : Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    _looping = false;
                    await _c.setLooping(false);
                    _autoPlayNext = true;
                    await _c.mpvSetAutoPlayNext(enabled: true);
                    if (!mounted) return;
                    setState(() {});
                  },
                  child: Text(
                    _t('kinetic_settings_mode_next'),
                    style: TextStyle(
                      color: _autoPlayNext ? accent : Colors.white,
                    ),
                  ),
                ),
                Text(
                  _t('kinetic_settings_aspect'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                TextButton(
                  onPressed: () => _setAspect(0),
                  child: Text(
                    _t('kinetic_settings_aspect_auto'),
                    style: TextStyle(
                      color: _aspectMode == 0 ? accent : Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _setAspect(1),
                  child: Text(
                    _t('kinetic_settings_aspect_16_9'),
                    style: TextStyle(
                      color: _aspectMode == 1 ? accent : Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _setAspect(2),
                  child: Text(
                    _t('kinetic_settings_aspect_4_3'),
                    style: TextStyle(
                      color: _aspectMode == 2 ? accent : Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  _t('kinetic_audio_tracks'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                if (_tracks.isEmpty)
                  Text(
                    _t('kinetic_no_audio_tracks'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  )
                else
                  for (final track in _tracks)
                    TextButton(
                      onPressed: () => _selectTrack(track.index),
                      child: Text(
                        _ellipsis(
                          track.label.isEmpty
                              ? (track.language ?? '#${track.index}')
                              : track.label,
                        ),
                        style: TextStyle(
                          color: track.selected ? accent : Colors.white,
                        ),
                      ),
                    ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    _t('kinetic_settings_mirror'),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  value: _mirror,
                  activeThumbColor: accent,
                  onChanged: (_) => _toggleMirror(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    _t('kinetic_settings_loop'),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  value: _looping,
                  activeThumbColor: accent,
                  onChanged: (_) => _toggleLoop(),
                ),
                TextButton(
                  onPressed: () => setState(() => _settingsMore = true),
                  child: Text(
                    _t('kinetic_settings_more'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton.icon(
                  onPressed: _screenshot,
                  icon: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: Text(
                    _t('kinetic_settings_screenshot'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _qualityPopup(Color accent) {
    return _panel(
      SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('kinetic_quality_title'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            TextButton(
              onPressed: () => _selectVideoTrack(-1),
              child: Text(
                _t('kinetic_quality_auto'),
                style: TextStyle(
                  color: _videoTracks.every((t) => !t.selected)
                      ? accent
                      : Colors.white,
                ),
              ),
            ),
            for (final track in _videoTracks)
              TextButton(
                onPressed: () => _selectVideoTrack(track.index),
                child: Text(
                  _ellipsis(
                    track.label.isEmpty ? '#${track.index}' : track.label,
                  ),
                  style: TextStyle(
                    color: track.selected ? accent : Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _ellipsis(String text) {
    if (text.length <= 10) return text;
    return '${text.substring(0, 10)}…';
  }
}
