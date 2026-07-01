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
      'https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4';

  /// Writes a WebVTT track with public thumbnail URLs for seek preview.
  static Future<String> preparePreviewVttUri() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kinetic_demo_preview.vtt');
    if (!await file.exists()) {
      await file.writeAsString(_buildPreviewVtt());
    }
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
      buffer.writeln('https://picsum.photos/id/${1010 + i}/284/160');
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
}

class PlayerDemoPage extends StatefulWidget {
  const PlayerDemoPage({super.key});

  @override
  State<PlayerDemoPage> createState() => _PlayerDemoPageState();
}

class _PlayerDemoPageState extends State<PlayerDemoPage> {
  String? _previewVttUri;
  CommonVideoController? _controller;
  bool _gsyFeaturesApplied = false;

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

  Future<void> _applyGsyDemoFeatures(GSYVideoControllerImpl gsy) async {
    if (_gsyFeaturesApplied) return;
    _gsyFeaturesApplied = true;
    await gsy.gsySetRenderType(GsyRenderType.glSurface);
    await gsy.gsySetEffectFilter('sepia');
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
                      if (controller is GSYVideoControllerImpl) {
                        _applyGsyDemoFeatures(controller);
                      }
                    },
                  ),
                ),
                _ControlPanel(controller: _controller),
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
  String _selectedFilter = 'sepia';

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void didUpdateWidget(covariant _ControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _loadFilters();
    }
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
    await gsy.gsySetRenderType(GsyRenderType.glSurface);
    await gsy.gsySetEffectFilter(value);
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
          if (isAndroidGsy) ...[
            const SizedBox(height: 8),
            const Text(
              '进度条预览：先点视频唤出控制栏，再拖动进度条。',
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
              if (isAndroidGsy) ...[
                FilledButton(
                  onPressed: () => active.gsyStartFullscreen(),
                  child: const Text('GSY Fullscreen'),
                ),
                FilledButton(
                  onPressed: () => active.gsyToggleDanmaku(enabled: true),
                  child: const Text('GSY Danmaku'),
                ),
              ],
              if (active is SGVideoControllerImpl)
                FilledButton(
                  onPressed: () => active.sgSetVRMode(enabled: true),
                  child: const Text('SG VR'),
                ),
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
