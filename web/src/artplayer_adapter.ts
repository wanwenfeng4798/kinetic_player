import Artplayer from 'artplayer';
import type {
  AudioTrackInfo,
  KineticArtplayerConfig,
  ScaleMode,
  VideoSizeInfo,
} from './types';
import { PlayerState, ScaleMode as ScaleModeEnum } from './types';

const POSITION_THROTTLE_MS = 250;

/**
 * Artplayer adapter for kinetic_player Web.
 * Maps public API (play/pause/seek/volume/rate/dispose/togglePip) to Artplayer.
 */
export class KineticArtplayerAdapter {
  private art: Artplayer;
  private readonly config: KineticArtplayerConfig;
  private disposed = false;
  private lastPositionEmit = 0;
  private state: PlayerState = PlayerState.idle;
  private volumeBeforeMute = 1;
  private muted = false;
  private looping = false;
  private pipActive = false;
  private scaleMode: ScaleMode = ScaleModeEnum.fit;

  constructor(config: KineticArtplayerConfig) {
    this.config = config;
    const ui = config.ui ?? {};
    const enableControls = ui.enableNativeControls !== false;
    const pipEnabled = ui.pictureInPictureEnabled !== false;
    const custom = {
      ...(config.artplayerOptions ?? {}),
      ...(config.webCustomExtensions ?? {}),
    };

    this.looping = ui.looping === true;

    this.art = new Artplayer({
      container: config.container,
      url: config.url ?? '',
      poster: ui.coverUrl,
      volume: 1,
      autoplay: false,
      muted: false,
      autoSize: false,
      loop: this.looping,
      playbackRate: true,
      aspectRatio: true,
      screenshot: false,
      setting: ui.showSettingsButton !== false && enableControls,
      hotkey: enableControls,
      pip: pipEnabled && enableControls,
      mutex: true,
      fullscreen: ui.showFullscreenButton !== false && enableControls,
      fullscreenWeb: false,
      miniProgressBar: enableControls,
      playsInline: true,
      lock: enableControls,
      gesture: enableControls,
      autoOrientation: false,
      moreVideoAttr: {
        controls: false,
        playsinline: true,
        'webkit-playsinline': true,
        'x5-video-player-type': 'h5',
        preload: 'metadata',
      },
      ...custom,
    });

    if (typeof ui.speed === 'number' && ui.speed > 0) {
      this.art.playbackRate = ui.speed;
    }

    if (!enableControls) {
      this.hideNativeChrome();
    }

    this.applyMobileInlineAttributes();
    this.bindEvents();
    this.setupPipListeners();
  }

  private hideNativeChrome(): void {
    const style = document.createElement('style');
    style.textContent = `
      .kinetic-art-nocontrols .art-bottom,
      .kinetic-art-nocontrols .art-controls,
      .kinetic-art-nocontrols .art-notice,
      .kinetic-art-nocontrols .art-contextmenus {
        display: none !important;
      }
    `;
    document.head.appendChild(style);
    this.config.container.classList.add('kinetic-art-nocontrols');
  }

  private applyMobileInlineAttributes(): void {
    const video = this.art.video;
    if (!video) return;
    video.setAttribute('playsinline', 'true');
    video.setAttribute('webkit-playsinline', 'true');
    video.setAttribute('x5-video-player-type', 'h5');
    video.controls = false;
  }

  private bindEvents(): void {
    this.art.on('ready', () => {
      this.applyMobileInlineAttributes();
      this.applyScaleMode(this.scaleMode);
      this.emitState(PlayerState.ready);
    });

    this.art.on('play', () => this.emitState(PlayerState.playing));
    this.art.on('video:play', () => this.emitState(PlayerState.playing));
    this.art.on('pause', () => {
      if (this.state !== PlayerState.completed) {
        this.emitState(PlayerState.paused);
      }
    });
    this.art.on('video:pause', () => {
      if (this.state !== PlayerState.completed) {
        this.emitState(PlayerState.paused);
      }
    });
    this.art.on('video:waiting', () => this.emitState(PlayerState.buffering));
    this.art.on('video:seeking', () => this.emitState(PlayerState.buffering));
    this.art.on('video:seeked', () => {
      this.emitPosition(true);
      if (!this.art.playing) {
        this.emitState(PlayerState.paused);
      } else {
        this.emitState(PlayerState.playing);
      }
    });
    this.art.on('video:ended', () => {
      if (this.looping) {
        void this.seek(0).then(() => this.play());
        return;
      }
      this.emitState(PlayerState.completed);
    });
    this.art.on('video:timeupdate', () => this.emitPosition(false));
    this.art.on('error', (error: unknown) => {
      const message =
        error instanceof Error
          ? error.message
          : typeof error === 'string'
            ? error
            : 'Artplayer error';
      this.config.onError?.(message);
      this.emitState(PlayerState.error);
    });
  }

  private setupPipListeners(): void {
    this.art.on('pip', (state: boolean) => {
      this.pipActive = Boolean(state);
      this.config.onPipChanged?.(this.pipActive);
    });

    const video = this.art.video;
    if (!video) return;
    video.addEventListener('enterpictureinpicture', () => {
      this.pipActive = true;
      this.config.onPipChanged?.(true);
    });
    video.addEventListener('leavepictureinpicture', () => {
      this.pipActive = false;
      this.config.onPipChanged?.(false);
    });
  }

  private emitState(state: PlayerState): void {
    if (this.disposed || this.state === state) return;
    this.state = state;
    this.config.onStateChanged?.(state);
  }

  private emitPosition(force: boolean): void {
    if (this.disposed) return;
    const now = Date.now();
    if (!force && now - this.lastPositionEmit < POSITION_THROTTLE_MS) return;
    this.lastPositionEmit = now;
    const positionMs = Math.max(0, Math.floor((this.art.currentTime ?? 0) * 1000));
    const durationMs = Math.max(0, Math.floor((this.art.duration ?? 0) * 1000));
    this.config.onPositionChanged?.(positionMs, durationMs);
  }

  async play(): Promise<void> {
    try {
      await this.art.play();
    } catch {
      // Autoplay policy fallback: mute then retry.
      this.art.muted = true;
      this.muted = true;
      try {
        await this.art.play();
      } catch (error) {
        const message =
          error instanceof Error ? error.message : 'Playback failed (user gesture required)';
        this.config.onError?.(message);
        this.emitState(PlayerState.error);
        throw error;
      }
    }
  }

  pause(): void {
    this.art.pause();
  }

  stop(): void {
    this.art.pause();
    this.art.currentTime = 0;
    this.emitState(PlayerState.idle);
    this.emitPosition(true);
  }

  async seek(positionMs: number): Promise<void> {
    const seconds = Math.max(0, positionMs) / 1000;
    this.art.currentTime = seconds;
    this.emitPosition(true);
  }

  setVolume(volume: number): void {
    const clamped = Math.min(1, Math.max(0, volume));
    this.art.volume = clamped;
    if (clamped > 0) {
      this.volumeBeforeMute = clamped;
      this.muted = false;
      this.art.muted = false;
    }
  }

  setMute(muted: boolean): void {
    this.muted = muted;
    if (muted) {
      this.volumeBeforeMute = this.art.volume || this.volumeBeforeMute;
      this.art.muted = true;
    } else {
      this.art.muted = false;
      this.art.volume = this.volumeBeforeMute || 1;
    }
  }

  setPlaybackRate(rate: number): void {
    this.art.playbackRate = rate;
  }

  setLooping(looping: boolean): void {
    this.looping = looping;
    this.art.loop = looping;
  }

  setScaleMode(mode: ScaleMode): void {
    this.scaleMode = mode;
    this.applyScaleMode(mode);
  }

  private applyScaleMode(mode: ScaleMode): void {
    const video = this.art.video;
    if (!video) return;
    switch (mode) {
      case ScaleModeEnum.fill:
        video.style.objectFit = 'cover';
        break;
      case ScaleModeEnum.stretch:
        video.style.objectFit = 'fill';
        break;
      case ScaleModeEnum.fit:
      default:
        video.style.objectFit = 'contain';
        break;
    }
  }

  async switchVideoSource(url: string, autoPlay = true): Promise<void> {
    this.emitState(PlayerState.buffering);
    await this.art.switchUrl(url);
    if (autoPlay) {
      await this.play();
    } else {
      this.emitState(PlayerState.ready);
    }
  }

  getAudioTracks(): AudioTrackInfo[] {
    const video = this.art.video as HTMLVideoElement & {
      audioTracks?: {
        length: number;
        [index: number]: { label?: string; language?: string; enabled: boolean };
      };
    };
    const tracks = video.audioTracks;
    if (!tracks || tracks.length === 0) {
      return [
        {
          index: 0,
          label: 'Default',
          selected: true,
        },
      ];
    }
    const result: AudioTrackInfo[] = [];
    for (let i = 0; i < tracks.length; i++) {
      const t = tracks[i];
      result.push({
        index: i,
        label: t.label || `Track ${i + 1}`,
        language: t.language || undefined,
        selected: t.enabled,
      });
    }
    return result;
  }

  selectAudioTrack(index: number): boolean {
    const video = this.art.video as HTMLVideoElement & {
      audioTracks?: {
        length: number;
        [i: number]: { enabled: boolean };
      };
    };
    const tracks = video.audioTracks;
    if (!tracks || index < 0 || index >= tracks.length) return false;
    for (let i = 0; i < tracks.length; i++) {
      tracks[i].enabled = i === index;
    }
    return true;
  }

  getVideoSize(): VideoSizeInfo | null {
    const video = this.art.video;
    if (!video) return null;
    const width = video.videoWidth || 0;
    const height = video.videoHeight || 0;
    if (width <= 0 || height <= 0) return null;
    return { width, height };
  }

  getCurrentPositionMs(): number {
    return Math.max(0, Math.floor((this.art.currentTime ?? 0) * 1000));
  }

  getDurationMs(): number {
    return Math.max(0, Math.floor((this.art.duration ?? 0) * 1000));
  }

  get isPipActive(): boolean {
    return this.pipActive;
  }

  static get isPipSupported(): boolean {
    if (typeof document === 'undefined') return false;
    return Boolean(
      document.pictureInPictureEnabled &&
        (Artplayer as unknown as { html5?: { isPipSupported?: boolean } }).html5
          ?.isPipSupported !== false,
    );
  }

  async togglePip(): Promise<boolean> {
    if (!KineticArtplayerAdapter.isPipSupported) {
      throw new Error('PiP not supported on this platform');
    }
    this.art.pip = !this.art.pip;
    this.pipActive = Boolean(this.art.pip);
    return this.pipActive;
  }

  async captureFrame(): Promise<string | null> {
    try {
      const canvas = document.createElement('canvas');
      const video = this.art.video;
      if (!video || !video.videoWidth) return null;
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext('2d');
      if (!ctx) return null;
      ctx.drawImage(video, 0, 0);
      return canvas.toDataURL('image/png');
    } catch {
      return null;
    }
  }

  applyUiConfig(ui: KineticArtplayerConfig['ui']): void {
    if (!ui) return;
    if (typeof ui.looping === 'boolean') this.setLooping(ui.looping);
    if (typeof ui.speed === 'number' && ui.speed > 0) {
      this.setPlaybackRate(ui.speed);
    }
    if (ui.coverUrl) {
      this.art.poster = ui.coverUrl;
    }
    if (ui.enableNativeControls === false) {
      this.hideNativeChrome();
    }
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    try {
      this.art.destroy(false);
    } catch {
      // ignore
    }
  }
}
