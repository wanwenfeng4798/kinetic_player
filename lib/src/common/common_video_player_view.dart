import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common_video_controller.dart';
import 'common_video_player_factory.dart';
import 'platform_guard.dart';
import 'player_view_types.dart';

/// Unified player surface: Android → GSY, iOS → SGPlayer master.
class CommonVideoPlayerView extends StatefulWidget {
  const CommonVideoPlayerView({
    super.key,
    this.url,
    this.creationParams,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
    this.onPlatformViewCreated,
  });

  final String? url;
  final Map<String, dynamic>? creationParams;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final ValueChanged<int>? onPlatformViewCreated;

  @override
  State<CommonVideoPlayerView> createState() => _CommonVideoPlayerViewState();
}

class _CommonVideoPlayerViewState extends State<CommonVideoPlayerView> {
  Map<String, dynamic> get _creationParams => <String, dynamic>{
        if (widget.url != null) 'url': widget.url,
        ...?widget.creationParams,
      };

  @override
  Widget build(BuildContext context) {
    assertSupportedMobilePlatform();

    final creationParams = _creationParams;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: PlayerViewTypes.sg,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: widget.gestureRecognizers,
        onPlatformViewCreated: widget.onPlatformViewCreated,
      );
    }

    return AndroidView(
      viewType: PlayerViewTypes.gsy,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams.isEmpty ? null : creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: widget.gestureRecognizers,
      onPlatformViewCreated: widget.onPlatformViewCreated,
    );
  }
}

typedef CommonVideoPlayerViewCreatedCallback = void Function(
  CommonVideoController controller,
);

/// Wires [CommonVideoPlayerFactory.createAuto] to platform view lifecycle.
class CommonVideoPlayerViewBuilder extends StatefulWidget {
  const CommonVideoPlayerViewBuilder({
    super.key,
    required this.builder,
    this.url,
    this.creationParams,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  final CommonVideoPlayerViewCreatedCallback builder;
  final String? url;
  final Map<String, dynamic>? creationParams;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<CommonVideoPlayerViewBuilder> createState() =>
      _CommonVideoPlayerViewBuilderState();
}

class _CommonVideoPlayerViewBuilderState
    extends State<CommonVideoPlayerViewBuilder> {
  CommonVideoController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonVideoPlayerView(
      url: widget.url,
      creationParams: widget.creationParams,
      gestureRecognizers: widget.gestureRecognizers,
      onPlatformViewCreated: _handleCreated,
    );
  }

  void _handleCreated(int viewId) {
    if (_controller != null) return;
    final controller = CommonVideoPlayerFactory.createAuto(viewId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _controller = controller);
      widget.builder(controller);
    });
  }
}
