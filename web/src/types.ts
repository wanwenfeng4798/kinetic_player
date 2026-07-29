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
}

export interface KineticArtplayerConfig {
  container: HTMLDivElement;
  url?: string;
  /** Mapped from GsyUiConfig / creationParams.gsyUi */
  ui?: ArtplayerUiConfig;
  /**
   * Advanced Artplayer-only options (plugins, danmuku, custom layers…).
   * Must not pollute the universal kinetic_player API.
   */
  artplayerOptions?: Record<string, unknown>;
  webCustomExtensions?: Record<string, unknown>;
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
