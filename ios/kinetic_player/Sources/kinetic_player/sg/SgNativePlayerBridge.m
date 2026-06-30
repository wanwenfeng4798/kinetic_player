#import "SgNativePlayerBridge.h"

#import <SGPlayer/SGPlayerHeader.h>

@interface SgNativePlayerBridge ()

@property (nonatomic, copy) SgStateChangedBlock stateHandler;
@property (nonatomic, copy) SgProgressChangedBlock progressHandler;
@property (nonatomic, strong) SGPlayer *player;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, copy, nullable) NSString *syncGroupId;
@property (nonatomic, assign) BOOL vrModeEnabled;

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

- (void)setUrl:(NSString *)urlString {
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) {
    [self emitState:6];
    return;
  }
  [self emitState:0];
  [_player replaceWithURL:url];
}

- (void)play {
  [_player play];
}

- (void)pause {
  [_player pause];
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
  [_player stop];
  _player = nil;
}

#pragma mark - Notifications

- (void)handleInfoChanged:(NSNotification *)notification {
  SGTimeInfo timeInfo = [SGPlayer timeInfoFromUserInfo:notification.userInfo];
  SGStateInfo stateInfo = [SGPlayer stateInfoFromUserInfo:notification.userInfo];
  SGInfoAction action = [SGPlayer infoActionFromUserInfo:notification.userInfo];

  if (action & SGInfoActionState) {
    [self emitState:[self mapCommonState:stateInfo]];
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
