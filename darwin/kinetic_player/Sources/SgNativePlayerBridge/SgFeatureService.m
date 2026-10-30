#import "SgFeatureService.h"
#import <SGPlayer/SGPlaybackSession.h>
#import <SGPlayer/SGPlaybackControls.h>
#import <SGPlayer/SGPlaybackCapabilities.h>
#import <SGPlayer/SGPlaybackPresentation.h>
#import <SGPlayer/SGMediaCache.h>
#import <SGPlayer/SGHLSAssetStore.h>
#import <SGPlayer/SGMediaTranscoder.h>
#import <SGPlayer/SGTimelinePreview.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSError *SgFeatureError(NSString *message) {
  return [NSError errorWithDomain:@"kinetic_player.sg" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}
static NSURL *SgURL(id value) {
  if (![value isKindOfClass:NSString.class] || ![value length]) return nil;
  NSURL *url = [NSURL URLWithString:value];
  return url.scheme.length ? url : [NSURL fileURLWithPath:value];
}
static CMTime SgTime(id value) { return CMTimeMake([value longLongValue], 1000); }
static CGRect SgRect(NSDictionary *value) {
  return CGRectMake([value[@"x"] doubleValue], [value[@"y"] doubleValue], [value[@"width"] doubleValue], [value[@"height"] doubleValue]);
}
static NSDictionary *SgRectMap(CGRect r) { return @{ @"x":@(r.origin.x), @"y":@(r.origin.y), @"width":@(r.size.width), @"height":@(r.size.height) }; }
static NSDictionary *SgRangeMap(CMTimeRange range) {
  double start = CMTimeGetSeconds(range.start), duration = CMTimeGetSeconds(range.duration);
  return @{ @"startMs":@(isfinite(start) ? llround(start * 1000) : 0), @"durationMs":@(isfinite(duration) ? llround(duration * 1000) : 0) };
}
static NSData *SgPNG(CIImage *image) {
  if (!image) return nil;
  CIContext *context = [CIContext contextWithOptions:nil];
  CGImageRef cg = [context createCGImage:image fromRect:image.extent];
  if (!cg) return nil;
  NSMutableData *data = [NSMutableData data];
  CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, (__bridge CFStringRef)UTTypePNG.identifier, 1, nil);
  if (destination) { CGImageDestinationAddImage(destination, cg, nil); if (!CGImageDestinationFinalize(destination)) data = nil; CFRelease(destination); }
  CGImageRelease(cg);
  return data;
}

@interface SgFeatureService ()
@property(nonatomic, strong) SGPlaybackSession *session;
@property(nonatomic, strong) SGPlaybackControls *controls;
@property(nonatomic, weak) SgFeatureView *surface;
@property(nonatomic, strong) SGPlaybackPresentation *presentation;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *workers;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *jobs;
@property(nonatomic, strong) SGMediaCache *cache;
@property(nonatomic, strong) SGHLSAssetStore *hls;
@property(nonatomic, strong) NSMutableDictionary<NSString *, SGTimelinePreview *> *previews;
@property(nonatomic, strong) NSMutableDictionary<NSString *, SGTimelineSpriteIndex *> *sprites;
@property(nonatomic) BOOL closed;
@property(nonatomic, strong) NSMutableDictionary<NSString *, void (^)(BOOL)> *restoreRequests;
@property(nonatomic) NSUInteger coverRevision;
@property(nonatomic) NSUInteger danmakuRevision;
@property(nonatomic, strong) NSURLSessionDataTask *coverTask;
@end

static NSMutableDictionary<NSString *, SGHLSAssetStore *> *SgHLSStores;
static NSMutableDictionary<NSString *, void (^)(void)> *SgHLSCompletions;
static NSMapTable<NSString *, SgFeatureService *> *SgHLSOwners;

@implementation SgFeatureService
+ (BOOL)handleBackgroundSession:(NSString *)identifier completion:(void (^)(void))completion {
  // Only claim sessions opened by this plugin, or its documented relaunch namespace.
  if (!SgHLSStores[identifier] && ![identifier hasPrefix:@"kinetic_player.hls."]) return NO;
  if (!SgHLSCompletions) SgHLSCompletions = [NSMutableDictionary dictionary];
  SgHLSCompletions[identifier] = [completion copy];
  if (!SgHLSStores) SgHLSStores = [NSMutableDictionary dictionary];
  if (!SgHLSStores[identifier] && [SGHLSAssetStore isSupported]) {
    SGHLSAssetStore *store = [[SGHLSAssetStore alloc] initWithBackgroundIdentifier:identifier metadataStore:NSUserDefaults.standardUserDefaults];
    if (store) {
      SgHLSStores[identifier] = store;
      store.backgroundEventsFinished = ^{
        void (^pending)(void) = SgHLSCompletions[identifier];
        [SgHLSCompletions removeObjectForKey:identifier]; if (pending) pending();
      };
      [store restoreTasksWithCompletion:^{}];
    }
  }
  if (!SgHLSStores[identifier]) { [SgHLSCompletions removeObjectForKey:identifier]; return NO; }
  return YES;
}
- (void)emit:(NSDictionary *)event { if (!self.closed && self.eventHandler) self.eventHandler(event); }

+ (SGPlaybackCoordinator *)coordinator {
  static SGPlaybackCoordinator *value; static dispatch_once_t once;
  dispatch_once(&once, ^{ value = [SGPlaybackCoordinator new]; }); return value;
}
- (instancetype)initWithSession:(SGPlaybackSession *)session controls:(SGPlaybackControls *)controls surface:(SgFeatureView *)surface container:(SgFeatureView *)container {
  if ((self = [super init])) {
    _session = session; _controls = controls; _surface = surface;
    session.controller.pictureInPictureView=container;
    __weak typeof(self) eventSelf = self;
    session.controller.pictureInPictureChanged = ^(BOOL active, NSError *failure) {
      [eventSelf emit:@{@"type":@"pip",@"active":@(active),@"error":failure.localizedDescription ?: NSNull.null}];
    };
    session.controller.restoreInterface = ^(void (^completion)(BOOL)) {
      SgFeatureService *self = eventSelf;
      if (!self || self.closed) { completion(NO); return; }
      [self.presentation restore]; [self.controls revealControls];
      NSString *request = NSUUID.UUID.UUIDString;
      self.restoreRequests[request] = [completion copy];
      [self emit:@{@"type":@"pipRestore",@"requestId":request}];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        void (^pending)(BOOL) = eventSelf.restoreRequests[request];
        [eventSelf.restoreRequests removeObjectForKey:request]; if (pending) pending(NO);
      });
    };
    _presentation = [[SGPlaybackPresentation alloc] initWithSurface:container];
    _restoreRequests = [NSMutableDictionary dictionary];
    _workers = [NSMutableDictionary dictionary]; _jobs = [NSMutableDictionary dictionary];
    _previews = [NSMutableDictionary dictionary]; _sprites = [NSMutableDictionary dictionary];
    [[self.class coordinator] registerSession:session];
    __weak typeof(self) weakSelf = self;
    controls.screenshotCaptured = ^(SGPLFImage *image) {
#if TARGET_OS_OSX
      CGImageRef cg = [image CGImageForProposedRect:NULL context:nil hints:nil];
#else
      CGImageRef cg = image.CGImage;
#endif
      NSData *png = cg ? SgPNG([CIImage imageWithCGImage:cg]) : nil;
      if (png) [weakSelf emit:@{@"type":@"screenshot",@"bytes":png}];
    };
    controls.toggleFloatingWindow = ^{ [weakSelf toggleFloating]; };
    controls.dismissPresentation = ^{ [weakSelf.presentation restore]; };
  } return self;
}
- (void)setPresentationView:(SgFeatureView *)view {
  [self.session.controller stopPictureInPicture];
  [self.presentation restore];
  self.presentation=[[SGPlaybackPresentation alloc]initWithSurface:view];
  self.session.controller.pictureInPictureView=view;
}
- (SgFeatureView *)windowContent {
#if TARGET_OS_OSX
  return self.controls.window.contentView;
#else
  return self.controls.window;
#endif
}
- (void)toggleFloating {
  if (self.presentation.mode != SGPlaybackPresentationModeInline) { [self.presentation restore]; return; }
  SgFeatureView *host = [self windowContent];
  if (host) [self.presentation showFloatingInView:host frame:CGRectMake(16, 16, MIN(400, host.bounds.size.width), 225)];
}
- (NSURLRequest *)request:(NSDictionary *)a {
  NSURL *url = SgURL(a[@"url"]); if (!url) return nil;
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  NSDictionary *headers = a[@"headers"];
  for (NSString *key in headers) [request setValue:headers[key] forHTTPHeaderField:key];
  return request;
}
- (NSString *)job:(id)worker {
  NSString *identifier = NSUUID.UUID.UUIDString;
  self.workers[identifier] = worker;
  self.jobs[identifier] = @{@"id":identifier, @"state":@"running", @"progress":@0};
  return identifier;
}
- (void)progress:(NSString *)identifier value:(double)value {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.closed || !self.workers[identifier]) return;
    self.jobs[identifier] = @{@"id":identifier, @"state":@"running", @"progress":@(isfinite(value) ? value : 0)};
  });
}
- (void)finish:(NSString *)identifier result:(id)result error:(NSError *)error {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.closed) return;
    id worker = self.workers[identifier];
    BOOL cancelled = ([worker respondsToSelector:@selector(cancelled)] && [worker cancelled]) || error.code == NSURLErrorCancelled;
    self.jobs[identifier] = @{@"id":identifier, @"state":cancelled ? @"cancelled" : error ? @"failed" : @"completed", @"progress":@1,
      @"result":result ?: NSNull.null, @"error":error.localizedDescription ?: NSNull.null, @"code":@(error.code)};
    [self.workers removeObjectForKey:identifier];
    [self emit:@{@"type":@"job",@"job":self.jobs[identifier]}];
  });
}
- (void)perform:(NSString *)op arguments:(NSDictionary *)a completion:(void (^)(id, NSError *))done {
  NSAssert(NSThread.isMainThread, @"SGPlayer feature API requires main thread");
  if (self.closed) { done(nil, SgFeatureError(@"Player disposed")); return; }
  NSError *error = nil;
  SGPlaybackController *controller = self.session.controller;
  SGMediaEffects *effects = controller.effects;
  if ([op isEqual:@"pip.restoreComplete"]) {
    void (^completion)(BOOL) = self.restoreRequests[a[@"requestId"]];
    [self.restoreRequests removeObjectForKey:a[@"requestId"]];
    if (completion) completion([a[@"restored"] boolValue]); done(@(completion != nil),nil); return;
  }
  if ([op isEqual:@"capabilities"]) { done([SGPlaybackCapabilities snapshot], nil); return; }
  if ([op isEqual:@"session.load"]) {
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *item in a[@"items"]) {
      NSMutableArray *renditions = [NSMutableArray array];
      for (NSDictionary *r in item[@"renditions"]) {
        NSURL *url = SgURL(r[@"url"]);
        if (!url || ![r[@"id"] length]) { done(nil,SgFeatureError(@"Rendition requires id and URL")); return; }
        [renditions addObject:[[SGPlaybackRendition alloc] initWithIdentifier:r[@"id"] title:r[@"title"] ?: @"Original" URL:url]];
      }
      if (![item[@"id"] length]) { done(nil,SgFeatureError(@"Item requires a stable id")); return; }
      [items addObject:[[SGPlaybackItem alloc] initWithIdentifier:item[@"id"] title:item[@"title"] ?: @"Video" renditions:renditions]];
    }
    BOOL ok = [self.session loadItems:items startIndex:[a[@"startIndex"] integerValue] autoPlay:[a[@"autoPlay"] boolValue] error:&error]; done(@(ok),error); return;
  }
  if ([op isEqual:@"session.configure"]) {
    if ((a[@"kernelPolicy"] && ([a[@"kernelPolicy"] integerValue] < 0 || [a[@"kernelPolicy"] integerValue] > 3)) ||
        (a[@"loopMode"] && ([a[@"loopMode"] integerValue] < 0 || [a[@"loopMode"] integerValue] > 2))) { done(nil,SgFeatureError(@"Invalid kernel policy or loop mode")); return; }
    if (a[@"kernelPolicy"]) self.session.kernelPolicy = [a[@"kernelPolicy"] integerValue];
    if (a[@"requiresFFmpeg"]) self.session.requiresFFmpeg = [a[@"requiresFFmpeg"] boolValue];
    if (a[@"loopMode"]) self.session.loopMode = [a[@"loopMode"] integerValue];
    if (a[@"resumeEnabled"]) self.session.resumeEnabled = [a[@"resumeEnabled"] boolValue];
    if (a[@"automaticAdvance"]) self.session.automaticAdvance = [a[@"automaticAdvance"] boolValue];
    if (a[@"loadingTimeout"]) self.session.loadingTimeout = [a[@"loadingTimeout"] doubleValue];
  } else if ([op isEqual:@"ads.play"]) {
    NSURL *url = SgURL(a[@"url"]); double skip = [a[@"skipAfterMs"] doubleValue] / 1000;
    if (!url || !isfinite(skip) || skip < 0) { done(nil,SgFeatureError(@"Ad requires URL and nonnegative skip delay")); return; }
    BOOL started = [a[@"fromBeginning"] boolValue] ? [self.session playPreRollAdvertisementWithURL:url skipAfter:skip] : [self.session playAdvertisementWithURL:url skipAfter:skip];
    done(started ? @YES : @NO,nil); return;
  } else if ([op isEqual:@"ads.schedule"]) {
    NSMutableArray *ads = [NSMutableArray array];
    for (NSDictionary *value in a[@"items"]) {
      NSURL *url = SgURL(value[@"url"]); double time = [value[@"positionMs"] doubleValue] / 1000, skip = [value[@"skipAfterMs"] doubleValue] / 1000;
      if (!url || !isfinite(time) || time < 0 || !isfinite(skip) || skip < 0) { done(nil,SgFeatureError(@"Invalid advertisement schedule")); return; }
      [ads addObject:[[SGPlaybackAdvertisement alloc] initWithURL:url atTime:CMTimeMakeWithSeconds(time,1000) skipAfter:skip]];
    }
    self.session.advertisements = ads;
  } else if ([op isEqual:@"ads.skip"]) { done(@([self.session skipAdvertisement]),nil); return;
  } else if ([op isEqual:@"ads.status"]) {
    done(@{@"active":@(self.session.advertisementActive),@"canSkip":@(self.session.canSkipAdvertisement),@"skipRemaining":@(self.session.advertisementSkipRemaining)},nil); return;
  } else if ([op isEqual:@"session.selectItem"]) { done(@([self.session selectItemAtIndex:[a[@"index"] integerValue]]),nil); return;
  } else if ([op isEqual:@"session.next"]) { done(@([self.session next]),nil); return;
  } else if ([op isEqual:@"session.previous"]) { done(@([self.session previous]),nil); return;
  } else if ([op isEqual:@"session.rendition"]) {
    [self.session selectRenditionAtIndex:[a[@"index"] integerValue] completion:^(BOOL ok) { done(@(ok), ok ? nil : SgFeatureError(@"Rendition switch failed")); }]; return;
  } else if ([op isEqual:@"session.kernel"]) {
    NSInteger kernel = [a[@"kernel"] integerValue];
    if (kernel < 0 || kernel > 1) { done(nil,SgFeatureError(@"Unknown kernel")); return; }
    [self.session switchToKernel:kernel completion:^(BOOL ok) { done(@(ok),ok ? nil : SgFeatureError(@"Kernel switch failed")); }]; return;
  } else if ([op isEqual:@"session.loopRange"]) { done(@([self.session setLoopFrom:SgTime(a[@"startMs"]) to:SgTime(a[@"endMs"])]),nil); return;
  } else if ([op isEqual:@"session.clearLoop"]) { [self.session clearLoop];
  } else if ([op isEqual:@"session.retry"]) { [self.session retry];
  } else if ([op isEqual:@"session.saveResume"]) { [self.session saveResumePosition];
  } else if ([op isEqual:@"session.diagnostics"]) { done([self.session diagnostics],nil); return;
  } else if ([op isEqual:@"session.exportDiagnostics"]) {
    NSURL *url = SgURL(a[@"destination"]); if (!url.isFileURL) { done(nil,SgFeatureError(@"Destination must be a local file URL")); return; }
    BOOL ok = [self.session exportDiagnosticsToURL:url error:&error]; done(@(ok),error); return;
  } else if ([op isEqual:@"coordinator.activate"]) { [[self.class coordinator] activateSession:self.session];
  } else if ([op isEqual:@"coordinator.pauseAll"]) { [[self.class coordinator] pauseAll];
  } else if ([op isEqual:@"native.policy"]) {
    SGNativePlaybackPolicy *policy = [controller.nativePlaybackPolicy copy];
    NSArray *keys = @[@"preferredPeakBitRate",@"preferredForwardBufferDuration",@"automaticallyWaitsToMinimizeStalling",@"allowsNetworkWhilePaused"];
    for (NSString *key in keys) if (a[key]) [policy setValue:a[key] forKey:key];
    if (a[@"maximumWidth"] || a[@"maximumHeight"]) policy.preferredMaximumResolution = CGSizeMake([a[@"maximumWidth"] doubleValue],[a[@"maximumHeight"] doubleValue]);
    BOOL ok = [controller applyNativePlaybackPolicy:policy error:&error]; done(@(ok),error); return;
  } else if ([op isEqual:@"native.metrics"]) { done(controller.nativePlaybackMetrics,nil); return;
  } else if ([op isEqual:@"subtitles.load"]) {
    NSURL *url = SgURL(a[@"url"]); if (!url) { done(nil,SgFeatureError(@"Subtitle URL required")); return; }
    [controller loadSubtitlesFromURL:url completion:^(NSError *failure) { done(nil,failure); }]; return;
  } else if ([op isEqual:@"subtitles.read"]) {
    NSURL *url = SgURL(a[@"url"]); if (!url) { done(nil,SgFeatureError(@"Subtitle URL required")); return; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
      NSError *failure = nil; NSArray *tracks = [SGSubtitleReader readURL:url error:&failure];
      NSMutableArray *result = [NSMutableArray array];
      for (SGSubtitleTrack *track in tracks) {
        NSMutableArray *cues = [NSMutableArray array];
        for (SGSubtitleCue *cue in track.cues) {
          [cues addObject:@{@"range":SgRangeMap(CMTimeRangeMake(cue.start,cue.duration)),@"text":cue.text ?: @"",@"ass":cue.ASS ?: NSNull.null,@"region":SgRectMap(cue.region),@"bitmapPNG":cue.bitmap ? SgPNG(cue.bitmap) ?: NSNull.null : NSNull.null}];
        }
        [result addObject:@{@"index":@(track.index),@"title":track.title ?: @"",@"language":track.language ?: @"",@"default":@(track.defaultTrack),@"forced":@(track.forced),@"cues":cues,@"fonts":track.fonts ?: @{},@"assHeader":track.ASSHeader ?: NSNull.null}];
      }
      dispatch_async(dispatch_get_main_queue(), ^{ done(failure ? nil : result,failure); });
    }); return;
  } else if ([op isEqual:@"subtitles.tracks"]) {
    NSMutableArray *tracks = [NSMutableArray array];
    for (SGSubtitleTrack *track in controller.subtitleTracks) [tracks addObject:@{@"index":@(track.index),@"title":track.title ?: @"",@"language":track.language ?: @"",@"default":@(track.defaultTrack),@"forced":@(track.forced)}];
    done(@{@"tracks":tracks,@"selected":@(controller.selectedSubtitleTrack),@"secondary":@(controller.selectedSecondarySubtitleTrack)},nil); return;
  } else if ([op isEqual:@"subtitles.select"]) {
    BOOL ok = [a[@"secondary"] boolValue] ? [controller selectSecondarySubtitleTrack:[a[@"index"] integerValue]] : [controller selectSubtitleTrack:[a[@"index"] integerValue]]; done(@(ok),nil); return;
  } else if ([op isEqual:@"effects.configure"]) {
    for (NSString *key in @[@"watermarksEnabled",@"subtitlesEnabled",@"subtitleOffset",@"secondarySubtitleOffset",@"subtitleVerticalPosition",@"secondarySubtitleVerticalPosition",@"danmakuEnabled",@"maximumDanmakuCount",@"textSize",@"textColorRGB",@"textBackgroundEnabled",@"textBackgroundColorRGB",@"textBackgroundOpacity",@"overlayOpacity",@"softwareRendering",@"stickerStart"]) if (a[key]) [effects setValue:a[key] forKey:key];
    if (a[@"subtitleFallbackFontURL"]) effects.subtitleFallbackFontURL = SgURL(a[@"subtitleFallbackFontURL"]);
    if (a[@"stickerRect"]) effects.stickerRect = SgRect(a[@"stickerRect"]);
  } else if ([op isEqual:@"effects.filter"]) {
    SGFilterConfiguration *filter = a[@"cubeText"] ? [SGFilterConfiguration configurationWithCubeText:a[@"cubeText"] error:&error] : [SGFilterConfiguration new];
    if (!filter) { done(nil,error); return; }
    for (NSString *key in @[@"brightness",@"contrast",@"saturation",@"grayscale",@"horizontalFlip",@"verticalFlip",@"blurRadius",@"colorCubeDimension",@"bloomRadius",@"bloomIntensity"]) if (a[key]) [filter setValue:a[key] forKey:key];
    for (NSString *key in @[@"colorCurves",@"colorCube"]) if (a[key]) {
      NSMutableData *samples = [NSMutableData data]; for (NSNumber *sample in a[key]) { float value = sample.floatValue; [samples appendBytes:&value length:sizeof(value)]; } [filter setValue:samples forKey:key];
    }
    error = filter.validationError; if (!error) effects.filter = filter;
  } else if ([op isEqual:@"effects.subtitles"]) {
    NSMutableArray *cues = [NSMutableArray array];
    for (NSDictionary *value in a[@"cues"]) {
      SGSubtitleCue *cue = [SGSubtitleCue new]; cue.start = SgTime(value[@"startMs"]); cue.duration = SgTime(value[@"durationMs"]);
      cue.text = value[@"text"] ?: @""; cue.ASS = value[@"ass"];
      if (value[@"region"]) cue.region = SgRect(value[@"region"]);
      if (value[@"bitmapURL"]) { NSURL *url = SgURL(value[@"bitmapURL"]); if (!url.isFileURL) { done(nil,SgFeatureError(@"Subtitle bitmap must be local")); return; } cue.bitmap = [CIImage imageWithContentsOfURL:url]; }
      [cues addObject:cue];
    }
    [controller selectSubtitleTrack:-1];[controller selectSecondarySubtitleTrack:-1];
    effects.subtitles = cues;
  } else if ([op isEqual:@"effects.danmakuLoad"]) {
    NSURL *url = SgURL(a[@"url"]); if (!url) { done(nil,SgFeatureError(@"Danmaku URL required")); return; }
    NSUInteger revision=++self.danmakuRevision;
    [controller loadDanmakuFromURL:url completion:^(NSError *failure) {
      if(self.closed||revision!=self.danmakuRevision){done(nil,SgFeatureError(@"Danmaku load superseded"));return;}
      done(failure ? nil : @(effects.danmaku.count),failure);
    }];return;
  } else if ([op isEqual:@"effects.danmaku"]) {
    self.danmakuRevision++;
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *value in a[@"items"]) { SGDanmakuItem *item = [SGDanmakuItem new]; item.text = value[@"text"] ?: @""; item.start = SgTime(value[@"startMs"]); item.duration = [value[@"durationMs"] doubleValue]/1000; item.mode = [value[@"mode"] integerValue]; if(value[@"color"])item.rgbColor=[value[@"color"] unsignedIntegerValue]&0xffffff; if(value[@"fontSize"])item.fontSize=[value[@"fontSize"] doubleValue]; [items addObject:item]; }
    effects.danmaku = items; effects.danmakuEnabled = YES;
  } else if ([op isEqual:@"effects.watermarks"]) {
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *value in a[@"items"]) { SGWatermark *item = [SGWatermark new]; item.text = value[@"text"] ?: @""; item.rect = SgRect(value[@"rect"]); item.opacity = value[@"opacity"] ? [value[@"opacity"] doubleValue] : 1;
      if (value[@"imageURL"]) { NSURL *url = SgURL(value[@"imageURL"]); if (!url.isFileURL) { done(nil,SgFeatureError(@"Watermark image must be downloaded to a local file")); return; } item.image = [CIImage imageWithContentsOfURL:url]; if (!item.image) { done(nil,SgFeatureError(@"Invalid watermark image")); return; } } [items addObject:item]; }
    effects.watermarks = items; effects.watermarksEnabled = YES;
  } else if ([op isEqual:@"effects.sticker"]) {
    if (!a[@"url"]) { effects.sticker = nil; done(nil,nil); return; }
    NSURL *url = SgURL(a[@"url"]); if (!url.isFileURL) { done(nil,SgFeatureError(@"Sticker must be a local file")); return; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
      NSError *failure = nil; SGAnimatedImage *image = [SGAnimatedImage imageWithURL:url maxDecodedBytes:a[@"maximumBytes"] ? [a[@"maximumBytes"] unsignedIntegerValue] : 64*1024*1024 error:&failure];
      dispatch_async(dispatch_get_main_queue(), ^{ if (!self.closed && image) effects.sticker = image; done(image ? @{@"duration":@(image.duration),@"frameCount":@(image.frameCount),@"loopCount":@(image.loopCount)} : nil,failure); });
    }); return;
  } else if ([op isEqual:@"effects.compose"]) {
    NSURL *url = SgURL(a[@"imageURL"]); if (!url.isFileURL) { done(nil,SgFeatureError(@"Composition image must be local")); return; }
    SGMediaEffects *snapshot = [effects snapshot];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
      CIImage *image = [CIImage imageWithContentsOfURL:url];
      NSData *png = image ? SgPNG([snapshot composeImage:image atTime:SgTime(a[@"timeMs"])]) : nil;
      dispatch_async(dispatch_get_main_queue(), ^{ done(png,png ? nil : SgFeatureError(@"Image composition failed")); });
    }); return;
  } else if ([op isEqual:@"effects.flush"]) { [effects flush];
  } else if ([op isEqual:@"effects.status"]) { done(@{@"active":@(effects.active),@"subtitlesEnabled":@(effects.subtitlesEnabled),@"subtitleCount":@(effects.subtitles.count),@"danmakuEnabled":@(effects.danmakuEnabled),@"danmakuCount":@(effects.danmaku.count),@"watermarksEnabled":@(effects.watermarksEnabled),@"watermarkCount":@(effects.watermarks.count),@"error":effects.lastError.localizedDescription ?: NSNull.null},nil); return;
  } else if ([op isEqual:@"controls.preview.load"]) {
    [self.controls loadTimelineSpritesFromURL:SgURL(a[@"url"]) completion:^(NSError *failure) { done(nil,failure); }]; return;
  } else if ([op isEqual:@"controls.preview.image"]) {
    [self.controls timelineImageAtTime:SgTime(a[@"timeMs"]) completion:^(SGPLFImage *image,NSError *failure) {
#if TARGET_OS_OSX
      CGImageRef cg = image ? [image CGImageForProposedRect:NULL context:nil hints:nil] : nil;
#else
      CGImageRef cg = image.CGImage;
#endif
      done(cg ? SgPNG([CIImage imageWithCGImage:cg]) : nil,failure);
    }]; return;
  } else if ([op isEqual:@"controls.configure"]) {
    if (a[@"previewVttUrl"]) [self.controls loadTimelineSpritesFromURL:SgURL(a[@"previewVttUrl"]) completion:^(NSError *failure) { if (failure) [self emit:@{@"type":@"previewError",@"error":failure.localizedDescription}]; }];
    if (a[@"enabled"]) self.controls.controlsEnabled = [a[@"enabled"] boolValue];
    if (a[@"keepLastFrameWhenComplete"]) self.controls.keepLastFrameWhenComplete = [a[@"keepLastFrameWhenComplete"] boolValue];
    if (a[@"automaticPictureInPictureEnabled"]) controller.automaticPictureInPictureEnabled = [a[@"automaticPictureInPictureEnabled"] boolValue];
    if (a[@"showVolumeToolbar"]) self.controls.showsVolumeControl = [a[@"showVolumeToolbar"] boolValue];
    if (a[@"showSettingsButton"]) self.controls.showsSettingsControl = [a[@"showSettingsButton"] boolValue];
    if (a[@"showFullscreenButton"]) self.controls.showsFullscreenControl = [a[@"showFullscreenButton"] boolValue];
    if (a[@"showLockButton"]) self.controls.showsLockControl = [a[@"showLockButton"] boolValue];

    if (a[@"locked"]) self.controls.controlsLocked = [a[@"locked"] boolValue];
    if (a[@"showsKernelSelection"]) self.controls.showsKernelSelection = [a[@"showsKernelSelection"] boolValue];
    if (a[@"autoHideInterval"]) self.controls.autoHideInterval = [a[@"autoHideInterval"] doubleValue];
  } else if ([op isEqual:@"controls.status"]) {
    SgFeatureView *host = [self windowContent];
    NSMutableArray *ancestors=[NSMutableArray array];
    for(SgFeatureView *view=self.surface;view;view=view.superview)[ancestors addObject:@{@"class":NSStringFromClass(view.class),@"frame":SgRectMap(view.frame)}];
    CGRect safe = host.bounds;
    NSInteger appState=-1;
#if !TARGET_OS_OSX
    appState=UIApplication.sharedApplication.applicationState;
    safe = UIEdgeInsetsInsetRect(safe,host.safeAreaInsets);
#endif
    done(@{@"enabled":@(self.controls.controlsEnabled),@"hidden":@(self.controls.hidden),@"keepLastFrameWhenComplete":@(self.controls.keepLastFrameWhenComplete),@"coverEnabled":@(self.controls.coverEnabled),@"automaticPictureInPictureEnabled":@(controller.automaticPictureInPictureEnabled),@"applicationState":@(appState),@"ancestors":ancestors,@"hostBounds":SgRectMap(host.bounds),@"hostSafeBounds":SgRectMap(safe),@"surfaceHasParent":(self.surface.superview ? @YES : @NO),@"surfaceBounds":SgRectMap(self.surface.bounds),@"windowAttached":(self.surface.window ? @YES : @NO)},nil); return;
  } else if ([op isEqual:@"controls.reveal"]) { [self.controls revealControls];
  } else if ([op isEqual:@"controls.seekBy"]) { done(@([self.controls seekBySeconds:[a[@"seconds"] doubleValue]]),nil); return;
  } else if ([op isEqual:@"controls.cover"]) {
    [self.coverTask cancel]; NSUInteger revision = ++self.coverRevision;
    NSURL *url = SgURL(a[@"url"]);
    if (!url) { [self.controls setCoverImage:nil forView:self.surface]; done(nil,nil); return; }
    void (^apply)(NSData *, NSError *) = ^(NSData *data, NSError *failure) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (self.closed || revision != self.coverRevision) { done(nil,SgFeatureError(@"Cover request superseded")); return; }
#if TARGET_OS_OSX
        NSImage *image = data ? [[NSImage alloc] initWithData:data] : nil;
#else
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
#endif
        if (image) [self.controls setCoverImage:image forView:self.surface];
        done(nil,failure ?: (image ? nil : SgFeatureError(@"Cannot decode cover")));
      });
    };
    if (url.isFileURL) dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{ NSError *failure = nil; NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&failure]; apply(data,failure); });
    else { self.coverTask = [NSURLSession.sharedSession dataTaskWithRequest:[self request:a] completionHandler:^(NSData *data, NSURLResponse *response, NSError *failure) { apply(data,failure); }]; [self.coverTask resume]; }
    return;
  } else if ([op isEqual:@"presentation.status"]) { done(@(self.presentation.mode),nil); return;
  } else if ([op isEqual:@"presentation.restore"]) { [self.presentation restore];
  } else if ([op isEqual:@"presentation.floating"] || [op isEqual:@"presentation.fullscreen"]) {
    SgFeatureView *host = [self windowContent];
    BOOL ok = host && ([op isEqual:@"presentation.floating"] ? [self.presentation showFloatingInView:host frame:SgRect(a[@"rect"])] : [self.presentation showFullScreenInView:host]); done(@(ok),nil); return;
  } else if ([op hasPrefix:@"preview."]) { [self preview:op arguments:a completion:done]; return;
  } else if ([op hasPrefix:@"cache."]) { [self cache:op arguments:a completion:done]; return;
  } else if ([op hasPrefix:@"hls."]) { [self hls:op arguments:a completion:done]; return;
  } else if ([op hasPrefix:@"export."]) { [self export:op arguments:a completion:done]; return;
  } else if ([op isEqual:@"job.status"]) { NSDictionary *job = self.jobs[a[@"id"]]; done(job,job ? nil : SgFeatureError(@"Unknown job")); return;
  } else if ([op isEqual:@"job.cancel"]) { id worker = self.workers[a[@"id"]]; if ([worker respondsToSelector:@selector(cancel)]) [worker cancel]; else if ([worker isKindOfClass:NSUUID.class]) [self.cache cancelDownload:worker];
  } else if ([op isEqual:@"job.remove"]) { if (self.workers[a[@"id"]]) error = SgFeatureError(@"Cancel and wait for the job before removing it"); else [self.jobs removeObjectForKey:a[@"id"]];
  } else { error = SgFeatureError([@"Unsupported SGPlayer operation: " stringByAppendingString:op]); }
  done(nil,error);
}
- (void)preview:(NSString *)op arguments:(NSDictionary *)a completion:(void (^)(id, NSError *))done {
  NSError *error = nil; NSString *identifier = a[@"id"];
  if ([op isEqual:@"preview.create"]) {
    NSURL *url = SgURL(a[@"url"]); if (!url) { done(nil,SgFeatureError(@"Preview URL required")); return; }
    identifier = NSUUID.UUID.UUIDString; self.previews[identifier] = [[SGTimelinePreview alloc] initWithURL:url]; done(identifier,nil); return;
  }
  if ([op isEqual:@"preview.cancel"]) { [self.previews[identifier] cancel]; [self.previews removeObjectForKey:identifier]; [self.sprites removeObjectForKey:identifier]; done(nil,nil); return; }
  if ([op isEqual:@"preview.spriteIndex"]) {
    NSURL *base = SgURL(a[@"baseURL"]); if (!base || !a[@"webVTT"]) { done(nil,SgFeatureError(@"WebVTT and baseURL required")); return; }
    SGTimelineSpriteIndex *index = [SGTimelineSpriteIndex indexWithWebVTT:a[@"webVTT"] baseURL:base error:&error];
    if (!index) { done(nil,error); return; } identifier = NSUUID.UUID.UUIDString; self.sprites[identifier] = index; done(identifier,nil); return;
  }
  if ([op isEqual:@"preview.spriteCue"]) {
    SGTimelineSpriteCue *cue = [self.sprites[identifier] cueAtTime:SgTime(a[@"timeMs"])];
    done(cue ? @{@"url":cue.URL.absoluteString,@"range":SgRangeMap(cue.range),@"rect":CGRectIsNull(cue.pixelRect) ? NSNull.null : SgRectMap(cue.pixelRect)} : nil,nil); return;
  }
  SGTimelinePreview *provider = self.previews[identifier];
  SGTimelineSpriteCue *cue = [self.sprites[identifier] cueAtTime:SgTime(a[@"timeMs"])];
  if (!([op isEqual:@"preview.image"] && provider) && !([op isEqual:@"preview.spriteImage"] && cue)) { done(nil,SgFeatureError(@"Unknown preview or missing sprite cue")); return; }
  // Dart supplies authenticated sprite bytes; the SDK owns cropping and scaling.
  NSData *data = a[@"imageData"];
  NSInteger dimension = a[@"maximumDimension"] ? [a[@"maximumDimension"] integerValue] : 320;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
    NSError *failure = nil;
    CIImage *image = provider ? [provider imageAtTime:SgTime(a[@"timeMs"]) maximumDimension:dimension error:&failure] : [SGTimelineSpriteIndex imageForCue:cue imageData:data maximumDimension:dimension error:&failure];
    NSData *png = SgPNG(image);
    dispatch_async(dispatch_get_main_queue(), ^{ done(png,failure ?: (png ? nil : SgFeatureError(@"No preview frame"))); });
  });
}
- (void)cache:(NSString *)op arguments:(NSDictionary *)a completion:(void (^)(id, NSError *))done {
  NSError *error = nil;
  if ([op isEqual:@"cache.open"]) {
    NSURL *directory = SgURL(a[@"directory"]); if (!directory.isFileURL) { done(nil,SgFeatureError(@"Cache directory must be local")); return; }
    SGMediaCache *cache = [[SGMediaCache alloc] initWithDirectory:directory maximumBytes:[a[@"maximumBytes"] unsignedLongLongValue] error:&error];
    if (cache) { [self.cache close]; self.cache = cache; } done(@(cache != nil),error); return;
  }
  if (!self.cache) { done(nil,SgFeatureError(@"Open a cache first")); return; }
  if ([op isEqual:@"cache.info"]) { done(@{@"directory":self.cache.directory.absoluteString,@"maximumBytes":@(self.cache.maximumBytes),@"cachedBytes":@(self.cache.cachedBytes)},nil); return; }
  if ([op isEqual:@"cache.clear"]) { [self.cache removeAllUnpinned]; done(nil,nil); return; }
  if ([op isEqual:@"cache.close"]) { [self.cache close]; self.cache = nil; done(nil,nil); return; }
  NSURLRequest *request = [self request:a]; if (!request) { done(nil,SgFeatureError(@"Request URL required")); return; }
  if ([op isEqual:@"cache.lookup"]) { done([self.cache cachedURLForRequest:request].absoluteString,nil); return; }
  if ([op isEqual:@"cache.pin"]) { done(@([self.cache pinRequest:request]),nil); return; }
  if ([op isEqual:@"cache.unpin"]) { [self.cache unpinRequest:request]; done(nil,nil); return; }
  if ([op isEqual:@"cache.download"]) {
    NSString *job = [self job:NSNull.null];
    NSUUID *worker = [self.cache downloadRequest:request expectedSHA256:a[@"sha256"] progress:^(int64_t received, int64_t expected) { [self progress:job value:expected > 0 ? (double)received/expected : 0]; } completion:^(NSURL *url, NSError *failure) { [self finish:job result:url.absoluteString error:failure]; }];
    if (worker) self.workers[job] = worker;
    done(job,nil); return;
  }
  done(nil,SgFeatureError(@"Unknown cache operation"));
}
- (void)hls:(NSString *)op arguments:(NSDictionary *)a completion:(void (^)(id, NSError *))done {
  if ([op isEqual:@"hls.supported"]) { done(@([SGHLSAssetStore isSupported]),nil); return; }
  if (![SGHLSAssetStore isSupported]) { done(nil,SgFeatureError(@"HLS downloads require iOS 18 or macOS 14 and supported system APIs")); return; }
  if ([op isEqual:@"hls.open"]) {
    NSString *identifier = a[@"backgroundIdentifier"]; if (!identifier.length) { done(nil,SgFeatureError(@"Background identifier required")); return; }
    if (![identifier hasPrefix:@"kinetic_player.hls."]) { done(nil,SgFeatureError(@"Use the kinetic_player.hls. namespace for relaunch callbacks")); return; }
    if ([SgHLSOwners objectForKey:identifier] && [SgHLSOwners objectForKey:identifier] != self) { done(nil,SgFeatureError(@"HLS identifier is already owned by another player")); return; }
    [self releaseHlsOwnership];
    self.hls = SgHLSStores[identifier] ?: [[SGHLSAssetStore alloc] initWithBackgroundIdentifier:identifier metadataStore:NSUserDefaults.standardUserDefaults];
    if (!SgHLSOwners) SgHLSOwners = [NSMapTable strongToWeakObjectsMapTable];
    if (self.hls) [SgHLSOwners setObject:self forKey:identifier];
    if (!SgHLSStores) SgHLSStores = [NSMutableDictionary dictionary];
    if (self.hls) SgHLSStores[identifier] = self.hls;
    __weak typeof(self) weakSelf = self;
    self.hls.changed = ^(NSString *item, NSURL *url, NSError *failure) {
      [weakSelf emit:@{@"type":@"hls",@"id":item,@"offlineURL":url.absoluteString ?: NSNull.null,@"error":failure.localizedDescription ?: NSNull.null}];
    };
    self.hls.backgroundEventsFinished = ^{
      void (^completion)(void) = SgHLSCompletions[identifier];
      [SgHLSCompletions removeObjectForKey:identifier];
      if (completion) completion();
    };
    done(@(self.hls != nil),self.hls ? nil : SgFeatureError(@"Cannot create HLS store")); return;
  }
  if (!self.hls) { done(nil,SgFeatureError(@"Open an HLS store first")); return; }
  NSError *error = nil;
  if ([op isEqual:@"hls.restore"]) { [self.hls restoreTasksWithCompletion:^{ done(nil,nil); }]; return; }
  if ([op isEqual:@"hls.list"]) { done([self.hls downloads],nil); return; }
  if ([op isEqual:@"hls.close"]) {
    for (NSDictionary *record in self.hls.downloads) if ([record[@"state"] isEqual:@"downloading"]) {
      done(nil,SgFeatureError(@"Finish or cancel active HLS downloads before closing the store")); return;
    }
    [self detachHls]; done(nil,nil); return;
  }
  NSString *identifier = a[@"id"]; if (!identifier.length) { done(nil,SgFeatureError(@"HLS item identifier required")); return; }
  if ([op isEqual:@"hls.download"]) {
    NSURL *url = SgURL(a[@"url"]); if (!url) { done(nil,SgFeatureError(@"HLS URL required")); return; }
    // Authorization is configured explicitly by the caller; never persisted in metadata.
    if ([a[@"headers"] count]) { done(nil,SgFeatureError(@"HLS store accepts authorized cookies; arbitrary headers/resource loaders require a host-native AVURLAsset")); return; }
    NSMutableArray *cookies = [NSMutableArray array];
    for (NSDictionary *values in a[@"cookies"]) {
      NSMutableDictionary *properties = [NSMutableDictionary dictionary];
      NSDictionary *keys = @{@"name":NSHTTPCookieName,@"value":NSHTTPCookieValue,@"domain":NSHTTPCookieDomain,@"path":NSHTTPCookiePath,@"secure":NSHTTPCookieSecure};
      for (NSString *key in keys) if (values[key]) properties[keys[key]] = values[key];
      NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:properties];
      if (!cookie) { done(nil,SgFeatureError(@"Invalid HLS cookie")); return; } [cookies addObject:cookie];
    }
    NSDictionary *options = cookies.count ? @{AVURLAssetHTTPCookiesKey:cookies} : nil;
    BOOL ok = [self.hls downloadAsset:[AVURLAsset URLAssetWithURL:url options:options] identifier:identifier title:a[@"title"] ?: identifier error:&error]; done(@(ok),error); return;
  }
  if ([op isEqual:@"hls.cancel"]) [self.hls cancelIdentifier:identifier];
  else if ([op isEqual:@"hls.lookup"]) { done([self.hls offlineURLForIdentifier:identifier].absoluteString,nil); return; }
  else if ([op isEqual:@"hls.remove"]) { BOOL ok = [self.hls removeIdentifier:identifier error:&error]; done(@(ok),error); return; }
  else error = SgFeatureError(@"Unknown HLS operation");
  done(nil,error);
}
- (void)export:(NSString *)op arguments:(NSDictionary *)a completion:(void (^)(id, NSError *))done {
  NSURL *source = SgURL(a[@"url"]), *destination = SgURL(a[@"destination"]);
  if (!source || !destination.isFileURL || [a[@"endMs"] longLongValue] <= [a[@"startMs"] longLongValue]) { done(nil,SgFeatureError(@"Export needs source URL, local destination and a finite positive time range")); return; }
  CMTimeRange range = CMTimeRangeFromTimeToTime(SgTime(a[@"startMs"]),SgTime(a[@"endMs"]));
  SGMediaEffects *effects = [a[@"includeEffects"] boolValue] ? [self.session.controller.effects snapshot] : nil;
  id worker;
  if ([op isEqual:@"export.gif"]) worker = [SGGIFExporter new];
  else if ([op isEqual:@"export.remux"]) worker = [SGMediaRemuxer new];
  else if ([op isEqual:@"export.transcode"]) worker = [SGMediaTranscoder new];
  else { done(nil,SgFeatureError(@"Unknown export operation")); return; }
  SGTranscodeConfiguration *config = [SGTranscodeConfiguration new];
  NSDictionary *configuration = a[@"configuration"] ?: @{};
  for (NSString *key in @[@"container",@"videoCodec",@"maximumDimension",@"maximumFramesPerSecond",@"videoBitRate",@"includeVideo",@"includeAudio",@"audioBitRate",@"audioGain"]) if (configuration[key]) [config setValue:configuration[key] forKey:key];
  NSError *validation = nil;
  if ([op isEqual:@"export.transcode"] && ![config validate:&validation]) { done(nil,validation); return; }
  SGDemuxerOptions *demuxer = [SGDemuxerOptions new];
  if (a[@"demuxerOptions"]) demuxer.options = a[@"demuxerOptions"];
  if ([worker isKindOfClass:SGMediaRemuxer.class]) { ((SGMediaRemuxer *)worker).demuxerOptions = demuxer; if (a[@"maximumWallTime"]) ((SGMediaRemuxer *)worker).maximumWallTime = [a[@"maximumWallTime"] doubleValue]; }
  if ([worker isKindOfClass:SGMediaTranscoder.class]) { ((SGMediaTranscoder *)worker).demuxerOptions = demuxer; if (a[@"maximumWallTime"]) ((SGMediaTranscoder *)worker).maximumWallTime = [a[@"maximumWallTime"] doubleValue]; }
  NSString *identifier = [self job:worker];
  __weak typeof(self) weakSelf = self;
  void (^progress)(double) = ^(double value) { [weakSelf progress:identifier value:value]; };
  if ([worker isKindOfClass:SGGIFExporter.class]) ((SGGIFExporter *)worker).progress = progress;
  else if ([worker isKindOfClass:SGMediaRemuxer.class]) ((SGMediaRemuxer *)worker).progress = progress;
  else ((SGMediaTranscoder *)worker).progress = progress;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
    NSError *error = nil; BOOL success = NO; NSMutableDictionary *result = [@{@"url":destination.absoluteString} mutableCopy];
    if ([worker isKindOfClass:SGGIFExporter.class]) success = [worker exportURL:source toURL:destination range:range framesPerSecond:a[@"framesPerSecond"] ? [a[@"framesPerSecond"] integerValue] : 10 maximumDimension:a[@"maximumDimension"] ? [a[@"maximumDimension"] integerValue] : 640 effects:effects error:&error];
    else if ([worker isKindOfClass:SGMediaRemuxer.class]) { success = [worker remuxURL:source toURL:destination container:[a[@"container"] integerValue] range:range error:&error]; result[@"actualRange"] = SgRangeMap(((SGMediaRemuxer *)worker).actualRange); }
    else { success = [worker transcodeURL:source toURL:destination configuration:config range:range effects:config.includeVideo ? effects : nil error:&error]; SGMediaTranscoder *transcoder = worker; result[@"actualRange"] = SgRangeMap(transcoder.actualRange); result[@"videoFrameCount"] = @(transcoder.videoFrameCount); result[@"audioSampleCount"] = @(transcoder.audioSampleCount); }
    [weakSelf finish:identifier result:success ? result : nil error:error ?: (success ? nil : SgFeatureError(@"Export cancelled or failed"))];
  });
  done(identifier,nil);
}
- (void)releaseHlsOwnership {
  self.hls.changed = nil;
  for (NSString *identifier in SgHLSOwners.keyEnumerator.allObjects) if ([SgHLSOwners objectForKey:identifier] == self) [SgHLSOwners removeObjectForKey:identifier];
  self.hls = nil;
}
- (void)detachHls {
  SGHLSAssetStore *store = self.hls;
  [store close]; [self releaseHlsOwnership];
  for (NSString *identifier in SgHLSStores.allKeys.copy) if (SgHLSStores[identifier] == store) {
    [SgHLSStores removeObjectForKey:identifier];
    void (^completion)(void) = SgHLSCompletions[identifier];
    [SgHLSCompletions removeObjectForKey:identifier]; if (completion) completion();
  }
}
- (void)close {
  if (self.closed) return; self.closed = YES;
  [self.coverTask cancel];
  for (void (^completion)(BOOL) in self.restoreRequests.allValues) completion(NO);
  [self.restoreRequests removeAllObjects];
  for (id worker in self.workers.allValues) if ([worker respondsToSelector:@selector(cancel)]) [worker cancel];
  for (SGTimelinePreview *preview in self.previews.allValues) [preview cancel];
  [self.cache close]; [self releaseHlsOwnership]; [self.session.controller stopPictureInPicture]; [self.presentation restore];
  [[self.class coordinator] unregisterSession:self.session];
  [self.workers removeAllObjects]; [self.jobs removeAllObjects]; [self.previews removeAllObjects]; [self.sprites removeAllObjects];
}
@end
