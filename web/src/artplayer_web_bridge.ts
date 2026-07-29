import { KineticArtplayerAdapter } from './artplayer_adapter';
import type { ArtplayerUiConfig, KineticArtplayerConfig } from './types';
import { PlayerState } from './types';

export type BridgeEventHandler = (method: string, args: Record<string, unknown>) => void;

/**
 * JS interop bridge between Flutter MethodChannel and KineticArtplayerAdapter.
 * Exposed on window for Dart `dart:js_interop` / package:web calls.
 */
export class ArtplayerWebBridge {
  private adapter: KineticArtplayerAdapter | null = null;
  private eventHandler: BridgeEventHandler | null = null;

  attach(config: {
    container: HTMLDivElement;
    url?: string;
    ui?: ArtplayerUiConfig;
    artplayerOptions?: Record<string, unknown>;
    webCustomExtensions?: Record<string, unknown>;
    onEvent?: BridgeEventHandler;
  }): void {
    this.dispose();
    this.eventHandler = config.onEvent ?? null;

    const adapterConfig: KineticArtplayerConfig = {
      container: config.container,
      url: config.url,
      ui: config.ui,
      artplayerOptions: config.artplayerOptions,
      webCustomExtensions: config.webCustomExtensions,
      onStateChanged: (state) => {
        this.emit('onPlayerStateChanged', { state });
      },
      onPositionChanged: (position, duration) => {
        this.emit('onPositionChanged', { position, duration });
      },
      onPipChanged: (active) => {
        this.emit('onPipChanged', { active });
      },
      onError: (message) => {
        this.emit('onPlayerStateChanged', { state: PlayerState.error });
        this.emit('onError', { message });
      },
    };

    this.adapter = new KineticArtplayerAdapter(adapterConfig);
  }

  private emit(method: string, args: Record<string, unknown>): void {
    this.eventHandler?.(method, args);
  }

  private requireAdapter(): KineticArtplayerAdapter {
    if (!this.adapter) {
      throw new Error('ArtplayerWebBridge is not attached');
    }
    return this.adapter;
  }

  async handleMethod(method: string, args: Record<string, unknown> = {}): Promise<unknown> {
    const adapter = this.requireAdapter();
    switch (method) {
      case 'play':
        await adapter.play();
        return null;
      case 'pause':
        adapter.pause();
        return null;
      case 'stop':
        adapter.stop();
        return null;
      case 'seekTo':
        await adapter.seek(Number(args['position'] ?? 0));
        return null;
      case 'setScaleMode':
        adapter.setScaleMode(Number(args['mode'] ?? 0));
        return null;
      case 'setRate':
        adapter.setPlaybackRate(Number(args['rate'] ?? 1));
        return null;
      case 'setVolume':
        adapter.setVolume(Number(args['volume'] ?? 1));
        return null;
      case 'setMute':
        adapter.setMute(Boolean(args['muted']));
        return null;
      case 'switchVideoSource':
        await adapter.switchVideoSource(
          String(args['url'] ?? ''),
          args['autoPlay'] !== false,
        );
        return null;
      case 'getAudioTracks':
        return adapter.getAudioTracks();
      case 'selectAudioTrack':
        if (!adapter.selectAudioTrack(Number(args['index'] ?? 0))) {
          throw new Error('Audio track not found');
        }
        return null;
      case 'getVideoSize':
        return adapter.getVideoSize();
      case 'setLooping':
        adapter.setLooping(Boolean(args['looping']));
        return null;
      case 'captureFrame':
        return adapter.captureFrame();
      case 'togglePip':
      case 'artTogglePip':
        return adapter.togglePip();
      case 'artIsPipSupported':
        return KineticArtplayerAdapter.isPipSupported;
      case 'artIsPipActive':
        return adapter.isPipActive;
      case 'artSetUiConfig':
        adapter.applyUiConfig((args['gsyUi'] as ArtplayerUiConfig) ?? (args as ArtplayerUiConfig));
        return null;
      case 'dispose':
        this.dispose();
        return null;
      default:
        throw new Error(`Unknown method: ${method}`);
    }
  }

  dispose(): void {
    this.adapter?.dispose();
    this.adapter = null;
    this.eventHandler = null;
  }
}

export function createBridge(): ArtplayerWebBridge {
  return new ArtplayerWebBridge();
}
