import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

/// List item that plays only while [coordinator] marks it active.
///
/// Prefer [GsyAutoPlayVideoList], which owns list-level visibility calculation.
class GsyAutoPlayVideoCell extends StatefulWidget {
  const GsyAutoPlayVideoCell({
    super.key,
    required this.index,
    required this.coordinator,
    required this.url,
    this.creationParams,
    this.aspectRatio = 16 / 9,
    this.cover,
  });

  final int index;
  final GsyAutoPlayCoordinator coordinator;
  final String url;
  final Map<String, dynamic>? creationParams;
  final double aspectRatio;
  final Widget? cover;

  @override
  State<GsyAutoPlayVideoCell> createState() => _GsyAutoPlayVideoCellState();
}

class _GsyAutoPlayVideoCellState extends State<GsyAutoPlayVideoCell> {
  CommonVideoController? _controller;

  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_onCoordinatorChanged);
  }

  @override
  void didUpdateWidget(covariant GsyAutoPlayVideoCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      oldWidget.coordinator.removeListener(_onCoordinatorChanged);
      widget.coordinator.addListener(_onCoordinatorChanged);
    }
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onCoordinatorChanged);
    super.dispose();
  }

  void _onCoordinatorChanged() {
    final active = widget.coordinator.activeIndex == widget.index;
    final controller = _controller;
    if (!active) {
      controller?.pause();
      return;
    }
    controller?.play();
  }

  bool get _active => widget.coordinator.activeIndex == widget.index;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: _active
          ? CommonVideoPlayerViewBuilder(
              url: widget.url,
              creationParams: widget.creationParams,
              builder: (controller) {
                if (!identical(_controller, controller)) {
                  _controller = controller;
                  controller.play();
                }
              },
            )
          : (widget.cover ??
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Icon(Icons.play_circle_outline, color: Colors.white54),
                ),
              )),
    );
  }
}

/// Vertical feed with list-level visibility auto-play (Android GSY pattern).
///
/// Only the cell nearest the play window (default: middle 60% of the viewport)
/// mounts a player; others show [coverBuilder] / placeholder. Not
/// `ListGSYVideoPlayer` playlist playback and not detail-page seamless handoff.
class GsyAutoPlayVideoList extends StatefulWidget {
  const GsyAutoPlayVideoList({
    super.key,
    required this.urls,
    this.coordinator,
    this.creationParamsForIndex,
    this.coverBuilder,
    this.aspectRatio = 16 / 9,
    this.playWindowFraction = 0.6,
  });

  final List<String> urls;
  final GsyAutoPlayCoordinator? coordinator;
  final Map<String, dynamic>? Function(int index)? creationParamsForIndex;
  final Widget Function(BuildContext context, int index)? coverBuilder;
  final double aspectRatio;

  /// Fraction of viewport height that must overlap a cell for it to be eligible.
  final double playWindowFraction;

  @override
  State<GsyAutoPlayVideoList> createState() => _GsyAutoPlayVideoListState();
}

class _GsyAutoPlayVideoListState extends State<GsyAutoPlayVideoList> {
  late final GsyAutoPlayCoordinator _coordinator =
      widget.coordinator ?? GsyAutoPlayCoordinator();
  final Map<int, GlobalKey> _keys = {};

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  void _recomputeActive() {
    if (!mounted) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final windowH = screenHeight * widget.playWindowFraction.clamp(0.2, 1.0);
    final playTop = (screenHeight - windowH) / 2;
    final playBottom = playTop + windowH;

    int? bestIndex;
    var bestOverlap = 0.0;
    for (var i = 0; i < widget.urls.length; i++) {
      final box = _keyFor(i).currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final offset = box.localToGlobal(Offset.zero);
      final top = offset.dy;
      final bottom = top + box.size.height;
      final overlapTop = top < playTop ? playTop : top;
      final overlapBottom = bottom > playBottom ? playBottom : bottom;
      final overlap = (overlapBottom - overlapTop).clamp(0.0, box.size.height);
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        bestIndex = i;
      }
    }

    if (bestIndex == null || bestOverlap <= 0) {
      final current = _coordinator.activeIndex;
      if (current != null) _coordinator.deactivate(current);
      return;
    }
    _coordinator.activate(bestIndex);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification ||
            notification is UserScrollNotification &&
                notification.direction == ScrollDirection.idle) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeActive());
        } else if (notification is ScrollUpdateNotification) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeActive());
        }
        return false;
      },
      child: ListView.builder(
        itemCount: widget.urls.length,
        itemBuilder: (context, index) {
          return KeyedSubtree(
            key: _keyFor(index),
            child: GsyAutoPlayVideoCell(
              index: index,
              coordinator: _coordinator,
              url: widget.urls[index],
              creationParams: widget.creationParamsForIndex?.call(index),
              aspectRatio: widget.aspectRatio,
              cover: widget.coverBuilder?.call(context, index),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeActive());
  }
}
