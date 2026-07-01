import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const KineticPlayerExampleApp());
}

class KineticPlayerExampleApp extends StatelessWidget {
  const KineticPlayerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinetic Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PlayerDemoPage(),
    );
  }
}

/// Demo media URLs (Android GSY).
class _DemoMedia {
  static const videoUrl =
      'https://www.w3schools.com/html/mov_bbb.mp4';

  /// Stable public JPEGs for demo seek-preview cues (avoid picsum 404/redirect).
  static const _previewImages = <String>[
    'https://www.gstatic.com/webp/gallery/1.jpg',
    'https://www.gstatic.com/webp/gallery/2.jpg',
    'https://www.gstatic.com/webp/gallery/3.jpg',
    'https://www.gstatic.com/webp/gallery/4.jpg',
  ];

  /// Writes a WebVTT track with public thumbnail URLs for seek preview.
  static Future<String> preparePreviewVttUri() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kinetic_demo_preview_v2.vtt');
    await file.writeAsString(_buildPreviewVtt());
    return file.uri.toString();
  }

  static String _buildPreviewVtt() {
    final buffer = StringBuffer('WEBVTT\n\n');
    for (var i = 0; i < 12; i++) {
      final startSec = i * 5;
      final endSec = startSec + 5;
      buffer.writeln(
        '${_formatVttTime(startSec)} --> ${_formatVttTime(endSec)}',
      );
      buffer.writeln(_previewImages[i % _previewImages.length]);
      buffer.writeln();
    }
    return buffer.toString();
  }

  static String _formatVttTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds.000';
  }

  static const _subtitleLines = <String>[
    'Kinetic Player 字幕示例',
    '外挂 WebVTT 字幕轨道',
    '拖动进度条可验证同步',
    '支持 SRT / WebVTT 文件',
    '也可用下方输入框推送字幕',
    'gsySetEmbeddedSubtitleText',
  ];

  /// Demo WebVTT subtitle track aligned to the sample video timeline.
  static Future<String> prepareSubtitleVttUri() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kinetic_demo_subtitles.vtt');
    await file.writeAsString(_buildSubtitleVtt());
    return file.uri.toString();
  }

  static String _buildSubtitleVtt() {
    final buffer = StringBuffer('WEBVTT\n\n');
    for (var i = 0; i < _subtitleLines.length; i++) {
      final startSec = i * 8;
      final endSec = startSec + 8;
      buffer.writeln(
        '${_formatVttTime(startSec)} --> ${_formatVttTime(endSec)}',
      );
      buffer.writeln(_subtitleLines[i]);
      buffer.writeln();
    }
    return buffer.toString();
  }

  static const _danmakuColors = <int>[
    0xFFFFFF,
    0xFF5252,
    0xFFD740,
    0x69F0AE,
    0x40C4FF,
  ];

  static const _demoDanmaku = <_DanmakuCue>[
    _DanmakuCue(0, 'Kinetic Player 弹幕示例'),
    _DanmakuCue(2, 'DanmakuFlameMaster + B 站 XML'),
    _DanmakuCue(4, '从右向左滚动弹幕'),
    _DanmakuCue(6, '支持加载本地 XML 文件'),
    _DanmakuCue(8, '也可在下方输入框发送弹幕'),
    _DanmakuCue(10, 'gsySetDanmakuUrl / gsyToggleDanmaku'),
  ];

  /// Bilibili XML danmaku track for demo playback.
  static Future<String> prepareDanmakuXmlUri({
    List<_DanmakuCue> extra = const [],
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kinetic_demo_danmaku.xml');
    await file.writeAsString(_buildDanmakuXml([..._demoDanmaku, ...extra]));
    return file.uri.toString();
  }

  static String _buildDanmakuXml(List<_DanmakuCue> cues) {
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?><i>',
    );
    for (var i = 0; i < cues.length; i++) {
      final cue = cues[i];
      final color = _danmakuColors[i % _danmakuColors.length];
      buffer.write(
        '<d p="${cue.timeSec.toStringAsFixed(1)},1,25,$color,0,0,0,0">'
        '${_escapeXml(cue.text)}</d>',
      );
    }
    buffer.write('</i>');
    return buffer.toString();
  }

  static String _escapeXml(String text) =>
      text
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;');
}

class _DanmakuCue {
  const _DanmakuCue(this.timeSec, this.text);

  final double timeSec;
  final String text;
}

class PlayerDemoPage extends StatefulWidget {
  const PlayerDemoPage({super.key});

  @override
  State<PlayerDemoPage> createState() => _PlayerDemoPageState();
}

class _PlayerDemoPageState extends State<PlayerDemoPage> {
  String? _previewVttUri;
  CommonVideoController? _controller;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _DemoMedia.preparePreviewVttUri().then((uri) {
        if (mounted) setState(() => _previewVttUri = uri);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final previewReady = !isAndroid || _previewVttUri != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Kinetic Player Demo')),
      body: previewReady
          ? Column(
              children: [
                Expanded(
                  flex: 3,
                  child: CommonVideoPlayerViewBuilder(
                    url: _DemoMedia.videoUrl,
                    creationParams: isAndroid
                        ? GsyUiConfig(
                            enableNativeControls: true,
                            showFullscreenButton: true,
                            showDragProgressTextOnSeekBar: true,
                            videoTitle: 'GSY Demo',
                            previewVttUrl: _previewVttUri,
                          ).toCreationParams()
                        : null,
                    builder: (controller) {
                      if (!identical(_controller, controller)) {
                        setState(() => _controller = controller);
                      }
                    },
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: _ControlPanel(controller: _controller),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ControlPanel extends StatefulWidget {
  const _ControlPanel({this.controller});

  final CommonVideoController? controller;

  @override
  State<_ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<_ControlPanel> {
  static final ValueNotifier<CommonPlayerState> _idleState =
      ValueNotifier(CommonPlayerState.idle);
  static final ValueNotifier<Duration> _zeroDuration =
      ValueNotifier(Duration.zero);

  List<String> _filters = const ['none', 'sepia', 'gaussianBlur', 'greyScale'];
  String _selectedFilter = 'none';
  String? _subtitleVttUri;
  bool _subtitlesEnabled = true;
  String? _danmakuXmlUri;
  bool _danmakuVisible = false;
  bool _loopingEnabled = false;
  String? _lastCapturePath;
  List<CommonAudioTrack> _audioTracks = const [];
  int? _selectedAudioTrackIndex;
  final List<_DanmakuCue> _customDanmaku = [];
  final TextEditingController _subtitleTextController = TextEditingController(
    text: 'Hello from Flutter — gsySetEmbeddedSubtitleText',
  );
  final TextEditingController _danmakuTextController = TextEditingController(
    text: 'Hello Danmaku!',
  );

  @override
  void initState() {
    super.initState();
    _loadFilters();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _DemoMedia.prepareSubtitleVttUri().then((uri) {
        if (mounted) setState(() => _subtitleVttUri = uri);
      });
      _DemoMedia.prepareDanmakuXmlUri().then((uri) {
        if (mounted) setState(() => _danmakuXmlUri = uri);
      });
    }
  }

  @override
  void dispose() {
    _subtitleTextController.dispose();
    _danmakuTextController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _loadFilters();
      _loadAudioTracks();
    }
  }

  Future<void> _loadAudioTracks() async {
    final controller = widget.controller;
    if (controller == null) return;
    final tracks = await controller.getAudioTracks();
    if (!mounted) return;
    setState(() {
      _audioTracks = tracks;
      _selectedAudioTrackIndex =
          tracks.where((t) => t.selected).map((t) => t.index).firstOrNull;
    });
  }

  Future<void> _onAudioTrackChanged(int? index) async {
    final controller = widget.controller;
    if (controller == null || index == null) return;
    await controller.selectAudioTrack(index);
    if (!mounted) return;
    setState(() => _selectedAudioTrackIndex = index);
    await _loadAudioTracks();
  }

  Future<void> _loadFilters() async {
    final gsy = widget.controller;
    if (gsy is! GSYVideoControllerImpl) return;
    final names = await gsy.gsyListEffectFilters();
    if (!mounted || names.isEmpty) return;
    setState(() {
      _filters = names;
      if (!_filters.contains(_selectedFilter)) {
        _selectedFilter = _filters.contains('sepia') ? 'sepia' : _filters.first;
      }
    });
  }

  Future<void> _onFilterChanged(String? value) async {
    if (value == null) return;
    final gsy = widget.controller;
    if (gsy is! GSYVideoControllerImpl) return;
    setState(() => _selectedFilter = value);
    if (value == 'none') {
      await gsy.gsySetEffectFilter('none');
      await gsy.gsySetRenderType(GsyRenderType.texture);
    } else {
      await gsy.gsySetRenderType(GsyRenderType.glSurface);
      await gsy.gsySetEffectFilter(value);
    }
  }

  Future<void> _loadWebVttSubtitles(GSYVideoControllerImpl gsy) async {
    final uri = _subtitleVttUri ?? await _DemoMedia.prepareSubtitleVttUri();
    if (!mounted) return;
    setState(() => _subtitleVttUri = uri);
    await gsy.gsySetSubtitleUrl(uri, mimeType: 'text/vtt');
    await gsy.gsySetSubtitleEnabled(enabled: true);
    if (mounted) setState(() => _subtitlesEnabled = true);
  }

  Future<void> _sendEmbeddedSubtitle(GSYVideoControllerImpl gsy) async {
    final text = _subtitleTextController.text.trim();
    if (text.isEmpty) {
      await gsy.gsySetEmbeddedSubtitleText(null);
    } else {
      await gsy.gsySetEmbeddedSubtitleText(text);
    }
    await gsy.gsySetSubtitleEnabled(enabled: true);
    if (mounted) setState(() => _subtitlesEnabled = true);
  }

  Future<void> _clearSubtitles(GSYVideoControllerImpl gsy) async {
    await gsy.gsySetEmbeddedSubtitleText(null);
    await gsy.gsySetSubtitleEnabled(enabled: false);
    if (mounted) setState(() => _subtitlesEnabled = false);
  }

  Future<void> _toggleSubtitles(GSYVideoControllerImpl gsy) async {
    final enabled = !_subtitlesEnabled;
    await gsy.gsySetSubtitleEnabled(enabled: enabled);
    if (mounted) setState(() => _subtitlesEnabled = enabled);
  }

  Future<void> _reloadDanmakuFile(GSYVideoControllerImpl gsy) async {
    final uri = await _DemoMedia.prepareDanmakuXmlUri(extra: _customDanmaku);
    if (!mounted) return;
    setState(() => _danmakuXmlUri = uri);
    await gsy.gsySetDanmakuUrl(uri);
    if (_danmakuVisible) {
      await gsy.gsyToggleDanmaku(enabled: true);
    }
  }

  Future<void> _loadDemoDanmaku(GSYVideoControllerImpl gsy) async {
    await _reloadDanmakuFile(gsy);
    await gsy.gsyToggleDanmaku(enabled: true);
    if (mounted) setState(() => _danmakuVisible = true);
  }

  Future<void> _sendDanmaku(GSYVideoControllerImpl gsy) async {
    final text = _danmakuTextController.text.trim();
    if (text.isEmpty) return;
    final timeSec = gsy.position.value.inMilliseconds / 1000.0;
    setState(() {
      _customDanmaku.add(_DanmakuCue(timeSec, text));
    });
    await _reloadDanmakuFile(gsy);
    await gsy.gsyToggleDanmaku(enabled: true);
    if (mounted) setState(() => _danmakuVisible = true);
  }

  Future<void> _toggleDanmaku(GSYVideoControllerImpl gsy) async {
    final visible = !_danmakuVisible;
    await gsy.gsyToggleDanmaku(enabled: visible);
    if (mounted) setState(() => _danmakuVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller;
    final isAndroidGsy = active is GSYVideoControllerImpl;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<CommonPlayerState>(
            valueListenable: active?.playerState ?? _idleState,
            builder: (_, state, _) => Text('State: $state'),
          ),
          ValueListenableBuilder<Duration>(
            valueListenable: active?.position ?? _zeroDuration,
            builder: (_, position, _) {
              final duration = active?.duration.value ?? Duration.zero;
              return Text('${_format(position)} / ${_format(duration)}');
            },
          ),
          if (active != null) ...[
            const SizedBox(height: 12),
            const Text(
              '设置',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('音轨：'),
                const SizedBox(width: 8),
                Expanded(
                  child: _audioTracks.isEmpty
                      ? Text(
                          '暂无可用音轨',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedAudioTrackIndex,
                          items: [
                            for (final track in _audioTracks)
                              DropdownMenuItem(
                                value: track.index,
                                child: Text(
                                  track.language == null
                                      ? track.label
                                      : '${track.label} (${track.language})',
                                ),
                              ),
                          ],
                          onChanged: _onAudioTrackChanged,
                        ),
                ),
                IconButton(
                  tooltip: '刷新音轨',
                  onPressed: _loadAudioTracks,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '音轨请在设置中选择；播放器内齿轮按钮也可切换原生音轨。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (isAndroidGsy) ...[
            const SizedBox(height: 8),
            const Text(
              '播放中点击画面可唤出暂停按钮；GL 滤镜需从下拉框手动开启。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('GL 滤镜：'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _filters.contains(_selectedFilter)
                        ? _selectedFilter
                        : _filters.first,
                    items: [
                      for (final name in _filters)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: _onFilterChanged,
                  ),
                ),
              ],
            ),
          ],
          if (isAndroidGsy) ...[
            const SizedBox(height: 12),
            const Text(
              '字幕',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _subtitleTextController,
              decoration: const InputDecoration(
                labelText: '推送字幕文本',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _subtitleVttUri == null
                      ? null
                      : () => _loadWebVttSubtitles(active),
                  child: const Text('加载 WebVTT'),
                ),
                FilledButton.tonal(
                  onPressed: () => _sendEmbeddedSubtitle(active),
                  child: const Text('发送字幕'),
                ),
                FilledButton.tonal(
                  onPressed: () => _clearSubtitles(active),
                  child: const Text('清除字幕'),
                ),
                FilledButton.tonal(
                  onPressed: () => _toggleSubtitles(active),
                  child: Text(_subtitlesEnabled ? '关闭显示' : '开启显示'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '「加载 WebVTT」使用外挂轨道；「发送字幕」通过 gsySetEmbeddedSubtitleText 即时显示。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Text(
              '弹幕',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _danmakuTextController,
              decoration: const InputDecoration(
                labelText: '弹幕内容',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _danmakuXmlUri == null
                      ? null
                      : () => _loadDemoDanmaku(active),
                  child: const Text('加载弹幕'),
                ),
                FilledButton.tonal(
                  onPressed: () => _sendDanmaku(active),
                  child: const Text('发送弹幕'),
                ),
                FilledButton.tonal(
                  onPressed: () => _toggleDanmaku(active),
                  child: Text(_danmakuVisible ? '隐藏弹幕' : '显示弹幕'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '「加载弹幕」使用 B 站 XML 本地文件；「发送弹幕」在当前播放时间点追加一条并重新加载。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '循环 / 截图',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: active == null
                    ? null
                    : () async {
                        final next = !_loopingEnabled;
                        await active.setLooping(next);
                        if (!mounted) return;
                        setState(() => _loopingEnabled = next);
                      },
                child: Text(_loopingEnabled ? '循环: 开' : '循环: 关'),
              ),
              FilledButton.tonal(
                onPressed: active == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final path = await active.captureFrame(
                          highQuality: true,
                          includeOverlay: isAndroidGsy,
                        );
                        if (!mounted) return;
                        setState(() => _lastCapturePath = path);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              path == null ? '截图失败' : '已保存: $path',
                            ),
                          ),
                        );
                      },
                child: const Text('截图 captureFrame'),
              ),
            ],
          ),
          if (_lastCapturePath != null) ...[
            const SizedBox(height: 4),
            Text(
              '最近截图: $_lastCapturePath',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            isAndroidGsy
                ? '循环走 GSY 原生 isLooping；截图可用 includeOverlay 包含控制栏。'
                : '循环在 iOS 播放结束时自动 seek(0)+play；截图保存到临时目录 PNG。',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: active == null ? null : () => active.play(),
                child: const Text('Play'),
              ),
              FilledButton(
                onPressed: active == null ? null : () => active.pause(),
                child: const Text('Pause'),
              ),
              FilledButton(
                onPressed: active == null
                    ? null
                    : () => active.seekTo(const Duration(seconds: 10)),
                child: const Text('Seek 10s'),
              ),
              if (isAndroidGsy)
                FilledButton(
                  onPressed: () => active.gsyStartFullscreen(),
                  child: const Text('GSY Fullscreen'),
                ),
              if (active is SGVideoControllerImpl) ...[
                FilledButton(
                  onPressed: () => active.sgStartFullscreen(),
                  child: const Text('SG Fullscreen'),
                ),
                FilledButton(
                  onPressed: () => active.sgSetVRMode(enabled: true),
                  child: const Text('SG VR'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
