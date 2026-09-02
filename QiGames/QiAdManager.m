//
//  QiAdManager.m
//  QiGames
//
//  Ad management abstraction implementation (AdMob real implementation,
//  Google-Mobile-Ads-SDK 11.7.0 integrated via CocoaPods).
//  Ad unit IDs are defined centrally below; to switch to production IDs,
//  replace the constants at the top of this file (and the GADApplicationIdentifier
//  in Info.plist).
//

#import "QiAdManager.h"
#import <GoogleMobileAds/GoogleMobileAds.h>

// Ad unit IDs: currently using Google's official test ad unit IDs (they
// reliably return test ads to verify the pipeline); replace them with the
// production IDs once confirmed. Test IDs must be paired with the test App ID
// (GADApplicationIdentifier in Info.plist).
static NSString * const kQiRewardedAdUnitID     = @"ca-app-pub-3940256099942544/1712485313";
static NSString * const kQiInterstitialAdUnitID = @"ca-app-pub-3940256099942544/4411468910";

@interface QiAdManager () <GADFullScreenContentDelegate>

@property (nonatomic, strong, nullable) GADRewardedAd *rewardedAd;         //!< Loaded rewarded ad, ready to play
@property (nonatomic, strong, nullable) GADInterstitialAd *interstitialAd; //!< Loaded interstitial ad, ready to play
@property (nonatomic, copy, nullable) QiAdLoadCompletion pendingCompletion; //!< Completion block pending while an ad is playing
@property (nonatomic, assign) QiAdType pendingType;                         //!< Ad type currently playing

@end

@implementation QiAdManager

/**
 *  Returns the ad manager singleton.
 *
 *  @return The QiAdManager singleton instance.
 */
+ (instancetype)sharedManager {
    
    static QiAdManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QiAdManager alloc] init];
    });
    return manager;
}

#pragma mark - Public

/**
 *  Loads the given ad type by calling the matching AdMob load API and
 *  reporting the result through the completion block.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadAdOfType:(QiAdType)type completion:(QiAdLoadCompletion)completion {
    
    if (type == QiAdTypeRewarded) {
        [self loadRewardedAdWithCompletion:completion];
    } else {
        [self loadInterstitialAdWithCompletion:completion];
    }
}

/**
 *  Plays the given ad type: if the ad is loaded and passes the canPresent
 *  check, presents it; after playback (dismiss), automatically reloads that
 *  ad type and calls back with the result. If the ad is not ready or no root
 *  controller is found, reloads directly and calls back with the result.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param completion Callback after playback and reload (success indicates whether the reload succeeded).
 *  @return None.
 */
- (void)showAdOfType:(QiAdType)type completion:(QiAdLoadCompletion)completion {
    
    UIViewController *rootVC = [self topViewController];
    NSError *presentError = nil;
    if (type == QiAdTypeRewarded) {
        GADRewardedAd *ad = self.rewardedAd;
        if (ad && rootVC && [ad canPresentFromRootViewController:rootVC error:&presentError]) {
            _pendingType = type;
            _pendingCompletion = [completion copy];
            ad.fullScreenContentDelegate = self;
            [ad presentFromRootViewController:rootVC userDidEarnRewardHandler:^{
                // Reward granting for rewarded video: the hidden panel has no
                // reward UI requirement, so this is intentionally left empty.
            }];
        } else {
            [self loadRewardedAdWithCompletion:completion];
        }
    } else {
        GADInterstitialAd *ad = self.interstitialAd;
        if (ad && rootVC && [ad canPresentFromRootViewController:rootVC error:&presentError]) {
            _pendingType = type;
            _pendingCompletion = [completion copy];
            ad.fullScreenContentDelegate = self;
            [ad presentFromRootViewController:rootVC];
        } else {
            [self loadInterstitialAdWithCompletion:completion];
        }
    }
}

/**
 *  Returns whether the given ad type is loaded and ready to play (does not
 *  trigger a load).
 *
 *  @param type Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @return YES if the ad is ready to play; NO otherwise.
 */
- (BOOL)isAdReadyOfType:(QiAdType)type {
    
    if (type == QiAdTypeRewarded) {
        return self.rewardedAd != nil;
    }
    return self.interstitialAd != nil;
}

#pragma mark - AdMob load

/**
 *  Loads the rewarded ad (AdMob GADRewardedAd).
 *
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadRewardedAdWithCompletion:(QiAdLoadCompletion)completion {
    
    __weak typeof(self) weakSelf = self;
    [GADRewardedAd loadWithAdUnitID:kQiRewardedAdUnitID
                            request:[GADRequest request]
                  completionHandler:^(GADRewardedAd *_Nullable rewardedAd, NSError *_Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (error) {
#if DEBUG
            NSLog(@"[QiAdManager] rewarded load failed: %@", error.localizedDescription);
#endif
            self.rewardedAd = nil;
            if (completion) { completion(NO); }
            return;
        }
        self.rewardedAd = rewardedAd;
        if (completion) { completion(YES); }
    }];
}

/**
 *  Loads the interstitial ad (AdMob GADInterstitialAd).
 *
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadInterstitialAdWithCompletion:(QiAdLoadCompletion)completion {
    
    __weak typeof(self) weakSelf = self;
    [GADInterstitialAd loadWithAdUnitID:kQiInterstitialAdUnitID
                                request:[GADRequest request]
                      completionHandler:^(GADInterstitialAd *_Nullable interstitialAd, NSError *_Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (error) {
#if DEBUG
            NSLog(@"[QiAdManager] interstitial load failed: %@", error.localizedDescription);
#endif
            self.interstitialAd = nil;
            if (completion) { completion(NO); }
            return;
        }
        self.interstitialAd = interstitialAd;
        if (completion) { completion(YES); }
    }];
}

#pragma mark - GADFullScreenContentDelegate

/**
 *  Full-screen ad dismissed callback: playback finished, automatically
 *  reloads the matching ad type and calls back with the result.
 *
 *  @param ad The dismissed full-screen ad object.
 *  @return None.
 */
- (void)adDidDismissFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
    
    [self reloadAfterFullScreenClosed];
}

/**
 *  Full-screen ad presentation failure callback: cannot play, automatically
 *  reloads the matching ad type and calls back with the result.
 *
 *  @param ad    The full-screen ad object that failed to present.
 *  @param error The reason for the presentation failure.
 *  @return None.
 */
- (void)ad:(id<GADFullScreenPresentingAd>)ad didFailToPresentFullScreenContentWithError:(NSError *)error {
    
#if DEBUG
    NSLog(@"[QiAdManager] full screen present failed: %@", error.localizedDescription);
#endif
    [self reloadAfterFullScreenClosed];
}

/**
 *  Unified handling after a full-screen ad closes: takes the pending
 *  completion block and automatically reloads the ad type that was playing.
 *
 *  @return None.
 */
- (void)reloadAfterFullScreenClosed {
    
    QiAdLoadCompletion completion = _pendingCompletion;
    QiAdType type = _pendingType;
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
