import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'mpv_chrome.dart';
import 'mpv_video_controller_impl.dart';
import 'mpv_video_features.dart';

/// Flutter [Texture] host for libmpv. Public widget API stays
/// [CommonVideoPlayerView] / `onPlatformViewCreated`.
class MpvPlayerSurface extends StatefulWidget {
  const MpvPlayerSurface({
    super.key,
    this.url,
    this.creationParams,
    this.onPlatformViewCreated,
  });

  final String? url;
  final Map<String, dynamic>? creationParams;
  final ValueChanged<int>? onPlatformViewCreated;

  @override
  State<MpvPlayerSurface> createState() => _MpvPlayerSurfaceState();
}

class _MpvPlayerSurfaceState extends State<MpvPlayerSurface> {
  static const MethodChannel _plugin = MethodChannel(MpvChannelNames.plugin);

  int? _viewId;
  int? _textureId;
  Object? _error;
  MpvVideoControllerImpl? _controller;
  late final MpvChromeConfig _chromeConfig;

  @override
  void initState() {
    super.initState();
    _chromeConfig = MpvChromeConfig.fromCreationParams({
      if (widget.url != null) 'url': widget.url,
      ...?widget.creationParams,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Map<String, dynamic> get _createArgs => <String, dynamic>{
        if (widget.url != null) 'url': widget.url,
        ...?widget.creationParams,
      };

  Future<void> _create() async {
    try {
      final result = await _plugin.invokeMethod<Map<Object?, Object?>>(
        'create',
        _createArgs,
      );
      if (!mounted || result == null) return;
      final viewId = result['viewId'] as int;
      final textureId = result['textureId'] as int;
      widget.onPlatformViewCreated?.call(viewId);
      setState(() {
        _viewId = viewId;
        _textureId = textureId;
        _controller = MpvVideoControllerImpl(viewId);
        final locale = _chromeConfig.locale;
        _controller!.chromeLocale.value = locale;
        _controller!.coverUrl.value = _chromeConfig.coverUrl;
        _controller!.videoTitle.value = _chromeConfig.videoTitle;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    final viewId = _viewId;
    _controller?.dispose();
    if (viewId != null) {
      _plugin.invokeMethod<void>('destroy', {'viewId': viewId});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
          child: Text(
            '$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12),
          ),
        ),
      );
    }
    final textureId = _textureId;
    if (textureId == null) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF000000)),
        Texture(textureId: textureId),
        if (_controller != null)
          MpvChromeOverlay(
            controller: _controller!,
            config: _chromeConfig,
          ),
      ],
    );
  }
}
