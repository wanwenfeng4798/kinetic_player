import { KineticArtplayerAdapter } from './artplayer_adapter';
import type { ArtPluginsConfig, ArtplayerUiConfig, KineticArtplayerConfig } from './types';
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
    userAgent?: string;
    headers?: Record<string, string>;
    artplayerOptions?: Record<string, unknown>;
    webCustomExtensions?: Record<string, unknown>;
    artPlugins?: ArtPluginsConfig;
    onEvent?: BridgeEventHandler;
  }): Promise<void> {
    this.dispose();
    this.eventHandler = config.onEvent ?? null;

    const adapterConfig: KineticArtplayerConfig = {
      container: config.container,
      url: config.url,
      ui: config.ui,
      userAgent: config.userAgent,
      headers: config.headers,
      artplayerOptions: config.artplayerOptions,
      webCustomExtensions: config.webCustomExtensions,
      artPlugins: config.artPlugins,
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

    return KineticArtplayerAdapter.create(adapterConfig).then((adapter) => {
      this.adapter = adapter;
    });
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
      case 'setLocale':
        adapter.applyLocale(
          typeof args['locale'] === 'string' ? args['locale'] : undefined,
          (args['strings'] as Record<string, string> | undefined) ?? undefined,
        );
        return null;
      case 'setHttpRequestOptions': {
        const rawHeaders = args['headers'];
        let headers: Record<string, string> | undefined;
        if (rawHeaders && typeof rawHeaders === 'object') {
          headers = {};
          for (const [key, value] of Object.entries(
            rawHeaders as Record<string, unknown>,
          )) {
            if (typeof value === 'string') headers[key] = value;
            else if (value != null) headers[key] = String(value);
          }
          if (Object.keys(headers).length === 0) headers = undefined;
        }
        adapter.setHttpRequestOptions({
          userAgent:
            typeof args['userAgent'] === 'string'
              ? (args['userAgent'] as string)
              : undefined,
          headers,
        });
        return null;
      }
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
        adapter.applyUiConfig(args['ui'] as ArtplayerUiConfig | undefined);
        return null;
      case 'artAvailablePlugins':
        return [...KineticArtplayerAdapter.availablePlugins];
      case 'artCallPlugin': {
        const name = String(args['name'] ?? '');
        const pluginMethod = String(args['method'] ?? '');
        const pluginArgs = Array.isArray(args['args']) ? (args['args'] as unknown[]) : [];
        return adapter.callPlugin(name, pluginMethod, pluginArgs);
      }
      case 'artEmitDanmuku':
        return adapter.emitDanmuku(
          (args['danmu'] as Record<string, unknown>) ?? args,
        );
      case 'artToggleDocumentPip':
        return adapter.toggleDocumentPip();
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
