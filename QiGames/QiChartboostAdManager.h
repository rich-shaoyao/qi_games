//
//  QiChartboostAdManager.h
//  QiGames
//
//  Ad management abstraction for the Chartboost network (ChartboostSDK 9.14.0,
//  integrated as a static xcframework under QiGames/Vendor/Chartboost),
//  mirroring QiAdManager's public API so the hidden ad panel can drive AdMob,
//  Vungle, InMobi and Chartboost uniformly. Chartboost app ID / signature are
//  initialized in AppDelegate (kQiChartboostAppID / kQiChartboostAppSignature);
//  rewarded / interstitial locations are defined at the top of the
//  implementation file.
//
//  NOTE: ChartboostSDK 9.14.0 is built with Xcode 26 / iOS 26 SDK (Swift 6.2);
//  linking it requires an Xcode 26 toolchain (see README "开发环境").
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Chartboost ad type enum. Rewarded and interstitial are distinct ad classes
 *  in the Chartboost SDK (CHBRewarded / CHBInterstitial); each is addressed by
 *  its own location string.
 */
typedef NS_ENUM(NSUInteger, QiChartboostAdType) {
    QiChartboostAdTypeRewarded,     //!< Rewarded video (CHBRewarded)
    QiChartboostAdTypeInterstitial, //!< Interstitial (CHBInterstitial)
};

/**
 *  Chartboost ad load completion callback.
 *
 *  @param success YES if the ad loaded successfully; NO on failure or no ad.
 */
typedef void (^QiChartboostAdLoadCompletion)(BOOL success);

/**
 *  Chartboost ad manager: unified entry point for loading and playing
 *  Chartboost rewarded / interstitial ads, with the same lifecycle semantics
 *  as QiAdManager (auto reload after playback).
 */
@interface QiChartboostAdManager : NSObject

/**
 *  Returns the Chartboost ad manager singleton.
 *
 *  @return The QiChartboostAdManager singleton instance.
 */
+ (instancetype)sharedManager;

/**
 *  Loads the given Chartboost ad type.
 *
 *  @param type       Ad type (QiChartboostAdTypeRewarded / QiChartboostAdTypeInterstitial).
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadAdOfType:(QiChartboostAdType)type completion:(QiChartboostAdLoadCompletion)completion;

/**
 *  Plays the given Chartboost ad type. Automatically reloads that ad type
 *  after playback finishes (or immediately when no ad is ready).
 *
 *  @param type       Ad type (QiChartboostAdTypeRewarded / QiChartboostAdTypeInterstitial).
 *  @param completion Callback after playback and reload (success indicates whether the reload succeeded).
 *  @return None.
 */
- (void)showAdOfType:(QiChartboostAdType)type completion:(QiChartboostAdLoadCompletion)completion;

/**
 *  Returns whether the given Chartboost ad type is loaded (cached) and ready
 *  to play.
 *
 *  @param type Ad type (QiChartboostAdTypeRewarded / QiChartboostAdTypeInterstitial).
 *  @return YES if the ad is ready to play; NO otherwise.
 */
- (BOOL)isAdReadyOfType:(QiChartboostAdType)type;

@end

NS_ASSUME_NONNULL_END
