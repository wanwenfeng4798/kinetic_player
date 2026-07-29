import { KineticArtplayerAdapter } from './artplayer_adapter';
import { ArtplayerWebBridge, createBridge } from './artplayer_web_bridge';
import { PlayerState, ScaleMode } from './types';

export interface KineticArtplayerGlobal {
  KineticArtplayerAdapter: typeof KineticArtplayerAdapter;
  ArtplayerWebBridge: typeof ArtplayerWebBridge;
  createBridge: typeof createBridge;
  PlayerState: typeof PlayerState;
  ScaleMode: typeof ScaleMode;
  isPipSupported: () => boolean;
}

const api: KineticArtplayerGlobal = {
  KineticArtplayerAdapter,
  ArtplayerWebBridge,
  createBridge,
  PlayerState,
  ScaleMode,
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
};

export default api;
