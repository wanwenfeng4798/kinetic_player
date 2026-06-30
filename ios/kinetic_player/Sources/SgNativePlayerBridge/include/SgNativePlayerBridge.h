#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SgStateChangedBlock)(NSInteger commonState);
typedef void (^SgProgressChangedBlock)(int64_t positionMs, int64_t durationMs);

@interface SgNativePlayerBridge : NSObject

@property (nonatomic, readonly) UIView *view;

- (instancetype)initWithStateHandler:(SgStateChangedBlock)stateHandler
                     progressHandler:(SgProgressChangedBlock)progressHandler;

- (void)setUrl:(NSString *)urlString;
- (void)play;
- (void)pause;
- (void)seekToMs:(NSInteger)positionMs;
- (void)setRenderMode:(NSInteger)mode;
- (void)setVrModeEnabled:(BOOL)enabled;
- (void)setSyncGroupId:(NSString *)syncGroupId;
- (void)releasePlayer;

@end

NS_ASSUME_NONNULL_END
