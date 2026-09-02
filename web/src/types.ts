import type Artplayer from 'artplayer';

/** Mirrors CommonPlayerState index order in Dart. */
export enum PlayerState {
  idle = 0,
  buffering = 1,
  ready = 2,
  playing = 3,
  paused = 4,
  completed = 5,
  error = 6,
}

/** CommonScaleMode index order in Dart. */
export enum ScaleMode {
  fit = 0,
  fill = 1,
  stretch = 2,
}

export interface ArtplayerUiConfig {
  enableNativeControls?: boolean;
  showFullscreenButton?: boolean;
  showVolumeToolbar?: boolean;
  showSettingsButton?: boolean;
  pictureInPictureEnabled?: boolean;
  dismissControlTime?: number;
  videoTitle?: string;
  speed?: number;
  looping?: boolean;
  coverUrl?: string;
  keepLastFrameWhenComplete?: boolean;
  startAfterPrepared?: boolean;
  /** ARGB int, default Bilibili pink 0xFFFB7299 */
  accentColor?: number;
  locale?: string;
  strings?: Record<string, string>;
}

/**
 * JSON-serializable Artplayer plugin toggles / options from Dart.
 * `true` enables with defaults; object passes plugin constructor options.
 * Must stay under artPlugins / webCustomExtensions — never on CommonVideoController.
 */
export interface ArtPluginsConfig {
  danmuku?: boolean | Record<string, unknown>;
  danmukuMask?: boolean | Record<string, unknown>;
  hlsControl?: boolean | Record<string, unknown>;
  dashControl?: boolean | Record<string, unknown>;
  vttThumbnail?: boolean | Record<string, unknown>;
  multipleSubtitles?: boolean | Record<string, unknown>;
  chromecast?: boolean | Record<string, unknown>;
  /** Prefer `{ tagUrl: string }` — VAST setup function is wrapped in JS. */
  vast?: boolean | Record<string, unknown>;
  chapter?: boolean | Record<string, unknown>;
  autoThumbnail?: boolean | Record<string, unknown>;
  ambilight?: boolean | Record<string, unknown>;
  documentPip?: boolean | Record<string, unknown>;
  audioTrack?: boolean | Record<string, unknown>;
  jassub?: boolean | Record<string, unknown>;
  asr?: boolean | Record<string, unknown>;
  /** Requires `{ source: string, type: 'video'|'image'|'html' }`. */
  ads?: boolean | Record<string, unknown>;
}

/** Matches Artplayer's `plugins` entry signature. */
export type PluginFactory = (art: Artplayer) => unknown;

/** Runtime fields attached by HLS / DASH customType handlers. */
export type ArtplayerWithStream = Artplayer & {
  hls?: import('hls.js').default;
  dash?: import('dashjs').MediaPlayerClass;
};

export interface KineticArtplayerConfig {
  container: HTMLDivElement;
  url?: string;
  /** Mapped from KineticUiConfig / creationParams.ui */
  ui?: ArtplayerUiConfig;
  /** Custom User-Agent (best-effort; browsers often forbid overriding). */
  userAgent?: string;
  /** Extra HTTP headers for HLS/DASH xhr (not progressive MP4). */
  headers?: Record<string, string>;
  /**
   * Advanced Artplayer-only options (layers, etc.).
   * Must not pollute the universal kinetic_player API.
   */
  artplayerOptions?: Record<string, unknown>;
  webCustomExtensions?: Record<string, unknown>;
  /** Declarative plugin enablement (preferred over raw plugins[]). */
  artPlugins?: ArtPluginsConfig;
  onStateChanged?: (state: PlayerState) => void;
  onPositionChanged?: (positionMs: number, durationMs: number) => void;
  onPipChanged?: (active: boolean) => void;
  onError?: (message: string) => void;
}

export interface AudioTrackInfo {
  index: number;
  label: string;
  language?: string;
  selected: boolean;
}

export interface VideoSizeInfo {
  width: number;
  height: number;
}
