//
//  QiInMobiAdManager.h
//  QiGames
//
//  Ad management abstraction for the InMobi network (InMobiSDK 11.4.0),
//  mirroring QiAdManager's public API so the hidden ad panel can drive AdMob
//  and InMobi uniformly. Placement IDs are defined centrally at the top of the
//  implementation file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  InMobi ad type enum. Note: in InMobi SDK 11.x both rewarded video and
 *  interstitial are served by the same IMInterstitial class; the placement
 *  type is configured on the InMobi portal.
 */
typedef NS_ENUM(NSUInteger, QiInMobiAdType) {
    QiInMobiAdTypeRewarded,     //!< Rewarded video (placement configured as rewarded on the portal)
    QiInMobiAdTypeInterstitial, //!< Interstitial (placement configured as interstitial on the portal)
};

/**
 *  InMobi ad load completion callback.
 *
 *  @param success YES if the ad loaded successfully; NO on failure or no ad.
 */
typedef void (^QiInMobiAdLoadCompletion)(BOOL success);

/**
 *  InMobi ad manager: unified entry point for loading and playing InMobi
 *  rewarded / interstitial ads, with the same lifecycle semantics as
 *  QiAdManager (auto reload after playback).
 */
@interface QiInMobiAdManager : NSObject

/**
 *  Returns the InMobi ad manager singleton.
 *
 *  @return The QiInMobiAdManager singleton instance.
 */
+ (instancetype)sharedManager;

/**
 *  Loads the given InMobi ad type.
 *
 *  @param type       Ad type (QiInMobiAdTypeRewarded / QiInMobiAdTypeInterstitial).
 *  @param completion Load completion callback (success indicates whether the load succeeded).
 *  @return None.
 */
- (void)loadAdOfType:(QiInMobiAdType)type completion:(QiInMobiAdLoadCompletion)completion;

/**
 *  Plays the given InMobi ad type. Automatically reloads that ad type after
 *  playback finishes (or immediately when no ad is ready).
 *
 *  @param type       Ad type (QiInMobiAdTypeRewarded / QiInMobiAdTypeInterstitial).
 *  @param completion Callback after playback and reload (success indicates whether the reload succeeded).
 *  @return None.
 */
- (void)showAdOfType:(QiInMobiAdType)type completion:(QiInMobiAdLoadCompletion)completion;

/**
 *  Returns whether the given InMobi ad type is loaded and ready to play.
 *
 *  @param type Ad type (QiInMobiAdTypeRewarded / QiInMobiAdTypeInterstitial).
 *  @return YES if the ad is ready to play; NO otherwise.
 */
- (BOOL)isAdReadyOfType:(QiInMobiAdType)type;

@end

NS_ASSUME_NONNULL_END
