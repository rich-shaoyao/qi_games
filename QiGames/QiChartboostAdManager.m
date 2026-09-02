//
//  QiChartboostAdManager.m
//  QiGames
//
//  Chartboost ad management abstraction implementation (ChartboostSDK 9.14.0,
//  integrated as a static xcframework under QiGames/Vendor/Chartboost).
//  The hidden panel's upper layer (QiHiddenAdPanel) treats this manager
//  exactly like QiAdManager.
//
//  Chartboost locations are defined centrally below. Chartboost does not
//  require locations to be pre-registered; distinct locations let the
//  dashboard report rewarded / interstitial separately. The SDK is started in
//  AppDelegate with the demo app ID / signature (replace with the production
//  credentials before delivery).
//
//  Ad lifecycle (mirrors QiAdManager / QiInMobiAdManager):
//    cache -> didCacheAd:error: (load result) -> showFromViewController:
//    -> didShowAd:error: -> didDismissAd: -> auto reload the same type.
//  Each load creates a fresh ad object so cache() always fetches a new ad and
//  the load completion always fires.
//

#import "QiChartboostAdManager.h"
#import <UIKit/UIKit.h>
#import <ChartboostSDK/Chartboost.h>

// Chartboost locations: per-type location strings used for caching and
// dashboard reporting. Replace with the production location names if required.
static NSString * const kQiChartboostRewardedLocation     = @"rewarded";
static NSString * const kQiChartboostInterstitialLocation = @"interstitial";

@interface QiChartboostAdManager () <CHBRewardedDelegate, CHBInterstitialDelegate>

@property (nonatomic, strong, nullable) CHBRewarded *rewardedAd;         //!< Loaded rewarded ad (strong: delegate is weak)
@property (nonatomic, strong, nullable) CHBInterstitial *interstitialAd; //!< Loaded interstitial ad (strong: delegate is weak)
@property (nonatomic, assign) BOOL rewardedCached;                       //!< Whether the rewarded ad is cached and ready to show
@property (nonatomic, assign) BOOL interstitialCached;                   //!< Whether the interstitial ad is cached and ready to show
@property (nonatomic, copy, nullable) QiChartboostAdLoadCompletion rewardedLoadCompletion;     //!< Pending load completion for the rewarded ad
@property (nonatomic, copy, nullable) QiChartboostAdLoadCompletion interstitialLoadCompletion; //!< Pending load completion for the interstitial ad
@property (nonatomic, copy, nullable) QiChartboostAdLoadCompletion pendingCompletion; //!< Completion block pending while an ad is playing
@property (nonatomic, assign) QiChartboostAdType pendingType;             //!< Ad type currently playing

@end

@implementation QiChartboostAdManager

/**
 *  Returns the Chartboost ad manager singleton.
 *
 *  @return The QiChartboostAdManager singleton instance.
 */
+ (instancetype)sharedManager {
    
    static QiChartboostAdManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QiChartboostAdManager alloc] init];
    });
    return manager;
}

#pragma mark - Public

/**
 *  Loads the given Chartboost ad type.
 *
 *  @param type       Ad type (QiChartboostAdTypeRewarded / QiChartboostAdTypeInterstitial).
 *  @param completion Load completion callback.
 *  @return None.
 */
- (void)loadAdOfType:(QiChartboostAdType)type completion:(QiChartboostAdLoadCompletion)completion {
    
    if (type == QiChartboostAdTypeRewarded) {
        [self loadRewardedWithCompletion:completion];
    } else {
        [self loadInterstitialWithCompletion:completion];
    }
}

/**
 *  Plays the given Chartboost ad type: if the ad is cached, presents it; after
 *  playback (dismiss) or presentation failure, automatically reloads that ad
 *  type and calls back. If the ad is not ready or no root controller is found,
 *  reloads directly and calls back with the result.
 *
 *  @param type       Ad type (QiChartboostAdTypeRewarded / QiChartboostAdTypeInterstitial).
 *  @param completion Callback after playback and reload.
 *  @return None.
 */
- (void)showAdOfType:(QiChartboostAdType)type completion:(QiChartboostAdLoadCompletion)completion {
    
    UIViewController *rootVC = [self topViewController];
    BOOL isRewarded = (type == QiChartboostAdTypeRewarded);
    BOOL cached = isRewarded ? self.rewardedCached : self.interstitialCached;
    id<CHBAd> ad = isRewarded ? (id<CHBAd>)self.rewardedAd : (id<CHBAd>)self.interstitialAd;
    if (ad && cached && rootVC) {
        _pendingType = type;
        _pendingCompletion = [completion copy];
        [ad showFromViewController:rootVC];
    } else {
        [self loadAdOfType:type completion:completion];
    }
}

/**
 *  Returns whether the given Chartboost ad type is cached and ready to play
 *  (does not trigger a load).
 *
 *  @param type Ad type (QiChartboostAdTypeRewarded / QiChartboostAdTypeInterstitial).
 *  @return YES if the ad is ready to play; NO otherwise.
 */
- (BOOL)isAdReadyOfType:(QiChartboostAdType)type {
    
    if (type == QiChartboostAdTypeRewarded) {
        return self.rewardedAd != nil && self.rewardedCached;
    }
    return self.interstitialAd != nil && self.interstitialCached;
}

#pragma mark - Chartboost load

/**
 *  Loads the rewarded ad: creates a fresh CHBRewarded for the rewarded
 *  location and caches it; the result is reported through the pending load
 *  completion when didCacheAd:error: fires.
 *
 *  @param completion Load completion callback.
 *  @return None.
 */
- (void)loadRewardedWithCompletion:(QiChartboostAdLoadCompletion)completion {
    
    self.rewardedCached = NO;
    self.rewardedLoadCompletion = [completion copy];
    CHBRewarded *ad = [[CHBRewarded alloc] initWithLocation:kQiChartboostRewardedLocation delegate:self];
    self.rewardedAd = ad;
    [ad cache];
}

/**
 *  Loads the interstitial ad (same flow as the rewarded ad).
 *
 *  @param completion Load completion callback.
 *  @return None.
 */
- (void)loadInterstitialWithCompletion:(QiChartboostAdLoadCompletion)completion {
    
    self.interstitialCached = NO;
    self.interstitialLoadCompletion = [completion copy];
    CHBInterstitial *ad = [[CHBInterstitial alloc] initWithLocation:kQiChartboostInterstitialLocation delegate:self];
    self.interstitialAd = ad;
    [ad cache];
}

#pragma mark - CHBAdDelegate (shared by rewarded + interstitial)

/**
 *  Cache finished callback: reports success/failure through the matching
 *  pending load completion and updates the cached flag.
 *
 *  @param event A cache event with info related to the cached ad.
 *  @param error An error specifying the failure reason, or nil on success.
 *  @return None.
 */
- (void)didCacheAd:(CHBCacheEvent *)event error:(nullable CHBCacheError *)error {
    
    BOOL success = (error == nil);
#if DEBUG
    NSLog(@"[QiChartboostAdManager] cache finished success=%d error=%@", success, error);
#endif
    if (event.ad == (id<CHBAd>)self.rewardedAd) {
        self.rewardedCached = success;
        QiChartboostAdLoadCompletion completion = self.rewardedLoadCompletion;
        self.rewardedLoadCompletion = nil;
        if (completion) { completion(success); }
    } else if (event.ad == (id<CHBAd>)self.interstitialAd) {
        self.interstitialCached = success;
        QiChartboostAdLoadCompletion completion = self.interstitialLoadCompletion;
        self.interstitialLoadCompletion = nil;
        if (completion) { completion(success); }
    }
}

/**
 *  Show result callback: on failure (no cached ad or presentation error)
 *  discards the ad and reloads the pending type; on success waits for
 *  didDismissAd: to reload.
 *
 *  @param event A show event with info related to the ad shown.
 *  @param error An error specifying the failure reason, or nil on success.
 *  @return None.
 */
- (void)didShowAd:(CHBShowEvent *)event error:(nullable CHBShowError *)error {
    
    if (error) {
#if DEBUG
        NSLog(@"[QiChartboostAdManager] show failed: %@", error);
#endif
        // Mark the ad as no longer cached and reload the pending type (a fresh
        // ad object is created by loadAdOfType, so the load callback always fires).
        if (event.ad == (id<CHBAd>)self.rewardedAd) {
            self.rewardedCached = NO;
        } else if (event.ad == (id<CHBAd>)self.interstitialAd) {
            self.interstitialCached = NO;
        }
        [self reloadAfterFullScreenClosed];
    }
}

/**
 *  Full-screen ad dismissed callback: playback finished, automatically reloads
 *  the pending ad type and calls back with the reload result.
 *
 *  @param event A dismiss event with info related to the dismissed ad.
 *  @return None.
 */
- (void)didDismissAd:(CHBDismissEvent *)event {
    
#if DEBUG
    NSLog(@"[QiChartboostAdManager] ad dismissed");
#endif
    [self reloadAfterFullScreenClosed];
}

/**
 *  Cached-ad expiration callback: the cached ad is no longer showable; the
 *  next load (or show pre-check) will fetch a new ad.
 *
 *  @param event An expiration event with info related to the expired ad.
 *  @return None.
 */
- (void)didExpireAd:(CHBExpirationEvent *)event {
    
#if DEBUG
    NSLog(@"[QiChartboostAdManager] ad expired");
#endif
    if (event.ad == (id<CHBAd>)self.rewardedAd) {
        self.rewardedCached = NO;
    } else if (event.ad == (id<CHBAd>)self.interstitialAd) {
        self.interstitialCached = NO;
    }
}

#pragma mark - CHBRewardedDelegate

/**
 *  Reward callback for rewarded video: the hidden panel has no reward UI
 *  requirement (same as AdMob / InMobi), so this is intentionally left empty.
 *
 *  @param event A reward event with info related to the ad and the reward.
 *  @return None.
 */
- (void)didEarnReward:(CHBRewardEvent *)event {
    
    // Reward granting for rewarded video: intentionally left empty.
}

#pragma mark - Helper

/**
 *  Unified handling after a full-screen ad closes (or fails to show): takes
 *  the pending completion block and automatically reloads the ad type that
 *  was playing.
 *
 *  @return None.
 */
- (void)reloadAfterFullScreenClosed {
    
    QiChartboostAdLoadCompletion completion = _pendingCompletion;
    QiChartboostAdType type = _pendingType;
    _pendingCompletion = nil;
    if (completion) {
        [self loadAdOfType:type completion:completion];
    }
}

/**
 *  Returns the root view controller usable for presenting full-screen ads
 *  (prefers the key window of the foreground active scene, then the key
 *  window of any scene; walks up to the topmost presentedViewController).
 *
 *  @return The root view controller, or nil if none is found.
 */
- (UIViewController *)topViewController {
    
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                if (windowScene.activationState == UISceneActivationStateForegroundActive && windowScene.keyWindow) {
                    window = windowScene.keyWindow;
                    break;
                }
            }
        }
        if (!window) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    if (windowScene.keyWindow) {
                        window = windowScene.keyWindow;
                        break;
                    }
                }
            }
        }
    }
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    return top;
}

@end
