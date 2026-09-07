//
//  QiAdManager.h
//  QiGames
//
//  Ad management abstraction: unified entry point for loading and playing
//  rewarded video and interstitial ads. Currently integrates the real AdMob
//  implementation (Google-Mobile-Ads-SDK 11.7.0, integrated via CocoaPods);
//  ad unit IDs are defined centrally at the top of the implementation file.
//  The QiAdPlatform enum additionally lists the other five ad networks
//  (Meta / Vungle / Chartboost / InMobi / Unity Ads) installed via CocoaPods —
//  they are shown in the hidden ad panel as placeholders until their platform
//  IDs and adapters are configured.
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
 *  Ad network platform enum (display order in the hidden ad panel = row order).
 *  Only QiAdPlatformAdMob has a real implementation; the rest are placeholders
 *  until their platform IDs and integration are configured.
 */
typedef NS_ENUM(NSUInteger, QiAdPlatform) {
    QiAdPlatformAdMob,     //!< AdMob (Google-Mobile-Ads-SDK 11.7.0, via CocoaPods; real implementation)
    QiAdPlatformMeta,      //!< Meta Audience Network (FBAudienceNetwork, placeholder)
    QiAdPlatformVungle,    //!< Vungle / Liftoff (VungleSDK-iOS, placeholder)
    QiAdPlatformChartboost,//!< Chartboost (ChartboostSDK, placeholder)
    QiAdPlatformInMobi,    //!< InMobi (InMobiSDK, placeholder)
    QiAdPlatformUnityAds,  //!< Unity Ads (UnityAds, placeholder)
};

/**
 *  Ad load completion callback.
 *
 *  @param success YES if the ad loaded successfully; NO on failure or no ad.
 */
typedef void (^QiAdLoadCompletion)(BOOL success);

/**
 *  Rewarded-playback completion callback (business reward flow): reports
 *  whether the user watched the ad to the end (earned), whether an ad was
 *  actually presented, and the result of the automatic reload after playback.
 *
 *  @param earned   YES when the user earned the reward (watched to the end);
 *                  NO when the ad was closed early.
 *  @param shown    YES when a rewarded ad was presented; NO when none was ready.
 *  @param reloaded Reload result after playback (NO when nothing was shown).
 */
typedef void (^QiRewardedPlayCompletion)(BOOL earned, BOOL shown, BOOL reloaded);

/**
 *  Ad manager: unified entry point for loading and playing rewarded /
 *  interstitial ads (AdMob implementation).
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
 *  Plays the given ad type (calls the matching AdMob show API).
 *  Automatically reloads that ad type after playback finishes.
 *
 *  @param type       Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param completion Callback after playback and reload (success indicates whether the reload succeeded).
 *  @return None.
 */
- (void)showAdOfType:(QiAdType)type completion:(QiAdLoadCompletion)completion;

/**
 *  Returns whether the given ad type is loaded and ready to play
 *  (canPresent pre-check; does not trigger a load).
 *
 *  @param type Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @return YES if the ad is ready to play; NO otherwise.
 */
- (BOOL)isAdReadyOfType:(QiAdType)type;

/**
 *  Plays the rewarded ad for a business reward (e.g. an ad-watched unlock).
 *  When the ad is ready it is presented and the completion reports whether the
 *  user watched it to the end (earned); AdMob auto-reloads that ad type after
 *  playback. When no rewarded ad is ready, nothing is presented and completion
 *  is called with shown = NO so the caller can notify the user and kick off a
 *  load for the next attempt.
 *
 *  @param completion Reward-aware playback callback (may be nil).
 *  @return None.
 */
- (void)showRewardedAdForRewardWithCompletion:(nullable QiRewardedPlayCompletion)completion;

@end

NS_ASSUME_NONNULL_END
