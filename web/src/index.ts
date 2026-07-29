import { KineticArtplayerAdapter } from './artplayer_adapter';
import { ArtplayerWebBridge, createBridge } from './artplayer_web_bridge';
import { ART_PLUGIN_KEYS } from './plugins';
import { PlayerState, ScaleMode } from './types';

export interface KineticArtplayerGlobal {
  KineticArtplayerAdapter: typeof KineticArtplayerAdapter;
  ArtplayerWebBridge: typeof ArtplayerWebBridge;
  createBridge: typeof createBridge;
  PlayerState: typeof PlayerState;
  ScaleMode: typeof ScaleMode;
  availablePlugins: readonly string[];
  isPipSupported: () => boolean;
}

const api: KineticArtplayerGlobal = {
  KineticArtplayerAdapter,
  ArtplayerWebBridge,
  createBridge,
  PlayerState,
  ScaleMode,
  availablePlugins: ART_PLUGIN_KEYS,
  isPipSupported: () => KineticArtplayerAdapter.isPipSupported,
};

declare global {
  interface Window {
    KineticArtplayer: KineticArtplayerGlobal;
  }
}

if (typeof window !== 'undefined') {
  window.KineticArtplayer = api;
}

export {
  KineticArtplayerAdapter,
  ArtplayerWebBridge,
  createBridge,
  PlayerState,
  ScaleMode,
  ART_PLUGIN_KEYS,
};

export default api;
