import 'package:flutter/material.dart';
import 'package:kinetic_player/kinetic_player.dart';

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

class PlayerDemoPage extends StatefulWidget {
  const PlayerDemoPage({super.key});

  @override
  State<PlayerDemoPage> createState() => _PlayerDemoPageState();
}

class _PlayerDemoPageState extends State<PlayerDemoPage> {
  static const _demoUrl =
      'https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4';

  CommonVideoController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kinetic Player Demo')),
      body: Column(
        children: [
          Expanded(
            child: CommonVideoPlayerViewBuilder(
              url: _demoUrl,
              builder: (controller) {
                if (!identical(_controller, controller)) {
                  setState(() => _controller = controller);
                }
              },
            ),
          ),
          _ControlPanel(controller: _controller),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({this.controller});

  final CommonVideoController? controller;

  static final ValueNotifier<CommonPlayerState> _idleState =
      ValueNotifier(CommonPlayerState.idle);
  static final ValueNotifier<Duration> _zeroDuration =
      ValueNotifier(Duration.zero);

  @override
  Widget build(BuildContext context) {
    final active = controller;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
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
          Wrap(
            spacing: 8,
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
              if (active is GSYVideoControllerImpl)
                FilledButton(
                  onPressed: () => active.gsyToggleDanmaku(enabled: true),
                  child: const Text('GSY Danmaku'),
                ),
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
