import type Artplayer from 'artplayer';
import type { KineticArtplayerConfig } from './types';
type Ui = KineticArtplayerConfig['ui'];

export function updateChromeUi(container: HTMLElement, ui: Ui): void {
  for (const [field, key] of [['showVolumeToolbar','volume'],['showSettingsButton','settings'],['showFullscreenButton','fullscreen'],['showLockButton','lock']] as const) {
    if (typeof ui?.[field] === 'boolean') container.dataset[`kinetic${key}`] = String(ui[field]);
  }
}

/** Style and position SDK controls; playback, seeking and selectors stay owned by Artplayer. */
export function installPlayerChrome(art: Artplayer, container: HTMLElement, ui: Ui): () => void {
  container.classList.add('kinetic-player-ui');
  updateChromeUi(container, ui);
  const style = document.createElement('style');
  style.textContent = `
.kinetic-player-ui{container-type:inline-size;container-name:kinetic-player}
.kinetic-player-ui .art-video-player{--art-indicator-scale:1;--art-indicator-size:12px;--art-control-height:44px;--art-padding:8px;--art-border-radius:8px;color:#fff;font-size:12px}
.kinetic-player-ui .art-bottom{left:0!important;right:0!important;bottom:0!important;padding:0 8px!important;background:transparent!important}
.kinetic-player-ui .art-controls{display:grid!important;grid-template-columns:44px 52px minmax(32px,1fr) 52px max-content;align-items:center;height:48px!important;flex:0 0 48px;background:rgba(0,0,0,.6)}
.kinetic-player-ui .art-controls-center{display:none}
.kinetic-player-ui .art-control-document-pip{display:none!important}
.kinetic-player-ui:has(.apd-emitter) .art-controls{height:92px!important;flex-basis:92px;grid-template-rows:44px 44px}
.kinetic-player-ui:has(.apd-emitter) .art-settings{bottom:100px!important;max-height:calc(100% - 108px)!important}
.kinetic-player-ui:has(.apd-emitter) .art-controls-center{display:flex!important;grid-column:1 / -1;grid-row:2;min-width:0;max-width:100%}
.kinetic-player-ui .art-controls-center .artplayer-plugin-danmuku{width:100%;max-width:100%;min-width:0;gap:8px}
.kinetic-player-ui .art-controls-center .apd-emitter{width:0!important;flex:1 1 0!important;max-width:100%;min-width:0;background:rgba(255,255,255,.12);border-radius:20px}
.kinetic-player-ui .apd-send{background:transparent!important;color:var(--art-theme)!important}
.kinetic-player-ui .art-controls-left{display:contents!important}
.kinetic-player-ui .art-controls-right{grid-column:5;display:flex!important;width:max-content;justify-self:end;align-items:center;height:44px}
.kinetic-player-ui .art-control-playAndPause{grid-column:1;grid-row:1}
.kinetic-player-ui .art-control-time{grid-column:2;grid-row:1;padding:0 4px!important;font-size:0!important}
.kinetic-player-ui .art-control-time::before{content:attr(data-current);font-size:12px}
.kinetic-player-ui .kinetic-duration{grid-column:4;grid-row:1;font-size:12px;white-space:nowrap}
.kinetic-player-ui .art-progress{grid-column:3;grid-row:1;position:relative!important;left:auto!important;right:auto!important;bottom:auto!important;width:auto!important;height:24px!important;margin:0 8px;padding:0!important}
.kinetic-player-ui .art-progress .art-control-progress{height:24px!important;min-height:0!important;width:100%;padding:0!important;box-sizing:border-box}
.kinetic-player-ui .art-control-progress-inner{height:3px!important}
.kinetic-player-ui .art-controls-right .art-control{width:44px!important;min-width:44px!important;max-width:44px;flex:0 0 44px;height:44px;padding:0 8px!important;box-sizing:border-box}
.kinetic-player-ui .art-control-kinetic-rate{order:0}
.kinetic-player-ui .art-control-setting{order:1}
.kinetic-player-ui .art-control-volume{order:2}
.kinetic-player-ui .art-control-pip{order:3}
.kinetic-player-ui .art-control-fullscreen{order:4}
.kinetic-player-ui .art-settings,.kinetic-player-ui .art-selector{background:rgba(16,16,16,.95)!important;color:#fff;border-radius:8px}
.kinetic-player-ui .art-settings{bottom:56px!important;max-height:calc(100% - 64px)!important;max-width:calc(100% - 24px)!important}
.kinetic-player-ui .art-layer-lock{display:none!important}
.kinetic-player-ui .kinetic-lock{position:absolute;right:max(20px,env(safe-area-inset-right));top:calc(50% - 22px);width:44px;height:44px;border:0;background:transparent;color:white;cursor:pointer;pointer-events:auto}
.kinetic-player-ui .kinetic-lock:focus-visible{outline:2px solid var(--art-theme,#fb7299);outline-offset:2px}
.kinetic-player-ui .kinetic-lock svg{width:24px;height:24px;fill:currentColor}
.kinetic-player-ui.kinetic-locked .art-bottom,.kinetic-player-ui.kinetic-locked .art-state,.kinetic-player-ui.kinetic-locked .art-settings{display:none!important}
.kinetic-art-nocontrols .kinetic-lock{display:none!important}
.kinetic-player-ui:not(.kinetic-locked) .art-video-player:not(.art-control-show) .kinetic-lock{visibility:hidden}
.kinetic-player-ui[data-kineticvolume="false"] .art-control-volume,.kinetic-player-ui[data-kineticsettings="false"] .art-control-setting,.kinetic-player-ui[data-kineticfullscreen="false"] .art-control-fullscreen,.kinetic-player-ui[data-kineticlock="false"] .kinetic-lock{display:none!important}
@container kinetic-player (max-width:559px){
 .kinetic-player-ui .art-controls{height:92px!important;flex-basis:92px;grid-template-columns:52px minmax(16px,1fr) 52px;grid-template-rows:44px 44px}
 .kinetic-player-ui:has(.apd-emitter) .art-controls{height:136px!important;flex-basis:136px;grid-template-rows:44px 44px 44px}
 .kinetic-player-ui:has(.apd-emitter) .art-controls-center{grid-row:3}
 .kinetic-player-ui:has(.apd-emitter) .art-settings{bottom:144px!important;max-height:calc(100% - 152px)!important}
 .kinetic-player-ui .art-control-playAndPause{grid-row:2}
 .kinetic-player-ui .kinetic-duration{grid-column:3;grid-row:1}
 .kinetic-player-ui .art-control-time{grid-column:1;grid-row:1}
 .kinetic-player-ui .art-progress{grid-column:2;grid-row:1}
 .kinetic-player-ui .art-controls-right{grid-column:1 / 4;grid-row:2;justify-content:flex-end}
 .kinetic-player-ui:not([data-kineticsettings="false"]) .art-control-pip{display:none!important}
 .kinetic-player-ui .art-settings{bottom:100px!important;max-height:calc(100% - 108px)!important}
 .kinetic-player-ui .art-bottom{padding-bottom:env(safe-area-inset-bottom)!important}
}
`;
  document.head.append(style);
  art.controls.add({ name:'kinetic-rate', position:'right', index:5,
    html:'<span class="kinetic-rate-label">1.0x</span>',
    tooltip: ui?.strings?.kinetic_rate_icon ?? ((ui?.locale ?? 'zh').startsWith('zh') ? '倍速' : 'Speed'),
    selector:[.5,.75,1,1.25,1.5,2].map(value => ({ html:`${value}x`,value,default:value === 1 })),
    onSelect(item) { art.playbackRate = Number(item.value); },
  });
  if (art.option.pip) art.setting.add({name:'kinetic-pip',
    html:(ui?.locale ?? 'zh').startsWith('zh') ? '画中画' : 'Picture in picture',
    onClick() {art.pip = !art.pip;},
  });
  const root = art.template.$player;
  const documentPip = root.querySelector<HTMLElement>('.art-control-document-pip');
  if (documentPip) art.setting.add({name:'kinetic-document-pip',
    html:(ui?.locale ?? 'zh').startsWith('zh') ? '网页画中画' : 'Document picture in picture',
    onClick() {documentPip.click();},
  });

  const controls = root.querySelector('.art-controls');
  const progress = root.querySelector('.art-progress');
  const right = root.querySelector('.art-controls-right');
  const volume = root.querySelector('.art-control-volume');
  if (right && volume) right.append(volume);
  if (controls && progress) controls.insertBefore(progress, right);
  const time = root.querySelector<HTMLElement>('.art-control-time');
  let timeObserver: MutationObserver | undefined;
  const duration = document.createElement('span'); duration.className = 'kinetic-duration';
  if (time && controls) {
    controls.insertBefore(duration,right);
    const syncTime = () => {
      // Project the SDK's already formatted text; do not maintain another clock.
      const [current,total] = (time.textContent ?? '').split(/\s*\/\s*/);
      time.dataset.current = current ?? ''; time.setAttribute('aria-label',current ?? '');
      duration.textContent = total ?? '';
    };
    timeObserver = new MutationObserver(syncTime);
    timeObserver.observe(time,{childList:true,characterData:true,subtree:true});syncTime();
  }

  const rate = () => {
    const label = root.querySelector('.kinetic-rate-label');
    if (label) label.textContent = `${Number.isInteger(art.playbackRate) ? art.playbackRate.toFixed(1) : Number(art.playbackRate.toFixed(2))}x`;
  };
  art.on('video:ratechange', rate); rate();
  const lock = document.createElement('button');
  lock.className = 'kinetic-lock'; lock.type = 'button';
  const label = (locked: boolean) => {
    lock.setAttribute('aria-label', (ui?.locale ?? 'zh').startsWith('zh') ? (locked ? '解锁' : '锁定') : (locked ? 'Unlock' : 'Lock'));
    lock.setAttribute('aria-pressed',String(locked));
    lock.replaceChildren((locked ? art.icons.lock : art.icons.unlock).cloneNode(true));
  };
  const toggle = () => {
    const locked = !container.classList.contains('kinetic-locked');
    container.classList.toggle('kinetic-locked',locked);
    // Reuse the built-in lock state on touch platforms when available.
    const native = art.plugins['lock'] as unknown as {state:boolean} | undefined;
    if (native) native.state = locked;
    else art.emit('lock',locked);
    label(locked); if (locked) lock.focus();
  };
  const syncLock = (locked: boolean) => {container.classList.toggle('kinetic-locked',locked);label(locked);};
  art.on('lock',syncLock);
  lock.addEventListener('keydown',event => event.stopPropagation());
  lock.addEventListener('click', toggle); root.append(lock); label(false);
  const intercept = (event: Event) => {
    if (!container.classList.contains('kinetic-locked') || lock.contains(event.target as Node)) return;
    if (event instanceof KeyboardEvent && (event.key === 'Tab' || event.ctrlKey || event.metaKey || event.altKey)) return;
    event.preventDefault(); event.stopImmediatePropagation();
  };
  for (const name of ['click','dblclick','pointerdown','touchstart','keydown']) root.addEventListener(name,intercept,true);
  return () => {
    art.off('video:ratechange',rate);
    art.off('lock',syncLock);
    for (const name of ['click','dblclick','pointerdown','touchstart','keydown']) root.removeEventListener(name,intercept,true);
    timeObserver?.disconnect();duration.remove();
    lock.remove();style.remove();container.classList.remove('kinetic-player-ui','kinetic-locked');
    for (const key of ['volume','settings','fullscreen','lock']) delete container.dataset[`kinetic${key}`];
  };
}
