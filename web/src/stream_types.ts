import type Artplayer from 'artplayer';
import Hls from 'hls.js';
import * as dashjs from 'dashjs';

import type { ArtplayerWithStream } from './types';

/** Mirrors artplayer `CustomType` without deep package path imports. */
type CustomType =
  | 'flv'
  | 'm3u8'
  | 'hls'
  | 'ts'
  | 'mpd'
  | 'torrent'
  | (string & Record<never, never>);

type CustomTypeHandler = (
  this: Artplayer,
  video: HTMLVideoElement,
  url: string,
  art: Artplayer,
) => unknown;

export type CustomTypeMap = Partial<Record<CustomType, CustomTypeHandler>>;

function asStreamArt(art: Artplayer): ArtplayerWithStream {
  return art as ArtplayerWithStream;
}

/**
 * Wires HLS / DASH customType handlers used by hls-control / dash-control plugins.
 * Safe to merge with host-provided customType (host wins on key collision).
 */
export function buildStreamCustomType(
  existing?: CustomTypeMap,
): CustomTypeMap {
  const customType: CustomTypeMap = { ...(existing ?? {}) };

  if (!customType.m3u8 && !customType.hls) {
    const hlsHandler: CustomTypeHandler = function (video, url, art) {
      const streamArt = asStreamArt(art);
      if (Hls.isSupported()) {
        streamArt.hls?.destroy();
        const hls = new Hls();
        hls.loadSource(url);
        hls.attachMedia(video);
        streamArt.hls = hls;
        art.on('destroy', () => hls.destroy());
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = url;
      } else {
        art.notice.show = 'Unsupported HLS playback';
      }
    };
    customType.m3u8 = hlsHandler;
    customType.hls = hlsHandler;
  }

  if (!customType.mpd && !customType.dash) {
    const dashHandler: CustomTypeHandler = function (video, url, art) {
      const streamArt = asStreamArt(art);
      streamArt.dash?.reset();
      const player = dashjs.MediaPlayer().create();
      player.initialize(video, url, false);
      streamArt.dash = player;
      art.on('destroy', () => player.reset());
    };
    customType.mpd = dashHandler;
    customType.dash = dashHandler;
  }

  return customType;
}

/** Infer Artplayer `type` from URL when not set explicitly. */
export function inferStreamType(url?: string): CustomType | undefined {
  if (!url) return undefined;
  const lower = url.split('?')[0]?.toLowerCase() ?? '';
  if (lower.endsWith('.m3u8')) return 'm3u8';
  if (lower.endsWith('.mpd')) return 'mpd';
  return undefined;
}
