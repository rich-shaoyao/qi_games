//
//  QiInMobiAdManager.m
//  QiGames
//
//  InMobi ad management abstraction implementation (InMobiSDK 11.4.0,
//  integrated as a dynamic xcframework under QiGames/Vendor/InMobi).
//  The hidden panel's upper layer (QiHiddenAdPanel) treats this manager
//  exactly like QiAdManager.
//
//  Placement IDs are defined centrally below; replace the placeholders with
//  the real InMobi placement IDs (int64) from https://publisher.inmobi.com
//  before delivery. Placeholder 0 is invalid — loading fails and the panel
//  shows "No Ad" for the InMobi rows.
//

#import "QiInMobiAdManager.h"
#import <UIKit/UIKit.h>
#import <InMobiSDK/InMobiSDK-Swift.h>

// Placement IDs: TODO replace the placeholders (0) with the real placement IDs.
static const int64_t kQiInMobiRewardedPlacementID     = 0; //!< TODO: rewarded placement ID
static const int64_t kQiInMobiInterstitialPlacementID = 0; //!< TODO: interstitial placement ID

@interface QiInMobiAdManager () <IMInterstitialDelegate>

@property (nonatomic, strong, nullable) IMInterstitial *rewardedInterstitial;         //!< Loaded rewarded ad, ready to play
@property (nonatomic, strong, nullable) IMInterstitial *interstitialInterstitial;     //!< Loaded interstitial ad, ready to play
@property (nonatomic, copy, nullable) QiInMobiAdLoadCompletion rewardedLoadCompletion;     //!< Pending load completion for the rewarded ad
@property (nonatomic, copy, nullable) QiInMobiAdLoadCompletion interstitialLoadCompletion; //!< Pending load completion for the interstitial ad
@property (nonatomic, copy, nullable) QiInMobiAdLoadCompletion pendingCompletion; //!< Completion block pending while an ad is playing
@property (nonatomic, assign) QiInMobiAdType pendingType;                         //!< Ad type currently playing

@end

@implementation QiInMobiAdManager

/**
 *  Returns the InMobi ad manager singleton.
 *
 *  @return The QiInMobiAdManager singleton instance.
 */
+ (instancetype)sharedManager {
    
    static QiInMobiAdManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QiInMobiAdManager alloc] init];
    });
    return manager;
}

#pragma mark - Public

/**
 *  Loads the given InMobi ad type.
 *
 *  @param type       Ad type (QiInMobiAdTypeRewarded / QiInMobiAdTypeInterstitial).
 *  @param completion Load completion callback.
 *  @return None.
 */
- (void)loadAdOfType:(QiInMobiAdType)type completion:(QiInMobiAdLoadCompletion)completion {
    
    if (type == QiInMobiAdTypeRewarded) {
        [self loadRewardedWithCompletion:completion];
    } else {
        [self loadInterstitialWithCompletion:completion];
    }
}

/**
 *  Plays the given InMobi ad type: if the ad is loaded and isReady, presents
 *  it; after playback (dismiss) or presentation failure, automatically reloads
 *  that ad type and calls back. If the ad is not ready or no root controller
 *  is found, reloads directly and calls back with the result.
 *
 *  @param type       Ad type (QiInMobiAdTypeRewarded / QiInMobiAdTypeInterstitial).
 *  @param completion Callback after playback and reload.
 *  @return None.
 */
- (void)showAdOfType:(QiInMobiAdType)type completion:(QiInMobiAdLoadCompletion)completion {
    
    UIViewController *rootVC = [self topViewController];
    IMInterstitial *ad = (type == QiInMobiAdTypeRewarded) ? self.rewardedInterstitial : self.interstitialInterstitial;
    if (ad && rootVC && ad.isReady) {
        _pendingType = type;
        _pendingCompletion = [completion copy];
        [ad showFrom:rootVC];
    } else {
        [self loadAdOfType:type completion:completion];
    }
}

/**
 *  Returns whether the given InMobi ad type is loaded and ready to play
 *  (isReady pre-check; does not trigger a load).
 *
 *  @param type Ad type (QiInMobiAdTypeRewarded / QiInMobiAdTypeInterstitial).
 *  @return YES if the ad is ready to play; NO otherwise.
 */
- (BOOL)isAdReadyOfType:(QiInMobiAdType)type {
    
    IMInterstitial *ad = (type == QiInMobiAdTypeRewarded) ? self.rewardedInterstitial : self.interstitialInterstitial;
    return ad != nil && ad.isReady;
}

#pragma mark - InMobi load

/**
 *  Loads the rewarded ad: creates a fresh IMInterstitial for the rewarded
 *  placement and loads it; the result is reported through the pending load
 *  completion when the delegate callback fires.
 *
 *  @param completion Load completion callback.
 *  @return None.
 */
- (void)loadRewardedWithCompletion:(QiInMobiAdLoadCompletion)completion {
    
    self.rewardedLoadCompletion = [completion copy];
    IMInterstitial *ad = [[IMInterstitial alloc] initWithPlacementId:kQiInMobiRewardedPlacementID delegate:self];
    self.rewardedInterstitial = ad;
    [ad load];
}

/**
 *  Loads the interstitial ad (same flow as the rewarded ad).
 *
 *  @param completion Load completion callback.
 *  @return None.
 */
- (void)loadInterstitialWithCompletion:(QiInMobiAdLoadCompletion)completion {
    
    self.interstitialLoadCompletion = [completion copy];
    IMInterstitial *ad = [[IMInterstitial alloc] initWithPlacementId:kQiInMobiInterstitialPlacementID delegate:self];
    self.interstitialInterstitial = ad;
    [ad load];
}

#pragma mark - IMInterstitialDelegate

/**
 *  Load finished callback: reports success through the matching pending load
 *  completion.
 *
 *  @param interstitial The interstitial that finished loading.
 *  @return None.
 */
- (void)interstitialDidFinishLoading:(IMInterstitial *)interstitial {
    
    if (interstitial == self.rewardedInterstitial) {
        QiInMobiAdLoadCompletion completion = self.rewardedLoadCompletion;
        self.rewardedLoadCompletion = nil;
        if (completion) { completion(YES); }
    } else if (interstitial == self.interstitialInterstitial) {
        QiInMobiAdLoadCompletion completion = self.interstitialLoadCompletion;
        self.interstitialLoadCompletion = nil;
        if (completion) { completion(YES); }
    }
#if DEBUG
    NSLog(@"[QiInMobiAdManager] interstitial finished loading");
#endif
}

/**
 *  Load failure callback: reports failure through the matching pending load
 *  completion and discards the ad.
 *
 *  @param interstitial The interstitial that failed to load.
 *  @param error        The load error (IMRequestStatus).
 *  @return None.
 */
- (void)interstitial:(IMInterstitial *)interstitial didFailToLoadWithError:(IMRequestStatus *)error {
    
#if DEBUG
    NSLog(@"[QiInMobiAdManager] interstitial load failed: %@", error.localizedDescription);
#endif
    if (interstitial == self.rewardedInterstitial) {
        self.rewardedInterstitial = nil;
        QiInMobiAdLoadCompletion completion = self.rewardedLoadCompletion;
        self.rewardedLoadCompletion = nil;
        if (completion) { completion(NO); }
    } else if (interstitial == self.interstitialInterstitial) {
        self.interstitialInterstitial = nil;
        QiInMobiAdLoadCompletion completion = self.interstitialLoadCompletion;
        self.interstitialLoadCompletion = nil;
        if (completion) { completion(NO); }
    }
}

/**
 *  Full-screen ad dismissed callback: playback finished, automatically reloads
 *  the matching ad type and calls back with the reload result.
 *
 *  @param interstitial The dismissed interstitial.
 *  @return None.
 */
- (void)interstitialDidDismiss:(IMInterstitial *)interstitial {
    
    [self reloadAfterFullScreenClosed];
}

/**
 *  Full-screen ad presentation failure callback: cannot play, automatically
 *  reloads the matching ad type and calls back with the reload result.
 *
 *  @param interstitial The interstitial that failed to present.
 *  @param error        The presentation error (IMRequestStatus).
 *  @return None.
 */
- (void)interstitial:(IMInterstitial *)interstitial didFailToPresentWithError:(IMRequestStatus *)error {
    
#if DEBUG
    NSLog(@"[QiInMobiAdManager] full screen present failed: %@", error.localizedDescription);
#endif
    [self reloadAfterFullScreenClosed];
}

/**
 *  Reward callback for rewarded video placements: the hidden panel has no
 *  reward UI requirement (same as AdMob), so this is intentionally left empty.
 *
 *  @param interstitial The interstitial that completed the reward action.
 *  @param rewards      The reward payload.
 *  @return None.
 */
- (void)interstitial:(IMInterstitial *)interstitial rewardActionCompletedWithRewards:(NSDictionary<NSString *, id> *)rewards {
    
    // Reward granting for rewarded video: intentionally left empty.
}

/**
 *  Unified handling after a full-screen ad closes: takes the pending
 *  completion block and automatically reloads the ad type that was playing.
 *
 *  @return None.
 */
- (void)reloadAfterFullScreenClosed {
    
    QiInMobiAdLoadCompletion completion = _pendingCompletion;
    QiInMobiAdType type = _pendingType;
    _pendingCompletion = nil;
    if (completion) {
        [self loadAdOfType:type completion:completion];
    }
}

#pragma mark - Helper

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
