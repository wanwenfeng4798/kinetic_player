#import "SgNativePlayerBridge.h"
#import "SgFeatureService.h"
#import <SGPlayer/SGPlayer.h>
#import <SGPlayer/SGPlaybackSession.h>
#import <SGPlayer/SGPlaybackControls.h>
#import <math.h>
#if TARGET_OS_OSX
#define SgPlatformView NSView
#else
#define SgPlatformView UIView
#endif

@interface SgNativePlayerBridge ()
@property(nonatomic, copy) SgStateChangedBlock stateHandler;
@property(nonatomic, copy) SgProgressChangedBlock progressHandler;
@property(nonatomic, copy) SgErrorChangedBlock errorHandler;
@property(nonatomic, strong) SGPlaybackController *controller;
@property(nonatomic, strong) SGPlaybackSession *session;
@property(nonatomic, strong) SGPlaybackControls *controls;
@property(nonatomic, strong) SgFeatureService *features;
@property(nonatomic, strong) NSTimer *progressTimer;
@property(nonatomic) BOOL segmentMode;
@property(nonatomic) BOOL segmentLooping;
@property(nonatomic) NSInteger renderMode;
@property(nonatomic, strong) SgPlatformView *containerView;
@property(nonatomic, strong) SgPlatformView *surface;
@property(nonatomic) BOOL muted;
@property(nonatomic) double savedVolume;
@property(nonatomic) double savedPitch;
@property(nonatomic) BOOL wantsBackgroundPlayback;
@property(nonatomic, copy) NSDictionary *pendingDemuxerOptions;
@property(nonatomic, copy) NSString *lastErrorMessage;
@property(nonatomic) NSInteger lastErrorCode;
@end

@implementation SgNativePlayerBridge
+ (BOOL)handleBackgroundSession:(NSString *)identifier completion:(void (^)(void))completion { return [SgFeatureService handleBackgroundSession:identifier completion:completion]; }
- (SGPlayer *)player { return self.controller.ffmpegPlayer; }
- (instancetype)initWithStateHandler:(SgStateChangedBlock)stateHandler
                     progressHandler:(SgProgressChangedBlock)progressHandler
                        errorHandler:(SgErrorChangedBlock)errorHandler {
  if ((self = [super init])) {
    _stateHandler = [stateHandler copy];
    _progressHandler = [progressHandler copy];
    _errorHandler = [errorHandler copy];
    _savedVolume = _savedPitch = 1;
    _containerView = [[SgPlatformView alloc] init];
    _surface = [[SgPlatformView alloc] init];
    _controller = [[SGPlaybackController alloc] initWithKernel:SGPlaybackKernelFFmpeg view:_surface];
    _session = [[SGPlaybackSession alloc] initWithController:_controller resumeStore:NSUserDefaults.standardUserDefaults];
    _session.resumeEnabled = NO;
    _controls = [[SGPlaybackControls alloc] initWithSession:_session];
    for (SgPlatformView *view in @[_surface, _controls]) {
      view.translatesAutoresizingMaskIntoConstraints = NO;
      [_containerView addSubview:view];
      [NSLayoutConstraint activateConstraints:@[
        [view.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],
        [view.topAnchor constraintEqualToAnchor:_containerView.topAnchor],
        [view.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor]]];
    }
    _features = [[SgFeatureService alloc] initWithSession:_session controls:_controls surface:_surface container:_containerView];
    __weak typeof(self) weakSelf = self;
    _progressTimer = [NSTimer timerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) {
      typeof(self) self = weakSelf;
      if (!self) return;
      if (self.segmentMode) {
        SGStateInfo info = self.player.sstateInfo;
        NSInteger state = info.player == SGPlayerStateFailed ? 6 :
          (info.playback & SGPlaybackStateFinished) ? 5 :
          (info.playback & SGPlaybackStatePlaying) ? 3 :
          info.player == SGPlayerStatePreparing ? 1 : 4;
        [self emitState:state];
        if (state == 6) [self publishError:self.player.error];
        if (state == 5 && self.segmentLooping) {
          [self.controller seekToTime:kCMTimeZero completion:^(BOOL success) {
            if (success) [weakSelf.controller play];
          }];
        }
      }
      if (self.progressHandler) self.progressHandler([self milliseconds:self.controller.currentTime],
          [self milliseconds:self.controller.duration], [self bufferedPositionMs]);
    }];
    [[NSRunLoop mainRunLoop] addTimer:_progressTimer forMode:NSRunLoopCommonModes];
    _session.changed = ^(SGPlaybackSession *session) {
      typeof(self) self = weakSelf;
      if (!self) return;
      const NSInteger states[] = {0, 1, 3, 4, 1, 5, 6};
      [self emitState:states[session.state]];
      if (session.error) [self publishError:session.error];
      if (self.progressHandler) self.progressHandler([self milliseconds:self.controller.currentTime],
          [self milliseconds:self.controller.duration], [self bufferedPositionMs]);
      self.player.audioRenderer.pitch = self.savedPitch;
      [self setRenderMode:self.renderMode];
      [self.controls refresh];
    };
  }
  return self;
}
- (SgPlatformView *)view { return self.containerView; }
- (void)setPresentationView:(SgPlatformView *)view { [self.features setPresentationView:view]; }
- (void)configureControls:(BOOL)enabled autoHide:(double)seconds fullscreen:(void (^)(void))fullscreen {
  self.controls.controlsEnabled = enabled;
#if TARGET_OS_OSX
  [self.controls attachKeyboardToView:enabled ? self.surface : nil];
#else
  if (enabled) [self.controls attachGesturesToView:self.surface];
#endif
  self.controls.autoHideInterval = seconds;
  __weak typeof(self) weakSelf = self;
  self.controls.toggleFullScreen = ^{
    [weakSelf.controller stopPictureInPicture];
    [weakSelf.features perform:@"presentation.restore" arguments:@{} completion:^(id result, NSError *error) { fullscreen(); }];
  };
}
- (int64_t)milliseconds:(CMTime)time {
  double seconds = CMTimeGetSeconds(time);
  return isfinite(seconds) ? (int64_t)(MAX(0, seconds) * 1000) : 0;
}
- (void)switchVideoSource:(NSString *)urlString autoPlay:(BOOL)autoPlay {
  self.segmentMode = NO;
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url.scheme.length) {
    [self publishError:[NSError errorWithDomain:@"SgNativePlayer" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Invalid absolute media URL"}]];
    [self emitState:6];
    return;
  }
  [self clearError];
  // Custom HTTP/FFmpeg options and pitch require FFmpeg; ordinary media uses SDK automatic selection.
  self.session.requiresFFmpeg = self.pendingDemuxerOptions.count > 0 || self.savedPitch != 1 || [self displayMode] != 0;
  if (self.session.requiresFFmpeg && self.controller.kernel != SGPlaybackKernelFFmpeg)
    [self.controller resetToKernel:SGPlaybackKernelFFmpeg];
  [self applyPendingDemuxerOptions];
  SGPlaybackRendition *rendition = [[SGPlaybackRendition alloc] initWithIdentifier:@"original" title:@"Original" URL:url];
  SGPlaybackItem *item = [[SGPlaybackItem alloc] initWithIdentifier:NSUUID.UUID.UUIDString title:@"Video" renditions:@[rendition]];
  NSError *error = nil;
  if (![self.session loadItems:@[item] startIndex:0 autoPlay:autoPlay error:&error]) [self publishError:error];
}
- (void)play { [self configurePlaybackAudioSessionIfNeeded]; [self.session play]; }
- (void)pause { [self.session pause]; }
- (void)stop { [self.session pause]; [self seekToMs:0]; }
- (void)seekToMs:(NSInteger)positionMs { [self.controller seekToTime:CMTimeMake(MAX(0,positionMs),1000) completion:^(BOOL success) {}]; }
- (void)setRate:(double)rate { self.controller.rate = rate; }
- (void)applySavedVolume { self.controller.volume = self.muted ? 0 : self.savedVolume; }
- (void)setLooping:(BOOL)looping { self.segmentLooping = looping; self.session.loopMode = looping ? SGPlaybackLoopModeOne : SGPlaybackLoopModeNone; }
- (NSArray<NSDictionary *> *)getAudioTracks {
  NSMutableArray *result = [NSMutableArray array];
  [self.controller.audioTrackTitles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger i, BOOL *stop) {
    [result addObject:@{@"index":@(i), @"label":title, @"language":NSNull.null, @"selected":@(self.controller.selectedAudioTrack == i)}];
  }];
  return result;
}
- (BOOL)selectAudioTrack:(NSInteger)index { return [self.controller selectAudioTrackAtIndex:index]; }
- (BOOL)isSeekable {
  if (self.controller.kernel == SGPlaybackKernelFFmpeg) return [self.player seekable];
  return self.controller.nativePlayer.currentItem.seekableTimeRanges.count > 0;
}
- (int64_t)bufferedPositionMs {
  if (self.controller.kernel == SGPlaybackKernelFFmpeg) return [self milliseconds:[self.player timeInfo].cached];
  int64_t end = 0;
  for (NSValue *value in self.controller.nativePlayer.currentItem.loadedTimeRanges)
    end = MAX(end, [self milliseconds:CMTimeRangeGetEnd(value.CMTimeRangeValue)]);
  return end;
}
- (BOOL)setPlaylist:(NSArray<NSString *> *)urls startIndex:(NSInteger)index autoPlay:(BOOL)autoPlay {
  self.session.requiresFFmpeg = self.pendingDemuxerOptions.count > 0 || self.savedPitch != 1 || [self displayMode] != 0;
  if (self.session.requiresFFmpeg && self.controller.kernel != SGPlaybackKernelFFmpeg)
    [self.controller resetToKernel:SGPlaybackKernelFFmpeg];
  [self applyPendingDemuxerOptions];
  NSMutableArray *items = [NSMutableArray array];
  for (NSString *text in urls) {
    NSURL *url = [NSURL URLWithString:text];
    if (!url.scheme.length) return NO;
    SGPlaybackRendition *r = [[SGPlaybackRendition alloc] initWithIdentifier:@"original" title:@"Original" URL:url];
    [items addObject:[[SGPlaybackItem alloc] initWithIdentifier:NSUUID.UUID.UUIDString title:@"Video" renditions:@[r]]];
  }
  self.segmentMode = NO;
  NSError *error = nil;
  BOOL ok = [self.session loadItems:items startIndex:index autoPlay:autoPlay error:&error];
  if (!ok) [self publishError:error];
  return ok;
}
- (BOOL)playNext { return [self.session next]; }
- (void)setAutomaticAdvance:(BOOL)enabled { self.session.automaticAdvance = enabled; }
- (NSDictionary *)diagnostics { return [self.session diagnostics]; }
- (BOOL)startPictureInPicture { NSError *error = nil; BOOL ok = [self.controller startPictureInPicture:&error]; if (!ok) [self publishError:error]; return ok; }
- (void)stopPictureInPicture { [self.controller stopPictureInPicture]; }
- (BOOL)isPictureInPictureActive { return self.controller.pictureInPictureActive; }
- (void)setDismissFullscreenHandler:(void (^)(void))handler {
  __weak typeof(self) weakSelf = self;
  self.controls.dismissPresentation = ^{
    [weakSelf.controller stopPictureInPicture];
    [weakSelf.features perform:@"presentation.restore" arguments:@{} completion:^(id result, NSError *error) { handler(); }];
  };
}
- (void)setFeatureEventHandler:(void (^)(NSDictionary *))handler { self.features.eventHandler = handler; }
- (void)performOperation:(NSString *)operation arguments:(NSDictionary *)arguments completion:(void (^)(id, NSError *))completion {
  if ([operation isEqual:@"session.load"]) {
    self.segmentMode = NO;
    self.session.requiresFFmpeg = self.session.requiresFFmpeg || self.pendingDemuxerOptions.count > 0 || self.savedPitch != 1 || [self displayMode] != 0;
    if (self.session.requiresFFmpeg && self.controller.kernel != SGPlaybackKernelFFmpeg) [self.controller resetToKernel:SGPlaybackKernelFFmpeg];
    [self applyPendingDemuxerOptions];
  }
  @try { [self.features perform:operation arguments:arguments completion:completion]; }
  @catch (NSException *exception) { completion(nil,[NSError errorWithDomain:@"kinetic_player.sg.arguments" code:1 userInfo:@{NSLocalizedDescriptionKey:exception.reason ?: @"Invalid feature arguments"}]); }
}
- (void)releasePlayer { [self.features close]; [self.progressTimer invalidate]; self.progressTimer = nil; self.session.changed = nil; [self.session close]; }
- (void)dealloc { [self releasePlayer]; }
- (void)applyPendingDemuxerOptions {
  if (!self.pendingDemuxerOptions.count) {
    return;
  }
  NSMutableDictionary *ffmpeg = [NSMutableDictionary dictionary];
  NSDictionary *extra = self.pendingDemuxerOptions[@"options"];
  if ([extra isKindOfClass:[NSDictionary class]]) {
    [ffmpeg addEntriesFromDictionary:extra];
  }
  NSNumber *timeout = self.pendingDemuxerOptions[@"timeoutMicros"];
  if ([timeout isKindOfClass:[NSNumber class]]) {
    ffmpeg[@"timeout"] = timeout;
  }
  NSNumber *reconnect = self.pendingDemuxerOptions[@"reconnect"];
  if ([reconnect isKindOfClass:[NSNumber class]]) {
    ffmpeg[@"reconnect"] = reconnect;
  }
  NSString *userAgent = self.pendingDemuxerOptions[@"userAgent"];
  if ([userAgent isKindOfClass:[NSString class]] && userAgent.length > 0) {
    ffmpeg[@"user-agent"] = userAgent;
  }
  NSDictionary *headers = self.pendingDemuxerOptions[@"headers"];
  if ([headers isKindOfClass:[NSDictionary class]] && headers.count > 0) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      [parts addObject:[NSString stringWithFormat:@"%@: %@", key, obj]];
    }];
    // FFmpeg expects headers separated by CRLF.
    ffmpeg[@"headers"] = [[parts componentsJoinedByString:@"\r\n"] stringByAppendingString:@"\r\n"];
  }
  if (ffmpeg.count > 0) {
    self.player.options.demuxer.options = ffmpeg;
  }
}

- (void)clearError {
  self.lastErrorMessage = nil;
  self.lastErrorCode = 0;
  if (self.errorHandler) {
    self.errorHandler(nil, 0);
  }
}

- (void)publishError:(NSError *)error {
  if (!error) {
    return;
  }
  self.lastErrorMessage = error.localizedDescription ?: error.domain;
  self.lastErrorCode = error.code;
  if (self.errorHandler) {
    self.errorHandler(self.lastErrorMessage, self.lastErrorCode);
  }
}

- (BOOL)replaceWithSegments:(NSArray<NSDictionary *> *)segments autoPlay:(BOOL)autoPlay {
  if (segments.count == 0) {
    return NO;
  }
  [self clearError];
  self.segmentMode = YES;
  self.session.requiresFFmpeg = YES;
  [self.controller resetToKernel:SGPlaybackKernelFFmpeg];
  [self applyPendingDemuxerOptions];

  SGMutableAsset *asset = [[SGMutableAsset alloc] init];
  SGMutableTrack *videoTrack = [asset addTrack:SGMediaTypeVideo];
  SGMutableTrack *audioTrack = [asset addTrack:SGMediaTypeAudio];

  for (NSDictionary *seg in segments) {
    NSString *urlString = seg[@"url"];
    if (![urlString isKindOfClass:[NSString class]] || urlString.length == 0) {
      continue;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
      continue;
    }
    NSInteger streamIndex = [seg[@"streamIndex"] respondsToSelector:@selector(integerValue)]
                                ? [seg[@"streamIndex"] integerValue]
                                : 0;
    CMTimeRange range = kCMTimeRangeZero;
    NSNumber *startMs = seg[@"startMs"];
    NSNumber *endMs = seg[@"endMs"];
    if ([startMs isKindOfClass:[NSNumber class]] || [endMs isKindOfClass:[NSNumber class]]) {
      int64_t start = [startMs isKindOfClass:[NSNumber class]] ? startMs.longLongValue : 0;
      CMTime startTime = CMTimeMake(start, 1000);
      if ([endMs isKindOfClass:[NSNumber class]]) {
        int64_t end = endMs.longLongValue;
        CMTime duration = CMTimeMake(MAX(0, end - start), 1000);
        range = CMTimeRangeMake(startTime, duration);
      } else {
        range = CMTimeRangeMake(startTime, kCMTimePositiveInfinity);
      }
    }
    SGURLSegment *segment =
        [[SGURLSegment alloc] initWithURL:url
                                    index:streamIndex
                                timeRange:range
                                    scale:CMTimeMake(1, 1)];
    [videoTrack appendSegment:segment];
    [audioTrack appendSegment:segment];
  }

  [self emitState:0];
  BOOL ok = [self.player replaceWithAsset:asset];
  [self applySavedVolume];
  self.player.audioRenderer.pitch = _savedPitch;
  if (ok && autoPlay) {
    [self.controller play];
  }
  return ok;
}

- (void)setVolume:(double)volume {
  Float64 clamped = fmax(0.0, fmin(volume, 1.0));
  if (clamped > 0.0) {
    _muted = NO;
  }
  _savedVolume = clamped;
  [self applySavedVolume];
}

- (void)setMuted:(BOOL)muted {
  _muted = muted;
  [self applySavedVolume];
}

- (void)setPitch:(double)pitch {
  // SGPlayer pitch is typically around 0.5–2.0; clamp gently.
  Float64 clamped = fmax(0.5, fmin(pitch, 2.0));
  _savedPitch = clamped;
  if (clamped != 1 && self.controller.kernel != SGPlaybackKernelFFmpeg) {
    self.session.requiresFFmpeg = YES;
    __weak typeof(self) weakSelf = self;
    [self.session switchToKernel:SGPlaybackKernelFFmpeg completion:^(BOOL success) {
      if (success) weakSelf.player.audioRenderer.pitch = weakSelf.savedPitch;
    }];
  } else { self.player.audioRenderer.pitch = clamped; }
}

- (double)currentPitch {
  return _savedPitch;
}

- (NSArray<NSDictionary *> *)tracksOfType:(SGMediaType)type labelPrefix:(NSString *)prefix {
  SGPlayerItem *item = [self.player currentItem];
  if (!item) {
    return @[];
  }
  NSArray<SGTrack *> *tracks = [SGTrack tracksWithTracks:item.tracks type:type];
  SGTrackSelection *selection =
      (type == SGMediaTypeAudio) ? item.audioSelection : item.videoSelection;
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  NSInteger index = 0;
  for (SGTrack *track in tracks) {
    BOOL selected = [selection.tracks containsObject:track];
    [result addObject:@{
      @"index" : @(index),
      @"label" : [NSString stringWithFormat:@"%@_%ld", prefix, (long)track.index],
      @"language" : [NSNull null],
      @"selected" : @(selected),
    }];
    index++;
  }
  return result;
}

- (BOOL)selectTrackAtIndex:(NSInteger)index type:(SGMediaType)type {
  SGPlayerItem *item = [self.player currentItem];
  if (!item) {
    return NO;
  }
  NSArray<SGTrack *> *tracks = [SGTrack tracksWithTracks:item.tracks type:type];
  if (index < 0 || index >= (NSInteger)tracks.count) {
    return NO;
  }
  SGTrack *track = tracks[(NSUInteger)index];
  SGTrackSelection *selection = [[SGTrackSelection alloc] init];
  selection.tracks = @[ track ];
  selection.weights = @[ @(1.0) ];
  if (type == SGMediaTypeAudio) {
    [item setAudioSelection:selection action:SGTrackSelectionActionTracks];
  } else {
    [item setVideoSelection:selection action:SGTrackSelectionActionTracks];
  }
  return YES;
}

- (NSArray<NSDictionary *> *)getVideoTracks {
  return [self tracksOfType:SGMediaTypeVideo labelPrefix:@"视频轨"];
}

- (BOOL)selectVideoTrack:(NSInteger)index {
  return [self selectTrackAtIndex:index type:SGMediaTypeVideo];
}

- (NSDictionary *)getVideoSize {
  CGSize presentationSize = self.controller.nativePlayer.currentItem.presentationSize;
  if (presentationSize.width > 0 && presentationSize.height > 0) return @{@"width":@((int)presentationSize.width),@"height":@((int)presentationSize.height)};
  SGPLFImage *image = [self.controller currentImage];
  if (image && image.size.width > 0 && image.size.height > 0) {
    return @{
      @"width" : @((int)image.size.width),
      @"height" : @((int)image.size.height),
    };
  }
  return nil;
}

- (NSData *)captureFrame {
  SGPLFImage *image = [self.controller currentImage];
  if (!image) {
    return nil;
  }
  NSData *pngData = nil;
#if TARGET_OS_OSX
  if ([image isKindOfClass:[NSImage class]]) {
    NSImage *nsImage = (NSImage *)image;
    CGImageRef cgImage = [nsImage CGImageForProposedRect:NULL context:nil hints:nil];
    if (cgImage) {
      NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
      pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    }
  }
#else
  pngData = UIImagePNGRepresentation(image);
#endif
  return pngData;
}

- (double)currentVolume {
  return self.controller.volume > 0 ? self.controller.volume : self.savedVolume;
}

- (BOOL)isMuted {
  return self.controller.volume <= 0;
}

- (void)setRenderMode:(NSInteger)mode {
  _renderMode = mode;
  self.controller.videoGravity = mode == 0 ? AVLayerVideoGravityResizeAspect : mode == 1 ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResize;
}

- (void)setDisplayMode:(NSInteger)mode {
  self.session.requiresFFmpeg = mode != 0;
  if (mode != 0 && self.controller.kernel != SGPlaybackKernelFFmpeg) {
    __weak typeof(self) weakSelf = self;
    [self.session switchToKernel:SGPlaybackKernelFFmpeg completion:^(BOOL success) {
      if (success) [weakSelf setDisplayMode:mode];
    }];
    return;
  }
  switch (mode) {
    case 1:
      self.player.videoRenderer.displayMode = SGDisplayModeVR;
      break;
    case 2:
      self.player.videoRenderer.displayMode = SGDisplayModeVRBox;
      break;
    default:
      self.player.videoRenderer.displayMode = SGDisplayModePlane;
      break;
  }
}

- (NSInteger)displayMode {
  switch (self.player.videoRenderer.displayMode) {
    case SGDisplayModeVR:
      return 1;
    case SGDisplayModeVRBox:
      return 2;
    default:
      return 0;
  }
}

- (void)setVrModeEnabled:(BOOL)enabled {
  [self setDisplayMode:enabled ? 1 : 0];
}

- (void)setVrViewport:(NSDictionary *)viewport {
  SGVRViewport *vp = self.player.videoRenderer.viewport;
  if (!vp) {
    return;
  }
  NSNumber *degrees = viewport[@"degrees"] ?: viewport[@"degress"];
  if ([degrees isKindOfClass:[NSNumber class]]) {
    vp.degress = degrees.doubleValue;
  }
  NSNumber *x = viewport[@"x"];
  if ([x isKindOfClass:[NSNumber class]]) {
    vp.x = x.doubleValue;
  }
  NSNumber *y = viewport[@"y"];
  if ([y isKindOfClass:[NSNumber class]]) {
    vp.y = y.doubleValue;
  }
  NSNumber *flipX = viewport[@"flipX"];
  if ([flipX isKindOfClass:[NSNumber class]]) {
    vp.flipX = flipX.boolValue;
  }
  NSNumber *flipY = viewport[@"flipY"];
  if ([flipY isKindOfClass:[NSNumber class]]) {
    vp.flipY = flipY.boolValue;
  }
  NSNumber *sensor = viewport[@"sensorEnable"];
  if ([sensor isKindOfClass:[NSNumber class]]) {
    vp.sensorEnable = sensor.boolValue;
  }
}

- (NSDictionary *)vrViewport {
  SGVRViewport *vp = self.player.videoRenderer.viewport;
  if (!vp) {
    return @{};
  }
  return @{
    @"degrees" : @(vp.degress),
    @"x" : @(vp.x),
    @"y" : @(vp.y),
    @"flipX" : @(vp.flipX),
    @"flipY" : @(vp.flipY),
    @"sensorEnable" : @(vp.sensorEnable),
  };
}

- (void)setDemuxerOptions:(NSDictionary *)options {
  NSMutableDictionary *merged =
      [NSMutableDictionary dictionaryWithDictionary:self.pendingDemuxerOptions ?: @{}];
  if ([options isKindOfClass:[NSDictionary class]]) {
    [merged addEntriesFromDictionary:options];
  }
  self.pendingDemuxerOptions = [merged copy];
  [self applyPendingDemuxerOptions];
}

- (void)setHttpRequestOptions:(NSDictionary *)options {
  NSMutableDictionary *merged =
      [NSMutableDictionary dictionaryWithDictionary:self.pendingDemuxerOptions ?: @{}];
  NSString *userAgent = options[@"userAgent"];
  if ([userAgent isKindOfClass:[NSString class]] && userAgent.length > 0) {
    merged[@"userAgent"] = userAgent;
  } else {
    [merged removeObjectForKey:@"userAgent"];
  }
  NSDictionary *headers = options[@"headers"];
  if ([headers isKindOfClass:[NSDictionary class]] && headers.count > 0) {
    merged[@"headers"] = headers;
  } else {
    [merged removeObjectForKey:@"headers"];
  }
  self.pendingDemuxerOptions = [merged copy];
  [self applyPendingDemuxerOptions];
}

- (void)setBackgroundPlaybackPolicy:(NSDictionary *)policy {
#if TARGET_OS_IOS || TARGET_OS_TV
  NSNumber *interrupted = policy[@"pausesWhenInterrupted"];
  if ([interrupted isKindOfClass:[NSNumber class]]) {
    self.player.pausesWhenInterrupted = interrupted.boolValue;
  }
  NSNumber *bg = policy[@"pausesWhenEnteredBackground"];
  if ([bg isKindOfClass:[NSNumber class]]) {
    self.player.pausesWhenEnteredBackground = bg.boolValue;
    self.wantsBackgroundPlayback = !bg.boolValue;
  }
  NSNumber *bgNoAudio = policy[@"pausesWhenEnteredBackgroundIfNoAudioTrack"];
  if ([bgNoAudio isKindOfClass:[NSNumber class]]) {
    self.player.pausesWhenEnteredBackgroundIfNoAudioTrack = bgNoAudio.boolValue;
  }
  if (self.wantsBackgroundPlayback) {
    [self configurePlaybackAudioSessionIfNeeded];
  }
#else
  (void)policy;
#endif
}

- (NSDictionary *)backgroundPlaybackPolicy {
#if TARGET_OS_IOS || TARGET_OS_TV
  return @{
    @"pausesWhenInterrupted" : @(self.player.pausesWhenInterrupted),
    @"pausesWhenEnteredBackground" : @(self.player.pausesWhenEnteredBackground),
    @"pausesWhenEnteredBackgroundIfNoAudioTrack" :
        @(self.player.pausesWhenEnteredBackgroundIfNoAudioTrack),
  };
#else
  return @{};
#endif
}

- (void)configurePlaybackAudioSessionIfNeeded {
#if TARGET_OS_IOS || TARGET_OS_TV
  NSError *error = nil;
  AVAudioSession *session = [AVAudioSession sharedInstance];
  if (![session setCategory:AVAudioSessionCategoryPlayback
                       mode:AVAudioSessionModeMoviePlayback
                    options:0
                      error:&error]) {
    NSLog(@"[SgNativePlayerBridge] AVAudioSession setCategory failed: %@", error);
  }
  if (![session setActive:YES error:&error]) {
    NSLog(@"[SgNativePlayerBridge] AVAudioSession setActive failed: %@", error);
  }
#endif
}

- (void)emitState:(NSInteger)state {
  if (self.stateHandler) {
    self.stateHandler(state);
  }
}

@end
