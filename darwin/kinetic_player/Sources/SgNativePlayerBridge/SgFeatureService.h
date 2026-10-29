#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class SGPlaybackSession, SGPlaybackControls;
#if TARGET_OS_OSX
@class NSView;
#define SgFeatureView NSView
#else
@class UIView;
#define SgFeatureView UIView
#endif
/// Channel adapter only. All media processing and playback policy remain in SGPlayer.
@interface SgFeatureService : NSObject
- (instancetype)initWithSession:(SGPlaybackSession *)session controls:(SGPlaybackControls *)controls surface:(SgFeatureView *)surface container:(SgFeatureView *)container;
+ (BOOL)handleBackgroundSession:(NSString *)identifier completion:(void (^)(void))completion;
@property(nonatomic, copy, nullable) void (^eventHandler)(NSDictionary *event);
- (void)perform:(NSString *)operation arguments:(NSDictionary *)arguments completion:(void (^)(id _Nullable, NSError * _Nullable))completion;
- (void)close;
@end
NS_ASSUME_NONNULL_END
