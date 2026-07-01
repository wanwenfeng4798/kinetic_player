#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SgStateChangedBlock)(NSInteger commonState);
typedef void (^SgProgressChangedBlock)(int64_t positionMs, int64_t durationMs);

@interface SgNativePlayerBridge : NSObject

@property (nonatomic, readonly) UIView *view;

- (instancetype)initWithStateHandler:(SgStateChangedBlock)stateHandler
                     progressHandler:(SgProgressChangedBlock)progressHandler;

- (void)switchVideoSource:(NSString *)urlString autoPlay:(BOOL)autoPlay;
- (void)play;
- (void)pause;
- (void)stop;
- (void)seekToMs:(NSInteger)positionMs;
- (void)setRenderMode:(NSInteger)mode;
- (void)setRate:(double)rate;
- (void)setVolume:(double)volume;
- (void)setMuted:(BOOL)muted;
- (NSArray<NSDictionary *> *)getAudioTracks;
- (BOOL)selectAudioTrack:(NSInteger)index;
- (NSDictionary * _Nullable)getVideoSize;
- (void)setLooping:(BOOL)looping;
- (NSString * _Nullable)captureFrame;
- (double)currentVolume;
- (BOOL)isMuted;
- (void)setVrModeEnabled:(BOOL)enabled;
- (void)setSyncGroupId:(NSString *)syncGroupId;
- (void)releasePlayer;

@end

NS_ASSUME_NONNULL_END
