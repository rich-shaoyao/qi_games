//
//  QiAdManager.h
//  QiGames
//
//  Ad management abstraction: provides a unified entry point for loading and
//  playing rewarded video and interstitial ads. It integrates the real AdMob
//  (GoogleMobileAds v11.3.0; the local Xcode 15.2-compatible version should be
//  bumped back to v11.7.0 in an Xcode 16 environment before delivery)
//  implementation while keeping the public API unchanged; ad unit IDs live at
//  the top of the implementation file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Ad type enum.
 */
typedef NS_ENUM(NSUInteger, QiAdType) {
    QiAdTypeRewarded,     //!< Rewarded video
    QiAdTypeInterstitial, //!< Interstitial
};

/**
 *  Ad network platform enum.
 */
typedef NS_ENUM(NSUInteger, QiAdPlatform) {
    QiAdPlatformAdMob,  //!< AdMob (GoogleMobileAds, integrated via SPM)
    QiAdPlatformVungle, //!< Vungle / Liftoff (VungleAds 7.0.0, manual xcframework)
    QiAdPlatformInMobi, //!< InMobi (InMobiSDK 11.4.0, manual xcframework)
    QiAdPlatformChartboost, //!< Chartboost (ChartboostSDK 9.14.0, manual xcframework; links with Xcode 26 toolchain)
};

/**
 *  Ad load completion callback.
 *
 *  @param success YES if the ad loaded successfully; NO on failure or no ad.
 */
typedef void (^QiAdLoadCompletion)(BOOL success);

/**
 *  Ad manager: unified entry point for loading and playing rewarded /
 *  interstitial ads.
 */
@interface QiAdManager : NSObject

/**
 *  Returns the ad manager singleton.
 *
 *  @return The QiAdManager singleton instance.
 */
+ (instancetype)sharedManager;

/**
 *  Loads the given ad type (calls the matching AdMob load API).
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadAdOfType:(QiAdType)type completion:(QiAdLoadCompletion)completion;

/**
 *  Loads the given ad type on the given platform (AdMob / Vungle).
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform   Ad network platform (QiAdPlatformAdMob / QiAdPlatformVungle).
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadAdOfType:(QiAdType)type platform:(QiAdPlatform)platform completion:(QiAdLoadCompletion)completion;

/**
 *  Plays the given ad type (calls the matching AdMob show API).
 *  Automatically reloads that ad type after playback finishes.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param completion Callback after playback and reload (success indicates whether the reload succeeded).
 *  @return None.
 */
- (void)showAdOfType:(QiAdType)type completion:(QiAdLoadCompletion)completion;

/**
 *  Plays the given ad type on the given platform (AdMob / Vungle).
 *  Automatically reloads that ad type after playback finishes.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform   Ad network platform (QiAdPlatformAdMob / QiAdPlatformVungle).
 *  @param completion Callback after playback and reload (success indicates whether the reload succeeded).
 *  @return None.
 */
- (void)showAdOfType:(QiAdType)type platform:(QiAdPlatform)platform completion:(QiAdLoadCompletion)completion;

/**
 *  Returns whether the given ad type is loaded and ready to play on the given
 *  platform (canPlayAd / isReady pre-check; does not trigger a load).
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform (QiAdPlatformAdMob / QiAdPlatformVungle / QiAdPlatformInMobi).
 *  @return YES if the ad is ready to play; NO otherwise.
 */
- (BOOL)isAdReadyOfType:(QiAdType)type platform:(QiAdPlatform)platform;

@end

NS_ASSUME_NONNULL_END
