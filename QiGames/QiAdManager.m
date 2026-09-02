//
//  QiAdManager.m
//  QiGames
//
//  Ad management abstraction implementation (AdMob GoogleMobileAds v11.3.0,
//  integrated via SPM; the local Xcode 15.2-compatible version should be
//  bumped back to v11.7.0 in an Xcode 16 environment before delivery).
//  Vungle / Liftoff VungleAds 7.0.0 (manual xcframework, dynamic) is also
//  supported through the same QiAdType abstraction.
//  FIX-02: the stub has been replaced with a real AdMob load/play
//  implementation; the upper layer (QiHiddenAdPanel) API is unchanged.
//  Ad unit IDs are defined centrally below; to switch to production IDs,
//  replace the constants at the top of this file.
//

#import "QiAdManager.h"
#import "QiInMobiAdManager.h"
#import "QiChartboostAdManager.h"
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <VungleAdsSDK/VungleAdsSDK.h>

// Ad unit IDs: currently using Google's official test ad unit IDs (they
// reliably return test ads to verify the pipeline); replace them with the
// production IDs once confirmed for FIX-02.
static NSString * const kQiRewardedAdUnitID     = @"ca-app-pub-3940256099942544/1712485313";
static NSString * const kQiInterstitialAdUnitID = @"ca-app-pub-3940256099942544/4411468910";

// Vungle / Liftoff placeholders (FIX-04): replace with the real Vungle
// placement IDs created in the Liftoff dashboard before delivery. The SDK only
// serves ads once a valid App ID (AppDelegate) and placement IDs are set.
static NSString * const kQiVungleRewardedPlacementID     = @"REPLACE_WITH_VUNGLE_REWARDED_PLACEMENT_ID";
static NSString * const kQiVungleInterstitialPlacementID = @"REPLACE_WITH_VUNGLE_INTERSTITIAL_PLACEMENT_ID";

@interface QiAdManager () <GADFullScreenContentDelegate, VungleRewardedDelegate, VungleInterstitialDelegate>

@property (nonatomic, strong, nullable) GADRewardedAd *rewardedAd;         //!< Loaded rewarded ad, ready to play
@property (nonatomic, strong, nullable) GADInterstitialAd *interstitialAd; //!< Loaded interstitial ad, ready to play
@property (nonatomic, copy, nullable) QiAdLoadCompletion pendingCompletion; //!< Completion block pending while an ad is playing
@property (nonatomic, assign) QiAdType pendingType;                         //!< Ad type currently playing
@property (nonatomic, assign) QiAdPlatform pendingPlatform;                 //!< Platform of the ad currently playing

@property (nonatomic, copy, nullable) QiAdLoadCompletion pendingRewardedLoadCompletion;    //!< Vungle rewarded load result callback (delivered by the delegate)
@property (nonatomic, copy, nullable) QiAdLoadCompletion pendingInterstitialLoadCompletion; //!< Vungle interstitial load result callback (delivered by the delegate)

@property (nonatomic, strong, nullable) VungleRewarded *vungleRewarded;         //!< Vungle rewarded ad (strong: delegate is weak)
@property (nonatomic, strong, nullable) VungleInterstitial *vungleInterstitial; //!< Vungle interstitial ad (strong: delegate is weak)

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
 *  Loads the given ad type by calling the matching load API and reporting the
 *  result through the completion block. Uses the AdMob platform by default.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadAdOfType:(QiAdType)type completion:(QiAdLoadCompletion)completion {
    
    [self loadAdOfType:type platform:QiAdPlatformAdMob completion:completion];
}

/**
 *  Loads the given ad type on the given platform by calling the matching load
 *  API and reporting the result through the completion block.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform   Ad network platform (QiAdPlatformAdMob / QiAdPlatformVungle).
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadAdOfType:(QiAdType)type platform:(QiAdPlatform)platform completion:(QiAdLoadCompletion)completion {
    
    if (platform == QiAdPlatformVungle) {
        if (type == QiAdTypeRewarded) {
            [self loadVungleRewardedAdWithCompletion:completion];
        } else {
            [self loadVungleInterstitialAdWithCompletion:completion];
        }
        return;
    }
    if (platform == QiAdPlatformInMobi) {
        QiInMobiAdType inMobiType = (type == QiAdTypeRewarded) ? QiInMobiAdTypeRewarded : QiInMobiAdTypeInterstitial;
        [[QiInMobiAdManager sharedManager] loadAdOfType:inMobiType completion:completion];
        return;
    }
    if (platform == QiAdPlatformChartboost) {
        QiChartboostAdType chartboostType = (type == QiAdTypeRewarded) ? QiChartboostAdTypeRewarded : QiChartboostAdTypeInterstitial;
        [[QiChartboostAdManager sharedManager] loadAdOfType:chartboostType completion:completion];
        return;
    }
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
 *  Uses the AdMob platform by default.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param completion Callback after playback and reload (success indicates whether the reload succeeded).
 *  @return None.
 */
- (void)showAdOfType:(QiAdType)type completion:(QiAdLoadCompletion)completion {
    
    [self showAdOfType:type platform:QiAdPlatformAdMob completion:completion];
}

/**
 *  Plays the given ad type on the given platform: if the ad is loaded and
 *  passes the canPresent check, presents it; after playback (dismiss),
 *  automatically reloads that ad type and calls back with the result. If the
 *  ad is not ready or no root controller is found, reloads directly and calls
 *  back with the result.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform   Ad network platform (QiAdPlatformAdMob / QiAdPlatformVungle).
 *  @param completion Callback after playback and reload (success indicates whether the reload succeeded).
 *  @return None.
 */
- (void)showAdOfType:(QiAdType)type platform:(QiAdPlatform)platform completion:(QiAdLoadCompletion)completion {
    
    UIViewController *rootVC = [self topViewController];
    if (platform == QiAdPlatformVungle) {
        if (type == QiAdTypeRewarded) {
            VungleRewarded *ad = self.vungleRewarded;
            if (ad && rootVC && [ad canPlayAd]) {
                _pendingType = type;
                _pendingPlatform = platform;
                _pendingCompletion = [completion copy];
                [ad presentWith:rootVC];
            } else {
                [self loadVungleRewardedAdWithCompletion:completion];
            }
        } else {
            VungleInterstitial *ad = self.vungleInterstitial;
            if (ad && rootVC && [ad canPlayAd]) {
                _pendingType = type;
                _pendingPlatform = platform;
                _pendingCompletion = [completion copy];
                [ad presentWith:rootVC];
            } else {
                [self loadVungleInterstitialAdWithCompletion:completion];
            }
        }
        return;
    }
    if (platform == QiAdPlatformInMobi) {
        QiInMobiAdType inMobiType = (type == QiAdTypeRewarded) ? QiInMobiAdTypeRewarded : QiInMobiAdTypeInterstitial;
        [[QiInMobiAdManager sharedManager] showAdOfType:inMobiType completion:completion];
        return;
    }
    if (platform == QiAdPlatformChartboost) {
        QiChartboostAdType chartboostType = (type == QiAdTypeRewarded) ? QiChartboostAdTypeRewarded : QiChartboostAdTypeInterstitial;
        [[QiChartboostAdManager sharedManager] showAdOfType:chartboostType completion:completion];
        return;
    }
    
    if (type == QiAdTypeRewarded) {
        GADRewardedAd *ad = self.rewardedAd;
        NSError *presentError = nil;
        if (ad && rootVC && [ad canPresentFromRootViewController:rootVC error:&presentError]) {
            _pendingType = type;
            _pendingPlatform = platform;
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
        NSError *presentError = nil;
        if (ad && rootVC && [ad canPresentFromRootViewController:rootVC error:&presentError]) {
            _pendingType = type;
            _pendingPlatform = platform;
            _pendingCompletion = [completion copy];
            ad.fullScreenContentDelegate = self;
            [ad presentFromRootViewController:rootVC];
        } else {
            [self loadInterstitialAdWithCompletion:completion];
        }
    }
}

#pragma mark - Vungle load

/**
 *  Returns whether the given ad type is loaded and ready to play on the given
 *  platform (does not trigger a load).
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform.
 *  @return YES if the ad is ready to play; NO otherwise.
 */
- (BOOL)isAdReadyOfType:(QiAdType)type platform:(QiAdPlatform)platform {
    
    if (platform == QiAdPlatformVungle) {
        if (type == QiAdTypeRewarded) {
            return self.vungleRewarded != nil && [self.vungleRewarded canPlayAd];
        }
        return self.vungleInterstitial != nil && [self.vungleInterstitial canPlayAd];
    }
    if (platform == QiAdPlatformInMobi) {
        QiInMobiAdType inMobiType = (type == QiAdTypeRewarded) ? QiInMobiAdTypeRewarded : QiInMobiAdTypeInterstitial;
        return [[QiInMobiAdManager sharedManager] isAdReadyOfType:inMobiType];
    }
    if (platform == QiAdPlatformChartboost) {
        QiChartboostAdType chartboostType = (type == QiAdTypeRewarded) ? QiChartboostAdTypeRewarded : QiChartboostAdTypeInterstitial;
        return [[QiChartboostAdManager sharedManager] isAdReadyOfType:chartboostType];
    }
    if (type == QiAdTypeRewarded) {
        return self.rewardedAd != nil;
    }
    return self.interstitialAd != nil;
}

/**
 *  Loads the Vungle rewarded ad (VungleRewarded). Returns NO immediately if
 *  the Vungle SDK is not initialized (placeholder App ID in DEBUG).
 *
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadVungleRewardedAdWithCompletion:(QiAdLoadCompletion)completion {
    
    if (![VungleAds isInitialized]) {
#if DEBUG
        NSLog(@"[QiAdManager] vungle rewarded load skipped: SDK not initialized");
#endif
        if (completion) { completion(NO); }
        return;
    }
    
    VungleRewarded *ad = [[VungleRewarded alloc] initWithPlacementId:kQiVungleRewardedPlacementID];
    ad.delegate = self;
    self.vungleRewarded = ad;
    [ad load:nil];
    // The load result is reported asynchronously through the VungleRewardedDelegate
    // callbacks (rewardedAdDidLoad: / rewardedAdDidFailToLoad:withError:); the
    // completion block is cached in a per-type slot so concurrent rewarded +
    // interstitial loads do not overwrite each other.
    _pendingRewardedLoadCompletion = [completion copy];
}

/**
 *  Loads the Vungle interstitial ad (VungleInterstitial). Returns NO
 *  immediately if the Vungle SDK is not initialized.
 *
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadVungleInterstitialAdWithCompletion:(QiAdLoadCompletion)completion {
    
    if (![VungleAds isInitialized]) {
#if DEBUG
        NSLog(@"[QiAdManager] vungle interstitial load skipped: SDK not initialized");
#endif
        if (completion) { completion(NO); }
        return;
    }
    
    VungleInterstitial *ad = [[VungleInterstitial alloc] initWithPlacementId:kQiVungleInterstitialPlacementID];
    ad.delegate = self;
    self.vungleInterstitial = ad;
    [ad load:nil];
    _pendingInterstitialLoadCompletion = [completion copy];
}

#pragma mark - VungleRewardedDelegate

- (void)rewardedAdDidLoad:(VungleRewarded *)rewarded {
    
#if DEBUG
    NSLog(@"[QiAdManager] vungle rewarded loaded");
#endif
    QiAdLoadCompletion completion = _pendingRewardedLoadCompletion;
    _pendingRewardedLoadCompletion = nil;
    if (completion) { completion(YES); }
}

- (void)rewardedAdDidFailToLoad:(VungleRewarded *)rewarded withError:(NSError *)withError {
    
#if DEBUG
    NSLog(@"[QiAdManager] vungle rewarded load failed: %@", withError.localizedDescription);
#endif
    self.vungleRewarded = nil;
    QiAdLoadCompletion completion = _pendingRewardedLoadCompletion;
    _pendingRewardedLoadCompletion = nil;
    if (completion) { completion(NO); }
}

- (void)rewardedAdDidFailToPresent:(VungleRewarded *)rewarded withError:(NSError *)withError {
    
#if DEBUG
    NSLog(@"[QiAdManager] vungle rewarded present failed: %@", withError.localizedDescription);
#endif
    self.vungleRewarded = nil;
    [self reloadAfterFullScreenClosed];
}

- (void)rewardedAdDidClose:(VungleRewarded *)rewarded {
    
    self.vungleRewarded = nil;
    [self reloadAfterFullScreenClosed];
}

#pragma mark - VungleInterstitialDelegate

- (void)interstitialAdDidLoad:(VungleInterstitial *)interstitial {
    
#if DEBUG
    NSLog(@"[QiAdManager] vungle interstitial loaded");
#endif
    QiAdLoadCompletion completion = _pendingInterstitialLoadCompletion;
    _pendingInterstitialLoadCompletion = nil;
    if (completion) { completion(YES); }
}

- (void)interstitialAdDidFailToLoad:(VungleInterstitial *)interstitial withError:(NSError *)withError {
    
#if DEBUG
    NSLog(@"[QiAdManager] vungle interstitial load failed: %@", withError.localizedDescription);
#endif
    self.vungleInterstitial = nil;
    QiAdLoadCompletion completion = _pendingInterstitialLoadCompletion;
    _pendingInterstitialLoadCompletion = nil;
    if (completion) { completion(NO); }
}

- (void)interstitialAdDidFailToPresent:(VungleInterstitial *)interstitial withError:(NSError *)withError {
    
#if DEBUG
    NSLog(@"[QiAdManager] vungle interstitial present failed: %@", withError.localizedDescription);
#endif
    self.vungleInterstitial = nil;
    [self reloadAfterFullScreenClosed];
}

- (void)interstitialAdDidClose:(VungleInterstitial *)interstitial {
    
    self.vungleInterstitial = nil;
    [self reloadAfterFullScreenClosed];
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
    QiAdPlatform platform = _pendingPlatform;
    _pendingCompletion = nil;
    if (completion) {
        [self loadAdOfType:type platform:platform completion:completion];
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
