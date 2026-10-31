import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:kinetic_player/kinetic_player.dart';
import 'package:path_provider/path_provider.dart';

import 'io_shim.dart' if (dart.library.html) 'io_shim_web.dart';

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

class _DemoSource {
  const _DemoSource(this.label, this.url, {this.format = 'MP4'});

  final String label;
  final String url;

  /// Container / protocol tag shown in the source picker.
  final String format;

  String get menuLabel => '[$format] $label';
}

/// Bundled SGPlayer fixtures plus the original network media catalog.
class _DemoMedia {
  static final sources = <_DemoSource>[];
  static List<_DemoSource> get continuousPlaylist => sources
      .where((s) => s.format == 'MP4' && s.label.startsWith('[本地]'))
      .toList(growable: false);
  static List<String> get continuousPlaylistUrls =>
      continuousPlaylist.map((s) => s.url).toList(growable: false);
  static String? coverUrl;
  static List<String> _previewImages = [];

  static Future<String> _assetUrl(String asset) async {
    if (kIsWeb) return Uri.base.resolve('assets/$asset').toString();
    final data = await rootBundle.load(asset);
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/kinetic_sgplayer_${asset.split('/').last}');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return file.uri.toString();
  }

  static Future<void> prepareSources() async {
    final assets = [
      ['[本地] SGPlayer 回归片段', 'integration_test/fixtures/orientation.mp4'],
      ['[本地] SGPlayer 音视频测试', 'assets/sgplayer/transcode-av.mp4'],
      ['[本地] I See Fire', 'assets/sgplayer/i-see-fire.mp4'],
      ['[本地] Google Help VR', 'assets/sgplayer/google-help-vr.mp4'],
    ];
    final prepared = <_DemoSource>[];
    for (final item in assets) {
      prepared.add(
        _DemoSource(item[0], await _assetUrl(item[1]), format: 'MP4'),
      );
    }
    prepared.addAll(<_DemoSource>[
      // Progressive — short clips first (also used as continuous playlist)
      const _DemoSource(
        'Sample 5s',
        'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
        format: 'MP4',
      ),
      const _DemoSource(
        'Flower',
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
        format: 'MP4',
      ),
      const _DemoSource(
        'Flower',
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.webm',
        format: 'WebM',
      ),
      const _DemoSource(
        'XGPlayer Demo 360p',
        'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-360p.mp4',
        format: 'MP4',
      ),
      const _DemoSource(
        'Sintel Trailer',
        'https://media.w3.org/2010/05/sintel/trailer.mp4',
        format: 'MP4',
      ),
      const _DemoSource(
        'Big Buck Bunny',
        'https://cdn.jsdelivr.net/gh/mediaelement/mediaelement-files@master/big_buck_bunny.mp4',
        format: 'MP4',
      ),
      // Adaptive streaming
      const _DemoSource(
        'Apple BipBop fMP4',
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
        format: 'HLS',
      ),
      const _DemoSource(
        'Mux Big Buck Bunny',
        'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        format: 'HLS',
      ),
      const _DemoSource(
        'Tears of Steel VOD',
        'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
        format: 'HLS',
      ),
      const _DemoSource(
        'XGPlayer HLS Demo',
        'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/hls/xgplayer-demo.m3u8',
        format: 'HLS',
      ),
      const _DemoSource(
        'Envivio MultiRate',
        'https://dash.akamaized.net/envivio/EnvivioDash3/manifest.mpd',
        format: 'DASH',
      ),
      const _DemoSource(
        'BBB 30fps MultiRate',
        'https://dash.akamaized.net/akamai/bbb_30fps/bbb_30fps.mpd',
        format: 'DASH',
      ),
      const _DemoSource(
        'Shaka Angel One',
        'https://storage.googleapis.com/shaka-demo-assets/angel-one/dash.mpd',
        format: 'DASH',
      ),
      // Other containers
      const _DemoSource(
        'XGPlayer MPEG-TS 片段',
        'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/hls/segment-0.ts',
        format: 'TS',
      ),
      const _DemoSource(
        'Sintel Trailer Ogg',
        'https://media.w3.org/2010/05/sintel/trailer.ogv',
        format: 'Ogg',
      ),
      const _DemoSource(
        'ExoPlayer 音频',
        'https://storage.googleapis.com/exoplayer-test-media-0/play.mp3',
        format: 'MP3',
      ),
      const _DemoSource(
        'ExoPlayer lavf sample',
        'https://storage.googleapis.com/exoplayer-test-media-1/mkv/android-screens-lavf-56.36.100-aac-avc-main-1280x720.mkv',
        format: 'MKV',
      ),
      const _DemoSource(
        'XGPlayer Demo 360p',
        'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/flv/xgplayer-demo-360p.flv',
        format: 'FLV',
      ),
    ]);
    coverUrl = await _assetUrl('assets/sgplayer/cover.jpg');
    _previewImages = [coverUrl!];
    sources
      ..clear()
      ..addAll(prepared);
  }

  /// Writes a WebVTT track with public thumbnail URLs for seek preview.
  static Future<String> preparePreviewVttUri() async {
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
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
    await dir.create(recursive: true);
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
    _DanmakuCue(8, '支持加载本地 XML 文件'),
    _DanmakuCue(10, 'gsySetDanmakuUrl / gsyToggleDanmaku'),
  ];

  /// Bilibili XML danmaku track for demo playback.
  static Future<String> prepareDanmakuXmlUri({
    List<_DanmakuCue> extra = const [],
  }) async {
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/kinetic_demo_danmaku.xml');
    await file.writeAsString(_buildDanmakuXml([..._demoDanmaku, ...extra]));
    return file.uri.toString();
  }

  static String _buildDanmakuXml(List<_DanmakuCue> cues) {
    final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?><i>');
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

  static String _escapeXml(String text) => text
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
  _DemoSource _selectedSource = const _DemoSource('正在准备 SGPlayer 示例', '');
  bool _mediaReady = false;
  Object? _mediaError;
  String _chromeLocale = 'zh';

  static const _chromeLocaleLabels = <String, String>{
    'zh': '中文',
    'en': 'English',
    'vi': 'Tiếng Việt',
    'ms': 'Bahasa Melayu',
    'id': 'Bahasa Indonesia',
    'fil': 'Filipino',
  };

  @override
  void initState() {
    super.initState();
    _DemoMedia.prepareSources()
        .then((_) async {
          String? preview;
          if (!kIsWeb) {
            preview = await _DemoMedia.preparePreviewVttUri();
          }
          if (mounted) {
            setState(() {
              _selectedSource = _DemoMedia.sources.first;
              _previewVttUri = preview;
              _mediaReady = true;
            });
          }
        })
        .catchError((Object error) {
          if (mounted) setState(() => _mediaError = error);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onChromeLocaleChanged(String locale) async {
    if (locale == _chromeLocale) return;
    try {
      await _controller?.setLocale(locale);
      if (mounted) setState(() => _chromeLocale = locale);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _onSourceChanged(_DemoSource source) async {
    if (source.url == _selectedSource.url) return;
    final controller = _controller;
    setState(() => _selectedSource = source);
    if (controller == null) return;
    final urls = _DemoMedia.continuousPlaylistUrls;
    final index = urls.indexOf(source.url);
    await controller.setPlaylist(
      index >= 0 ? urls : [source.url],
      startIndex: index >= 0 ? index : 0,
      autoPlay: true,
    );
  }

  KineticPlayerConfig _playerConfig() {
    final urls = _DemoMedia.continuousPlaylistUrls;
    final index = urls.indexOf(_selectedSource.url);
    return KineticPlayerConfig(
      url: _selectedSource.url,
      playlist: index >= 0 ? urls : [_selectedSource.url],
      startIndex: index >= 0 ? index : 0,
      autoPlay: false,
      ui: KineticUiConfig(
        enableNativeControls: true,
        lockLand: true,
        autoFullWithSize: false,
        showFullscreenButton: true,
        showVolumeToolbar: true,
        showSettingsButton: true,
        showDragProgressTextOnSeekBar: true,
        pictureInPictureEnabled: true,
        cacheWithPlay: false,
        videoTitle: _selectedSource.label,
        previewVttUrl: _previewVttUri,
        coverUrl: _DemoMedia.coverUrl,
        locale: _chromeLocale,
      ),
      platformOptions: {
        if (kIsWeb)
          'artPlugins': {
            ArtplayerPluginKeys.danmuku: true,
            ArtplayerPluginKeys.documentPip: true,
            ArtplayerPluginKeys.hlsControl: true,
            ArtplayerPluginKeys.dashControl: true,
            if (_previewVttUri != null)
              ArtplayerPluginKeys.vttThumbnail: {'vtt': _previewVttUri},
            ArtplayerPluginKeys.multipleSubtitles: true,
          },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final previewReady = _mediaReady && (!isAndroid || _previewVttUri != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kinetic Player Demo'),
        actions: [
          if (isAndroid)
            IconButton(
              tooltip: '列表自动播放',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _AutoPlayListDemoPage(),
                  ),
                );
              },
              icon: const Icon(Icons.view_list),
            ),
        ],
      ),
      body: _mediaError != null
          ? Center(child: Text('示例资源准备失败：$_mediaError'))
          : previewReady
          ? Column(
              children: [
                Expanded(
                  flex: 3,
                  child: CommonVideoPlayerViewBuilder(
                    config: _playerConfig(),
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
                    child: _ControlPanel(
                      controller: _controller,
                      selectedSource: _selectedSource,
                      chromeLocale: _chromeLocale,
                      onSourceChanged: _onSourceChanged,
                      onChromeLocaleChanged: _onChromeLocaleChanged,
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ControlPanel extends StatefulWidget {
  const _ControlPanel({
    this.controller,
    required this.selectedSource,
    required this.chromeLocale,
    required this.onSourceChanged,
    required this.onChromeLocaleChanged,
  });

  final CommonVideoController? controller;
  final _DemoSource selectedSource;
  final String chromeLocale;
  final Future<void> Function(_DemoSource source) onSourceChanged;
  final Future<void> Function(String locale) onChromeLocaleChanged;

  @override
  State<_ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<_ControlPanel> {
  static const _renderCoreLabels = <GsyRenderCore, String>{
    GsyRenderCore.ijk: 'IJKPlayer',
    GsyRenderCore.exo: 'Media3 (Exo)',
    GsyRenderCore.system: 'System MediaPlayer',
  };

  static final ValueNotifier<CommonPlayerState> _idleState = ValueNotifier(
    CommonPlayerState.idle,
  );
  static final ValueNotifier<Duration> _zeroDuration = ValueNotifier(
    Duration.zero,
  );

  List<String> _filters = const ['none', 'sepia', 'gaussianBlur', 'greyScale'];
  String _selectedFilter = 'none';
  String? _subtitleVttUri;
  String? _danmakuXmlUri;
  bool _watermarkEnabled = false;
  bool _purePlay = false;
  bool _automaticPip = true;
  final _overlayUrlController = TextEditingController();
  bool _gifRecording = false;
  Uint8List? _lastCaptureBytes;
  String? _lastGifPath;
  String? _netSpeedText;
  int _renderRotation = 0;
  bool _keepLastFrame = false;
  bool _coverEnabled = true;
  GsyRenderCore _selectedRenderCore = GsyRenderCore.ijk;
  final TextEditingController _subtitleTextController = TextEditingController(
    text: 'Hello subtitles!',
  );
  final TextEditingController _danmakuTextController = TextEditingController(
    text: 'Hello Danmaku!',
  );

  @override
  void initState() {
    super.initState();
    _bindScreenshotCallback(widget.controller);
    _loadFilters();
    if (!kIsWeb) {
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
    widget.controller?.onScreenshotCaptured = null;
    _overlayUrlController.dispose();
    _subtitleTextController.dispose();
    _danmakuTextController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.onScreenshotCaptured = null;
      _bindScreenshotCallback(widget.controller);
      _renderRotation = 0;
      _keepLastFrame = false;
      _coverEnabled = true;
      _selectedRenderCore = GsyRenderCore.ijk;
      _loadFilters();
    }
  }

  Future<void> _prepareAppleWatermark(SGVideoControllerImpl controller) async {
    final status = await controller.native.effectsStatus();
    if ((status['watermarkCount'] as num? ?? 0) > 0) return;
    await controller.native.setWatermarks([
      {
        'imageURL': _DemoMedia.coverUrl,
        'rect': {'x': 0.65, 'y': 0.08, 'width': 0.3, 'height': 0.12},
        'opacity': 0.85,
      },
    ]);
    await controller.native.configureEffects({'watermarksEnabled': false});
  }

  void _bindScreenshotCallback(CommonVideoController? controller) {
    if (controller is SGVideoControllerImpl) _prepareAppleWatermark(controller);
    controller?.onScreenshotCaptured = (bytes) {
      if (!mounted) return;
      setState(() => _lastCaptureBytes = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bytes == null ? '截图失败' : '截图完成 ${bytes.length} 字节'),
        ),
      );
    };
  }

  Future<void> _onDemoSourceChanged(String? url) async {
    if (url == null || url == widget.selectedSource.url) return;
    final source = _DemoMedia.sources.firstWhere((s) => s.url == url);
    await widget.onSourceChanged(source);
  }

  Future<void> _enterDemoVr(
    SGVideoControllerImpl controller,
    SgDisplayMode mode,
  ) async {
    // A flat clip projected onto a sphere only looks zoomed. Use the bundled
    // 360-degree scene so the demo actually exercises looking around.
    final panorama = _DemoMedia.sources.firstWhere(
      (source) => source.label == '[本地] Google Help VR',
    );
    await widget.onSourceChanged(panorama);
    await controller.sgSetDisplayMode(mode);
  }

  Future<void> _onRenderCoreChanged(GsyRenderCore? core) async {
    if (core == null || core == _selectedRenderCore) return;
    final gsy = widget.controller;
    if (gsy is! GSYVideoControllerImpl) return;

    final wasPlaying = gsy.playerState.value == CommonPlayerState.playing;
    final pos = gsy.position.value;

    await gsy.gsySwitchRenderCore(core);
    await gsy.switchVideoSource(
      widget.selectedSource.url,
      autoPlay: wasPlaying,
    );
    if (pos > Duration.zero) {
      await gsy.seekTo(pos);
    }

    if (!mounted) return;
    setState(() => _selectedRenderCore = core);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已切换至 ${_renderCoreLabels[core]}，视频已重新加载')),
    );
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

  Future<void> _loadOverlaySource(
    CommonVideoController player, {
    required bool danmaku,
    bool preview = false,
  }) async {
    final input = _overlayUrlController;
    input.clear();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          preview
              ? '加载预览 WebVTT'
              : danmaku
              ? '加载弹幕 XML'
              : '加载字幕',
        ),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: '网络 URL 或本地文件路径'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('加载'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    final source = Uri.tryParse(url)?.hasScheme == true
        ? url
        : Uri.file(url).toString();
    try {
      if (preview && player is SGVideoControllerImpl) {
        await player.native.loadTimelineSprites(source);
      } else if (preview && player is GSYVideoControllerImpl) {
        await player.gsySetPreviewVttUrl(source);
      } else if (danmaku && player is SGVideoControllerImpl) {
        await player.native.loadDanmakuXml(source);
      } else if (danmaku && player is GSYVideoControllerImpl) {
        await player.gsySetDanmakuUrl(source);
        await player.gsyToggleDanmaku(enabled: true);
      } else {
        await player.setSubtitleSource(source);
        await player.setSubtitlesEnabled(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败：$error')));
      }
    }
  }

  Future<void> _loadWebVttSubtitles(CommonVideoController gsy) async {
    final uri = _subtitleVttUri ?? await _DemoMedia.prepareSubtitleVttUri();
    if (!mounted) return;
    setState(() => _subtitleVttUri = uri);
    await gsy.setSubtitleSource(uri, mimeType: 'text/vtt');
    await gsy.setSubtitlesEnabled(true);
  }

  Future<void> _sendEmbeddedSubtitle(CommonVideoController gsy) async {
    final text = _subtitleTextController.text.trim();
    if (gsy is SGVideoControllerImpl) {
      await gsy.native.setSubtitleCues(
        text.isEmpty
            ? []
            : [
                {
                  'startMs': gsy.position.value.inMilliseconds,
                  'durationMs': 5000,
                  'text': text,
                },
              ],
      );
      await gsy.setSubtitlesEnabled(text.isNotEmpty);
      return;
    }
    if (gsy is! GSYVideoControllerImpl) return;
    if (text.isEmpty) {
      await gsy.gsySetEmbeddedSubtitleText(null);
    } else {
      await gsy.gsySetEmbeddedSubtitleText(text);
    }
    await gsy.gsySetSubtitleEnabled(enabled: true);
  }

  Future<void> _clearSubtitles(CommonVideoController gsy) async {
    if (gsy is SGVideoControllerImpl) {
      await gsy.native.setSubtitleCues([]);
      await gsy.setSubtitlesEnabled(false);
      return;
    }
    if (gsy is! GSYVideoControllerImpl) return;
    await gsy.gsySetEmbeddedSubtitleText(null);
    await gsy.gsySetSubtitleEnabled(enabled: false);
  }

  Future<void> _loadDemoDanmaku(CommonVideoController gsy) async {
    final uri = await _DemoMedia.prepareDanmakuXmlUri();
    if (!mounted) return;
    setState(() => _danmakuXmlUri = uri);
    if (gsy is SGVideoControllerImpl) {
      await gsy.native.loadDanmakuXml(uri);
      return;
    }
    if (gsy is GSYVideoControllerImpl) {
      await gsy.gsySetDanmakuUrl(uri);
      await gsy.gsyToggleDanmaku(enabled: true);
    }
  }

  Future<void> _toggleWatermark(CommonVideoController gsy) async {
    final status = gsy is SGVideoControllerImpl
        ? await gsy.native.effectsStatus()
        : null;
    final next = status == null
        ? !_watermarkEnabled
        : !(status['watermarksEnabled'] == true &&
              (status['watermarkCount'] as num? ?? 0) > 0);
    if (gsy is SGVideoControllerImpl) {
      if ((status?['watermarkCount'] as num? ?? 0) == 0) {
        await _prepareAppleWatermark(gsy);
      }
      await gsy.native.configureEffects({'watermarksEnabled': next});
    } else if (gsy is GSYVideoControllerImpl) {
      await gsy.gsySetWatermarkUrl(next ? _DemoMedia.coverUrl : null);
    }
    if (mounted) setState(() => _watermarkEnabled = next);
  }

  Future<void> _togglePurePlay(CommonVideoController gsy) async {
    final next = gsy is SGVideoControllerImpl
        ? ((await gsy.native.call<Map>('controls.status'))?['enabled'] == true)
        : !_purePlay;
    if (gsy is SGVideoControllerImpl) {
      await gsy.native.configureControls(enabled: !next);
    } else if (gsy is GSYVideoControllerImpl) {
      await gsy.gsySetPurePlayMode(enabled: next);
    }
    if (mounted) setState(() => _purePlay = next);
  }

  Future<void> _playPreRollAd(CommonVideoController gsy) async {
    final messenger = ScaffoldMessenger.of(context);
    if (gsy is SGVideoControllerImpl) {
      final ok = await gsy.native.playAdvertisement(
        _DemoMedia.sources[1].url,
        fromBeginning: true,
      );
      if (!ok) return;
    } else if (gsy is GSYVideoControllerImpl) {
      await gsy.gsyPlayWithPreRollAd(
        adUrl: _DemoMedia.sources[1].url,
        contentUrl: widget.selectedSource.url,
        skipAfter: const Duration(seconds: 3),
      );
    }
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('片头广告：约 3 秒后可跳过')));
  }

  Future<void> _armMidRollAds(CommonVideoController gsy) async {
    if (gsy is SGVideoControllerImpl) {
      await gsy.native.scheduleAdvertisements([
        {
          'positionMs': 8000,
          'url': _DemoMedia.sources[1].url,
          'skipAfterMs': 3000,
        },
      ]);
    } else if (gsy is GSYVideoControllerImpl) {
      await gsy.gsySetMidRollAds([
        {
          'positionMs': 8000,
          'adUrl': _DemoMedia.sources[1].url,
          'contentUrl': widget.selectedSource.url,
        },
      ]);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已设置中插：约 8s 触发广告')));
  }

  Future<void> _toggleGif(GSYVideoControllerImpl gsy) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_gifRecording) {
      final path = await gsy.gsyStopGifRecording();
      if (!mounted) return;
      setState(() {
        _gifRecording = false;
        _lastGifPath = path;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(path == null ? 'GIF 失败' : 'GIF: $path')),
      );
    } else {
      await gsy.gsyStartGifRecording();
      if (!mounted) return;
      setState(() => _gifRecording = true);
      messenger.showSnackBar(const SnackBar(content: Text('正在录制 GIF…')));
    }
  }

  Future<void> _refreshNetSpeed(GSYVideoControllerImpl gsy) async {
    final speed = await gsy.gsyGetNetSpeed();
    if (!mounted) return;
    setState(
      () => _netSpeedText = '${speed.text} (${speed.bytesPerSecond} B/s)',
    );
  }

  Future<void> _rotateBy(int deltaDegrees) async {
    final next = (_renderRotation + deltaDegrees) % 360;
    final normalized = next < 0 ? next + 360 : next;
    final controller = widget.controller;
    if (controller == null || !controller.supportsRenderTransform) return;
    await controller.setRenderRotation(normalized);
    if (mounted) setState(() => _renderRotation = normalized);
  }

  Future<void> _toggleKeepLastFrame() async {
    final controller = widget.controller;
    final next = controller is SGVideoControllerImpl
        ? ((await controller.native.call<Map>(
                'controls.status',
              ))?['keepLastFrameWhenComplete'] !=
              true)
        : !_keepLastFrame;
    if (controller is GSYVideoControllerImpl) {
      await controller.gsySetKeepLastFrameWhenComplete(enabled: next);
    } else if (controller is SGVideoControllerImpl) {
      await controller.sgSetKeepLastFrameWhenComplete(enabled: next);
    } else if (controller is MpvVideoControllerImpl) {
      await controller.mpvSetKeepLastFrameWhenComplete(enabled: next);
    } else {
      return;
    }
    if (mounted) setState(() => _keepLastFrame = next);
  }

  Future<void> _toggleCover() async {
    final controller = widget.controller;
    final next = controller is SGVideoControllerImpl
        ? ((await controller.native.call<Map>(
                'controls.status',
              ))?['coverEnabled'] !=
              true)
        : !_coverEnabled;
    final url = next ? _DemoMedia.coverUrl : null;
    if (controller == null) return;
    await controller.setCoverUrl(url);
    if (mounted) setState(() => _coverEnabled = next);
  }

  Future<void> _toggleDesktopWatermark(MpvVideoControllerImpl mpv) async {
    final next = !_watermarkEnabled;
    await mpv.mpvSetWatermarkUrl(next ? _DemoMedia.coverUrl : null);
    if (mounted) setState(() => _watermarkEnabled = next);
  }

  Future<void> _toggleDesktopPurePlay(MpvVideoControllerImpl mpv) async {
    final next = !_purePlay;
    await mpv.mpvSetPurePlayMode(enabled: next);
    if (mounted) setState(() => _purePlay = next);
  }

  Future<void> _refreshMpvNetSpeed(MpvVideoControllerImpl mpv) async {
    final speed = await mpv.mpvGetNetSpeed();
    if (!mounted) return;
    setState(
      () => _netSpeedText = '${speed.text} (${speed.bytesPerSecond} B/s)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller;
    final isAndroidGsy = active is GSYVideoControllerImpl;
    final isAppleSg = active is SGVideoControllerImpl;
    final isWebArt = active is ArtplayerVideoControllerImpl;
    final isDesktopMpv = active is MpvVideoControllerImpl;
    final supportsTransform = isAndroidGsy || isAppleSg || isDesktopMpv;
    final supportsCover = isAndroidGsy || isAppleSg || isDesktopMpv;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<CommonPlayerState>(
            valueListenable: active?.playerState ?? _idleState,
            builder: (_, state, widget) => Text('State: $state'),
          ),
          ValueListenableBuilder<Duration>(
            valueListenable: active?.position ?? _zeroDuration,
            builder: (_, position, _) {
              final duration = active?.duration.value ?? Duration.zero;
              if (active is! SGVideoControllerImpl) {
                return Text('${_format(position)} / ${_format(duration)}');
              }
              return ValueListenableBuilder<Duration>(
                valueListenable: active.buffered,
                builder: (_, buffered, _) => Text(
                  '${_format(position)} / ${_format(duration)}  缓冲 ${_format(buffered)}',
                ),
              );
            },
          ),
          if (active is SGVideoControllerImpl) ...[
            ValueListenableBuilder<String?>(
              valueListenable: active.playerError,
              builder: (_, err, _) {
                if (err == null || err.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ],
          if (active != null) ...[
            const SizedBox(height: 12),
            const Text('设置', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('片源：'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: widget.selectedSource.url,
                    items: [
                      for (final source in _DemoMedia.sources)
                        DropdownMenuItem(
                          value: source.url,
                          child: Text(
                            source.menuLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _onDemoSourceChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('语言：'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: widget.chromeLocale,
                    items: [
                      for (final entry
                          in _PlayerDemoPageState._chromeLocaleLabels.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        widget.onChromeLocaleChanged(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.selectedSource.url,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              '倍速 / 音量 / 循环 / 音轨 / 清晰度请用播放器原生底栏与设置面板。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (isAndroidGsy) ...[
            const SizedBox(height: 8),
            const Text('播放内核', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('内核：'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<GsyRenderCore>(
                    isExpanded: true,
                    value: _selectedRenderCore,
                    items: [
                      for (final core in GsyRenderCore.values)
                        DropdownMenuItem(
                          value: core,
                          child: Text(_renderCoreLabels[core]!),
                        ),
                    ],
                    onChanged: _onRenderCoreChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '切换后会重新加载当前视频；IJK 内核下可配合 ijkEnableAccurateSeek 减轻拖动回弹。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              '播放中点击画面可唤出暂停按钮；GL 滤镜需从下拉框手动开启。'
              '播放时按 Home 或切到后台会自动进入画中画（API 26+）。',
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
          if (isAndroidGsy || isAppleSg) ...[
            const SizedBox(height: 12),
            const Text('字幕', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  onPressed: () => _loadOverlaySource(active!, danmaku: false),
                  child: const Text('加载字幕文件 / URL'),
                ),
                FilledButton.tonal(
                  onPressed: () => _loadOverlaySource(
                    active!,
                    danmaku: false,
                    preview: true,
                  ),
                  child: const Text('加载预览 WebVTT'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    if (active is SGVideoControllerImpl) {
                      await active.native.loadTimelineSprites(null);
                    } else if (active is GSYVideoControllerImpl) {
                      await active.gsySetPreviewVttUrl(null);
                    }
                  },
                  child: const Text('关闭预览'),
                ),

                FilledButton.tonal(
                  onPressed: _subtitleVttUri == null
                      ? null
                      : () => _loadWebVttSubtitles(active!),
                  child: const Text('加载 WebVTT'),
                ),
                FilledButton.tonal(
                  onPressed: () => _sendEmbeddedSubtitle(active!),
                  child: const Text('推送字幕文本'),
                ),
                FilledButton.tonal(
                  onPressed: () => _clearSubtitles(active!),
                  child: const Text('清除字幕'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '在原生设置中选择字幕轨；支持加载 WebVTT 和推送临时字幕。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Text('弹幕', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _loadOverlaySource(active!, danmaku: true),
                  child: const Text('加载弹幕文件 / URL'),
                ),
                FilledButton.tonal(
                  onPressed: _danmakuXmlUri == null
                      ? null
                      : () => _loadDemoDanmaku(active!),
                  child: const Text('加载弹幕 XML'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '开关 / 发送弹幕请用底栏弹幕图标与输入框。此处仅演示加载 B 站 XML。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (isAndroidGsy || isAppleSg) ...[
            const SizedBox(height: 12),
            const Text('播放显示', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _toggleWatermark(active!),
                  child: Text(_watermarkEnabled ? '水印: 开' : '水印: 关'),
                ),
                FilledButton.tonal(
                  onPressed: () => _togglePurePlay(active!),
                  child: Text(_purePlay ? '纯播放: 开' : '纯播放: 关'),
                ),
              ],
            ),
          ],
          if (isAndroidGsy || isAppleSg) ...[
            const SizedBox(height: 12),
            const Text('广告', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _playPreRollAd(active!),
                  child: const Text('片头广告'),
                ),
                FilledButton.tonal(
                  onPressed: () => _armMidRollAds(active!),
                  child: const Text('设置中插(8s)'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    if (active is SGVideoControllerImpl) {
                      final ok = await active.native.skipAdvertisement();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('尚未达到可跳过时间，或当前没有广告')),
                        );
                      }
                    } else if (active is GSYVideoControllerImpl) {
                      await active.gsySkipAd();
                    }
                  },
                  child: const Text('跳过广告'),
                ),
              ],
            ),
          ],
          if (active is SGVideoControllerImpl) ...[
            const SizedBox(height: 12),
            const Text(
              '窗口 / 画中画',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => active.native.showFloating(),
                  child: const Text('悬浮播放'),
                ),
                FilledButton.tonal(
                  onPressed: () => active.native.restorePresentation(),
                  child: const Text('恢复播放窗口'),
                ),
                FilledButton.tonal(
                  onPressed: () => active.startPictureInPicture(),
                  child: const Text('画中画'),
                ),
                FilledButton.tonal(
                  onPressed: () => active.stopPictureInPicture(),
                  child: const Text('退出画中画'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final current = await active.native.call<Map>(
                      'controls.status',
                    );
                    final next =
                        current?['automaticPictureInPictureEnabled'] != true;
                    await active.native.configureControls(
                      automaticPictureInPictureEnabled: next,
                    );
                    if (mounted) setState(() => _automaticPip = next);
                  },
                  child: Text(_automaticPip ? '后台画中画: 开' : '后台画中画: 关'),
                ),
              ],
            ),
          ],
          if (isAndroidGsy) ...[
            const SizedBox(height: 12),
            const Text(
              '广告 / GIF / 其它',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _toggleGif(active),
                  child: Text(_gifRecording ? '停止 GIF' : '开始 GIF'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final ok = await active.gsyEnterPictureInPicture();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '已请求 PiP' : 'PiP 不可用')),
                    );
                  },
                  child: const Text('手动 PiP'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final ok = await active.gsyPlayNextInPlaylist();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '已切下一首' : '已是最后一首')),
                    );
                  },
                  child: const Text('播放下一首'),
                ),
                FilledButton.tonal(
                  onPressed: () => _refreshNetSpeed(active),
                  child: const Text('网速'),
                ),
                FilledButton.tonal(
                  onPressed: () => active.gsyReleaseAllVideos(),
                  child: const Text('释放全部'),
                ),
              ],
            ),
            if (_netSpeedText != null) ...[
              const SizedBox(height: 4),
              Text(
                '网速: $_netSpeedText',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (_lastGifPath != null) ...[
              const SizedBox(height: 4),
              Text(
                '最近 GIF: $_lastGifPath',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              '启动已注入短片 playlist；设置→更多→「播完切下一集」可验证连播。'
              '比例 / 镜像 / 循环请用原生设置。右上角可打开列表自动播 Demo。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (isDesktopMpv) ...[
            const SizedBox(height: 12),
            const Text(
              'Windows / Linux · libmpv',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _toggleDesktopWatermark(active),
                  child: Text(_watermarkEnabled ? '水印: 开' : '水印: 关'),
                ),
                FilledButton.tonal(
                  onPressed: () => _toggleDesktopPurePlay(active),
                  child: Text(_purePlay ? '纯播放: 开' : '纯播放: 关'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    await active.mpvSetSubtitleEnabled(
                      enabled: !active.subtitleEnabled.value,
                    );
                    if (mounted) setState(() {});
                  },
                  child: Text(active.subtitleEnabled.value ? '字幕: 开' : '字幕: 关'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final ok = await active.mpvPlayNextInPlaylist();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '已切下一首' : '已是最后一首')),
                    );
                  },
                  child: const Text('播放下一首'),
                ),
                FilledButton.tonal(
                  onPressed: () => _refreshMpvNetSpeed(active),
                  child: const Text('网速'),
                ),
              ],
            ),
            if (_netSpeedText != null) ...[
              const SizedBox(height: 4),
              Text(
                '网速: $_netSpeedText',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              'SGPlayer 随包片段已组成 playlist；设置→更多→「播完切下一集」可验证连播。'
              '弹幕 / 广告 / GIF / PiP / GL 滤镜桌面端不实现。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '公共 · HTTP 标头 / User-Agent',
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
                        await active.setHttpRequestOptions(
                          const KineticHttpRequestOptions(
                            userAgent: 'KineticPlayer-Example/2.1',
                            headers: {'Referer': 'https://example.com/'},
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '已设置 UA + Referer（下次换源生效；Web 仅 HLS/DASH）',
                            ),
                          ),
                        );
                      },
                child: const Text('设置 UA / headers'),
              ),
              FilledButton.tonal(
                onPressed: active == null
                    ? null
                    : () async {
                        await active.setHttpRequestOptions(null);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已清除 HTTP 选项')),
                        );
                      },
                child: const Text('清除 HTTP 选项'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('公共 · 截图', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: active == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final bytes = await active.captureFrame(
                          highQuality: true,
                          includeOverlay: isAndroidGsy,
                        );
                        if (!mounted) return;
                        setState(() => _lastCaptureBytes = bytes);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              bytes == null ? '截图失败' : '截图 ${bytes.length} 字节',
                            ),
                          ),
                        );
                      },
                child: const Text('截图 captureFrame'),
              ),
            ],
          ),
          if (_lastCaptureBytes != null) ...[
            const SizedBox(height: 4),
            Text(
              '最近截图 ${_lastCaptureBytes!.length} 字节',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Image.memory(_lastCaptureBytes!, height: 96, fit: BoxFit.contain),
          ],
          const SizedBox(height: 4),
          Text(
            isAndroidGsy
                ? '截图返回 PNG 字节；设置面板截图走 onScreenshotCaptured，由宿主决定保存位置。倍速/音量/循环请用原生底栏。'
                : isWebArt
                ? 'Web：截图返回 PNG 字节；倍速/音量用 Artplayer 控件。'
                : '截图返回 PNG 字节；设置面板截图走 onScreenshotCaptured。倍速/音量/循环请用原生底栏。',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (isWebArt) ...[
            const SizedBox(height: 12),
            const Text(
              'Web · Artplayer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await active.togglePip();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('PiP: $e')));
                    }
                  },
                  child: const Text('Video PiP'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await active.artToggleDocumentPip();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Document PiP: $e')),
                      );
                    }
                  },
                  child: const Text('Document PiP'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    await active.artEmitDanmuku({
                      'text': _danmakuTextController.text.trim().isEmpty
                          ? 'Hello Web Danmaku'
                          : _danmakuTextController.text.trim(),
                      'time': active.position.value.inSeconds,
                    });
                  },
                  child: const Text('发送弹幕'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final keys = await active.artAvailablePlugins();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('插件: ${keys.join(', ')}')),
                    );
                  },
                  child: const Text('可用插件'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _danmakuTextController,
              decoration: const InputDecoration(
                labelText: 'Web 弹幕内容',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '创建已启用 danmuku / documentPip / hlsControl / dashControl 等插件。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (supportsTransform) ...[
            const SizedBox(height: 12),
            const Text('旋转', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _rotateBy(-90),
                  child: const Text('左转 90°'),
                ),
                FilledButton.tonal(
                  onPressed: () => _rotateBy(90),
                  child: const Text('右转 90°'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final controller = widget.controller;
                    if (controller is GSYVideoControllerImpl) {
                      await controller.gsySetRenderRotation(0);
                    } else if (controller is SGVideoControllerImpl) {
                      await controller.sgSetRenderRotation(0);
                    }
                    if (mounted) setState(() => _renderRotation = 0);
                  },
                  child: const Text('复位 0°'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '当前旋转 $_renderRotation°。镜像请用原生设置面板。'
              '${isAndroidGsy ? '（gsySetRenderRotation）' : '（sgSetRenderRotation）'}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (supportsCover) ...[
            const SizedBox(height: 12),
            const Text(
              '封面 / 最后一帧',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _toggleCover,
                  child: Text(_coverEnabled ? '封面: 开' : '封面: 关'),
                ),
                FilledButton.tonal(
                  onPressed: _toggleKeepLastFrame,
                  child: Text(_keepLastFrame ? '保留最后一帧: 开' : '保留最后一帧: 关'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _keepLastFrame
                  ? '播完停留在最后一帧（不盖封面）。'
                  : '播完显示封面；关闭封面时 Android 清空画面，iOS 显示黑底。',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (active is SGVideoControllerImpl) ...[
            const SizedBox(height: 12),
            const Text(
              'SGPlayer 高级',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => active.sgSetPitch(1.25),
                  child: const Text('音高 1.25'),
                ),
                FilledButton.tonal(
                  onPressed: () => active.sgSetPitch(1.0),
                  child: const Text('音高复位'),
                ),
                FilledButton.tonal(
                  onPressed: () => _enterDemoVr(active, SgDisplayMode.vr),
                  child: const Text('VR'),
                ),
                FilledButton.tonal(
                  onPressed: () => _enterDemoVr(active, SgDisplayMode.vrBox),
                  child: const Text('VRBox'),
                ),
                FilledButton.tonal(
                  onPressed: () => active.sgSetDisplayMode(SgDisplayMode.plane),
                  child: const Text('平面'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    await active.sgSetBackgroundPlaybackPolicy(
                      const SgBackgroundPlaybackPolicy(
                        pausesWhenEnteredBackground: false,
                      ),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '已开启后台继续播（需 Info.plist UIBackgroundModes=audio）',
                        ),
                      ),
                    );
                  },
                  child: const Text('后台继续播'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    await active.sgSetDemuxerOptions(
                      const SgDemuxerOptions(
                        timeout: Duration(seconds: 20),
                        reconnect: true,
                        userAgent: 'KineticPlayer-Example',
                        headers: {'Referer': 'https://example.com/'},
                      ),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已保存解封装参数：影响网络请求和探测，下次打开媒体生效，不改变画面效果。'),
                      ),
                    );
                  },
                  child: const Text('Demuxer：下次打开生效'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final tracks = await active.sgGetVideoTracks();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('视频轨 ${tracks.length} 条')),
                    );
                  },
                  child: const Text('视频轨'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    await active.sgReplaceWithSegments([
                      SgMediaSegment(url: widget.selectedSource.url),
                      SgMediaSegment(url: _DemoMedia.sources[1].url),
                    ]);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已替换为两段资源')));
                  },
                  child: const Text('多段资源'),
                ),
                FilledButton.tonal(
                  onPressed: () => active.sgSetVrViewport(
                    const SgVrViewport(
                      degrees: 100,
                      x: 45,
                      sensorEnable: false,
                    ),
                  ),
                  child: const Text('VR 视口：转向 45°'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final seekable = await active.sgIsSeekable();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('可 seek: $seekable')),
                    );
                  },
                  child: const Text('是否可 Seek'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '缓冲/错误见上方。全景 VR 使用随包 360° 片段；拖动画面转动视角，iPhone 可配合陀螺仪。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
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
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '全屏请用播放器底栏按钮。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
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

/// Android list auto-play demo (visibility-based; not detail seamless).
class _AutoPlayListDemoPage extends StatelessWidget {
  const _AutoPlayListDemoPage();

  @override
  Widget build(BuildContext context) {
    final urls = _DemoMedia.continuousPlaylistUrls;
    return Scaffold(
      appBar: AppBar(title: const Text('列表滑动自动播放')),
      body: GsyAutoPlayVideoList(
        urls: urls,
        aspectRatio: 16 / 9,
        coverBuilder: (context, index) {
          final label = _DemoMedia.continuousPlaylist[index].menuLabel;
          return ColoredBox(
            color: Colors.black,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
