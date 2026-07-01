import 'package:flutter/material.dart';

import '../common/common_video_controller.dart';
import '../common/common_video_player_view.dart';

/// Coordinates which cell in a scrollable list should be playing.
class GsyAutoPlayCoordinator extends ChangeNotifier {
  int? activeIndex;

  void activate(int index) {
    if (activeIndex == index) return;
    activeIndex = index;
    notifyListeners();
  }

  void deactivate(int index) {
    if (activeIndex != index) return;
    activeIndex = null;
    notifyListeners();
  }
}

/// List item that auto-plays when mostly visible (GSY list auto-play pattern).
class GsyAutoPlayVideoCell extends StatefulWidget {
  const GsyAutoPlayVideoCell({
    super.key,
    required this.index,
    required this.coordinator,
    required this.url,
    this.creationParams,
    this.aspectRatio = 16 / 9,
  });

  final int index;
  final GsyAutoPlayCoordinator coordinator;
  final String url;
  final Map<String, dynamic>? creationParams;
  final double aspectRatio;

  @override
  State<GsyAutoPlayVideoCell> createState() => _GsyAutoPlayVideoCellState();
}

class _GsyAutoPlayVideoCellState extends State<GsyAutoPlayVideoCell> {
  CommonVideoController? _controller;
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_onCoordinatorChanged);
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onCoordinatorChanged);
    super.dispose();
  }

  void _onCoordinatorChanged() {
    final active = widget.coordinator.activeIndex == widget.index;
    final controller = _controller;
    if (controller == null) return;
    if (active) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  bool _isMostlyVisible() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final offset = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final top = offset.dy;
    final bottom = top + box.size.height;
    final visibleTop = top.clamp(0.0, screenHeight);
    final visibleBottom = bottom.clamp(0.0, screenHeight);
    final visible = (visibleBottom - visibleTop).clamp(0.0, box.size.height);
    return visible >= box.size.height * 0.6;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_isMostlyVisible()) {
            widget.coordinator.activate(widget.index);
          } else if (widget.coordinator.activeIndex == widget.index) {
            widget.coordinator.deactivate(widget.index);
          }
        });
        return false;
      },
      child: KeyedSubtree(
        key: _key,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: CommonVideoPlayerViewBuilder(
            url: widget.url,
            creationParams: widget.creationParams,
            builder: (controller) {
              if (!identical(_controller, controller)) {
                setState(() => _controller = controller);
                if (widget.coordinator.activeIndex == widget.index) {
                  controller.play();
                }
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Vertical feed list with scroll-based auto play (Android GSY).
class GsyAutoPlayVideoList extends StatelessWidget {
  const GsyAutoPlayVideoList({
    super.key,
    required this.urls,
    this.coordinator,
    this.creationParamsForIndex,
  });

  final List<String> urls;
  final GsyAutoPlayCoordinator? coordinator;
  final Map<String, dynamic>? Function(int index)? creationParamsForIndex;

  @override
  Widget build(BuildContext context) {
    final c = coordinator ?? GsyAutoPlayCoordinator();
    return ListView.builder(
      itemCount: urls.length,
      itemBuilder: (context, index) {
        return GsyAutoPlayVideoCell(
          index: index,
          coordinator: c,
          url: urls[index],
          creationParams: creationParamsForIndex?.call(index),
        );
      },
    );
  }
}

/// Keeps the same [playTag] when navigating to a detail page for seamless playback.
Map<String, dynamic> gsySeamlessHandoffParams({
  required int viewId,
  String? url,
  Map<String, dynamic>? extra,
}) {
  return {
    'url': url,
    'playTag': 'kinetic_$viewId',
    ...?extra,
  };
}
