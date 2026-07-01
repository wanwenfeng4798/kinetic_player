#import "SgNativePlayerBridge.h"

#import <SGPlayer/SGPlayer.h>

@interface SgNativePlayerBridge ()

@property (nonatomic, copy) SgStateChangedBlock stateHandler;
@property (nonatomic, copy) SgProgressChangedBlock progressHandler;
@property (nonatomic, strong) SGPlayer *player;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, copy, nullable) NSString *syncGroupId;
@property (nonatomic, assign) BOOL vrModeEnabled;
@property (nonatomic, assign) BOOL looping;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) Float64 savedVolume;

@end

@implementation SgNativePlayerBridge

- (instancetype)initWithStateHandler:(SgStateChangedBlock)stateHandler
                     progressHandler:(SgProgressChangedBlock)progressHandler {
  self = [super init];
  if (self) {
    _stateHandler = [stateHandler copy];
    _progressHandler = [progressHandler copy];
    _containerView = [[UIView alloc] init];
    _containerView.backgroundColor = UIColor.blackColor;
    _savedVolume = 1.0;

    _player = [[SGPlayer alloc] init];
    _player.minimumTimeInfoInterval = 0.25;
    _player.videoRenderer.view = _containerView;
    _player.videoRenderer.scalingMode = SGScalingModeResizeAspect;
    _player.videoRenderer.displayMode = SGDisplayModePlane;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInfoChanged:)
                                                 name:SGPlayerDidChangeInfosNotification
                                               object:_player];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self releasePlayer];
}

- (UIView *)view {
  return _containerView;
}

- (void)switchVideoSource:(NSString *)urlString autoPlay:(BOOL)autoPlay {
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) {
    [self emitState:6];
    return;
  }
  [self emitState:0];
  [_player replaceWithURL:url];
  if (autoPlay) {
    [_player play];
  }
}

- (void)play {
  SGStateInfo stateInfo = [_player sstateInfo];
  if (stateInfo.playback & SGPlaybackStateFinished) {
    [self replayFromBeginning];
    return;
  }
  [_player play];
}

- (void)pause {
  [_player pause];
}

- (void)stop {
  [_player pause];
  [_player seekToTime:kCMTimeZero];
  [self emitState:0];
  if (self.progressHandler) {
    self.progressHandler(0, [self getDurationMs]);
  }
}

- (void)setRate:(double)rate {
  _player.rate = rate;
}

- (void)setVolume:(double)volume {
  Float64 clamped = fmax(0.0, fmin(volume, 1.0));
  if (clamped > 0.0) {
    _muted = NO;
  }
  _savedVolume = clamped;
  _player.audioRenderer.volume = _muted ? 0.0 : clamped;
}

- (void)setMuted:(BOOL)muted {
  _muted = muted;
  if (muted) {
    _player.audioRenderer.volume = 0.0;
  } else {
    _player.audioRenderer.volume = _savedVolume;
  }
}

- (NSArray<NSDictionary *> *)getAudioTracks {
  SGPlayerItem *item = [_player currentItem];
  if (!item) {
    return @[];
  }
  NSArray<SGTrack *> *audioTracks =
      [SGTrack tracksWithTracks:item.tracks type:SGMediaTypeAudio];
  SGTrackSelection *selection = item.audioSelection;
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  NSInteger index = 0;
  for (SGTrack *track in audioTracks) {
    BOOL selected = [selection.tracks containsObject:track];
    [result addObject:@{
      @"index" : @(index),
      @"label" : [NSString stringWithFormat:@"音轨_%ld", (long)track.index],
      @"language" : [NSNull null],
      @"selected" : @(selected),
    }];
    index++;
  }
  return result;
}

- (BOOL)selectAudioTrack:(NSInteger)index {
  SGPlayerItem *item = [_player currentItem];
  if (!item) {
    return NO;
  }
  NSArray<SGTrack *> *audioTracks =
      [SGTrack tracksWithTracks:item.tracks type:SGMediaTypeAudio];
  if (index < 0 || index >= (NSInteger)audioTracks.count) {
    return NO;
  }
  SGTrack *track = audioTracks[(NSUInteger)index];
  SGTrackSelection *selection = [[SGTrackSelection alloc] init];
  selection.tracks = @[ track ];
  selection.weights = @[ @(1.0) ];
  [item setAudioSelection:selection action:SGTrackSelectionActionTracks];
  return YES;
}

- (int64_t)getDurationMs {
  SGTimeInfo timeInfo = [_player timeInfo];
  if (CMTIME_IS_NUMERIC(timeInfo.duration)) {
    return (int64_t)(CMTimeGetSeconds(timeInfo.duration) * 1000.0);
  }
  SGPlayerItem *item = [_player currentItem];
  if (item && CMTIME_IS_NUMERIC(item.duration)) {
    return (int64_t)(CMTimeGetSeconds(item.duration) * 1000.0);
  }
  return 0;
}

- (int64_t)getCurrentPositionMs {
  SGTimeInfo timeInfo = [_player timeInfo];
  if (CMTIME_IS_NUMERIC(timeInfo.playback)) {
    return (int64_t)(CMTimeGetSeconds(timeInfo.playback) * 1000.0);
  }
  return 0;
}

- (NSDictionary *)getVideoSize {
  SGPlayerItem *item = [_player currentItem];
  if (!item) {
    return nil;
  }
  NSArray<SGTrack *> *videoTracks =
      [SGTrack tracksWithTracks:item.tracks type:SGMediaTypeVideo];
  SGTrack *videoTrack = videoTracks.firstObject;
  if (!videoTrack) {
    return nil;
  }
  // SGTrack only exposes stream index; use renderer snapshot dimensions when available.
  SGPLFImage *image = [_player.videoRenderer currentImage];
  if (image && image.size.width > 0 && image.size.height > 0) {
    return @{
      @"width" : @((int)image.size.width),
      @"height" : @((int)image.size.height),
    };
  }
  return nil;
}

- (void)setLooping:(BOOL)looping {
  _looping = looping;
  if (looping) {
    SGStateInfo stateInfo = [_player sstateInfo];
    if (stateInfo.playback & SGPlaybackStateFinished) {
      [self replayFromBeginning];
    }
  }
}

- (void)replayFromBeginning {
  __weak typeof(self) weakSelf = self;
  [_player seekToTime:kCMTimeZero
                result:^(CMTime time, NSError *error) {
                  if (error) {
                    return;
                  }
                  [weakSelf.player play];
                }];
}

- (NSString *)captureFrame {
  SGPLFImage *image = [_player.videoRenderer currentImage];
  if (!image) {
    return nil;
  }
  NSData *pngData = UIImagePNGRepresentation(image);
  if (!pngData) {
    return nil;
  }
  NSString *path = [NSTemporaryDirectory()
      stringByAppendingPathComponent:
          [NSString stringWithFormat:@"sg_frame_%lld.png",
                                     (long long)(NSDate.date.timeIntervalSince1970 * 1000)]];
  if (![pngData writeToFile:path atomically:YES]) {
    return nil;
  }
  return path;
}

- (double)currentVolume {
  return _muted ? _savedVolume : _player.audioRenderer.volume;
}

- (BOOL)isMuted {
  return _muted;
}

- (void)seekToMs:(NSInteger)positionMs {
  CMTime time = CMTimeMake(positionMs, 1000);
  [_player seekToTime:time];
}

- (void)setRenderMode:(NSInteger)mode {
  switch (mode) {
    case 0:
      _player.videoRenderer.scalingMode = SGScalingModeResizeAspect;
      break;
    case 1:
      _player.videoRenderer.scalingMode = SGScalingModeResizeAspectFill;
      break;
    default:
      _player.videoRenderer.scalingMode = SGScalingModeResize;
      break;
  }
}

- (void)setVrModeEnabled:(BOOL)enabled {
  _vrModeEnabled = enabled;
  _player.videoRenderer.displayMode = enabled ? SGDisplayModeVR : SGDisplayModePlane;
}

- (void)setSyncGroupId:(NSString *)syncGroupId {
  _syncGroupId = [syncGroupId copy];
  // SGPlayer has no public sync-group API; stored for future SDK hookup.
}

- (void)releasePlayer {
  [_player pause];
  _player = nil;
}

#pragma mark - Notifications

- (void)handleInfoChanged:(NSNotification *)notification {
  SGTimeInfo timeInfo = [SGPlayer timeInfoFromUserInfo:notification.userInfo];
  SGStateInfo stateInfo = [SGPlayer stateInfoFromUserInfo:notification.userInfo];
  SGInfoAction action = [SGPlayer infoActionFromUserInfo:notification.userInfo];

  if (action & SGInfoActionState) {
    [self emitState:[self mapCommonState:stateInfo]];
    if ((stateInfo.playback & SGPlaybackStateFinished) && self.looping) {
      [self replayFromBeginning];
    }
  }

  if (action & SGInfoActionTime) {
    int64_t positionMs = 0;
    int64_t durationMs = 0;
    if (CMTIME_IS_NUMERIC(timeInfo.playback)) {
      positionMs = (int64_t)(CMTimeGetSeconds(timeInfo.playback) * 1000.0);
    }
    if (CMTIME_IS_NUMERIC(timeInfo.duration)) {
      durationMs = (int64_t)(CMTimeGetSeconds(timeInfo.duration) * 1000.0);
    }
    if (self.progressHandler) {
      self.progressHandler(positionMs, durationMs);
    }
  }
}

#pragma mark - Mapping

- (NSInteger)mapCommonState:(SGStateInfo)state {
  if (state.player == SGPlayerStateFailed) {
    return 6;
  }
  if (state.player == SGPlayerStatePreparing) {
    return 1;
  }
  if (state.playback & SGPlaybackStateFinished) {
    return 5;
  }
  if (state.playback & SGPlaybackStatePlaying) {
    return 3;
  }
  if (state.loading == SGLoadingStateStalled) {
    return 1;
  }
  if (state.player == SGPlayerStateReady) {
    if (self.player.wantsToPlay) {
      return 4;
    }
    return 2;
  }
  return 0;
}

- (void)emitState:(NSInteger)state {
  if (self.stateHandler) {
    self.stateHandler(state);
  }
}

@end
