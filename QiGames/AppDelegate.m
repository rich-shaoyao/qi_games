//
//  AppDelegate.m
//  QiGames
//

#import "AppDelegate.h"
#import "QiDrawViewController.h"
#import "QiAdManager.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <InMobiSDK/InMobiSDK-Swift.h>
#import <UserMessagingPlatform/UserMessagingPlatform.h>
#import <VungleAdsSDK/VungleAdsSDK.h>

// FIX-04: InMobi account ID. TODO: replace the placeholder with the real InMobi
// account ID from https://publisher.inmobi.com before delivery. The SDK only
// serves ads once a valid account ID is configured.
static NSString * const kQiInMobiAccountID = @"REPLACE_WITH_INMOBI_ACCOUNT_ID";

// FIX-04: Vungle / Liftoff app ID. TODO: replace the placeholder with the real
// Vungle app ID from the Liftoff dashboard before delivery. The SDK only serves
// ads once a valid app ID is configured (placement IDs live in QiAdManager.m).
static NSString * const kQiVungleAppID = @"REPLACE_WITH_VUNGLE_APP_ID";

@interface AppDelegate ()

@end

@implementation AppDelegate

/**
 *  App launch completion callback.
 *
 *  @param application   The current UIApplication instance.
 *  @param launchOptions Launch options (information carried when the app is opened externally).
 *  @return YES if the app can launch normally; NO to abort the launch flow.
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // FIX-04: Initialize the InMobi SDK before any other InMobi API is used.
    // The account ID is a placeholder (kQiInMobiAccountID above) — replace it
    // with the real InMobi account ID before delivery.
    [IMSdk initWithAccountID:kQiInMobiAccountID andCompletionHandler:^(NSError *_Nullable error) {
        if (error) {
#if DEBUG
            NSLog(@"[AppDelegate] InMobi SDK init failed: %@", error.localizedDescription);
#endif
        }
    }];
    
    // FIX-04: Initialize the Vungle / Liftoff SDK. The app ID is a placeholder
    // (kQiVungleAppID above) — replace it with the real Vungle app ID before
    // delivery. Ad loading through QiAdManager reports failure until then.
    [VungleAds initWithAppId:kQiVungleAppID completion:^(NSError *_Nullable error) {
        if (error) {
#if DEBUG
            NSLog(@"[AppDelegate] Vungle SDK init failed: %@", error.localizedDescription);
#endif
        }
#if DEBUG
        else {
            NSLog(@"[AppDelegate] Vungle SDK init complete");
        }
#endif
    }];
    
    // FIX-02: AdMob is initialized in qi_initializeAdMobAfterTrackingAuthorization
    // (after the ATT prompt on iOS 14+, or directly on older iOS), so the SDK can
    // serve personalized ads when the user grants tracking permission. The app ID
    // is configured in Info.plist as GADApplicationIdentifier; rewarded / interstitial
    // ads are loaded on demand through QiAdManager.
    
    // Entry point: opening the app goes straight to the Word Charades game page
    // (QiDraw.storyboard); the Main.storyboard home page is no longer used.
    UIStoryboard *drawStoryboard = [UIStoryboard storyboardWithName:@"QiDraw" bundle:nil];
    QiDrawViewController *drawViewController = [drawStoryboard instantiateInitialViewController];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:drawViewController];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = navigationController;
    [self.window makeKeyAndVisible];
    
    // FIX-05: App Tracking Transparency (iOS 14+): request IDFA permission before
    // initializing AdMob so personalized ads can be served. On iOS < 14 AdMob is
    // initialized directly. The ATT usage description lives in Info.plist
    // (NSUserTrackingUsageDescription).
    [self qi_initializeAdMobAfterTrackingAuthorization];
    
    // FIX-05: UMP consent flow (GDPR / EEA + UK + Brazil). Must be requested before
    // ads are loaded; QiAdManager loads ads on demand, so consent is normally ready
    // by the time the first ad is requested. The UMP SDK ships as the
    // GoogleUserMessagingPlatform SPM dependency.
    [self qi_requestConsentFromViewController:self.window.rootViewController];
    
    return YES;
}

/**
 *  Initializes the AdMob SDK. On iOS 14+ the ATT prompt is requested first so
 *  that AdMob can serve personalized ads when the user opts in; on older iOS
 *  versions the SDK is initialized directly.
 *
 *  @return None.
 */
- (void)qi_initializeAdMobAfterTrackingAuthorization {
    if (@available(iOS 14, *)) {
        [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus authorizationStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[GADMobileAds sharedInstance] startWithCompletionHandler:^(GADInitializationStatus *_Nonnull status) {
                }];
            });
        }];
    } else {
        [[GADMobileAds sharedInstance] startWithCompletionHandler:^(GADInitializationStatus *_Nonnull status) {
        }];
    }
}

/**
 *  Requests consent information and, when required, presents the UMP consent
 *  form (GDPR / EEA + UK + Brazil). Call this before loading ads.
 *
 *  @param viewController The view controller from which the consent form is
 *                        presented (the root view controller in this app).
 *  @return None.
 */
- (void)qi_requestConsentFromViewController:(UIViewController *)viewController {
    UMPRequestParameters *parameters = [[UMPRequestParameters alloc] init];
    parameters.tagForUnderAgeOfConsent = NO;
    [UMPConsentInformation.sharedInstance requestConsentInfoUpdateWithParameters:parameters completionHandler:^(NSError *_Nullable consentError) {
        if (consentError) {
#if DEBUG
            NSLog(@"[AppDelegate] UMP consent info update failed: %@", consentError.localizedDescription);
#endif
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [UMPConsentForm loadAndPresentIfRequiredFromViewController:viewController completionHandler:^(NSError *_Nullable formError) {
                if (formError) {
#if DEBUG
                    NSLog(@"[AppDelegate] UMP consent form load/present failed: %@", formError.localizedDescription);
#endif
                }
            }];
        });
    }];
}

/**
 *  Callback when the app is about to lose focus (e.g. interrupted by a call
 *  or a system alert).
 *
 *  @param application The current UIApplication instance.
 *  @return None.
 */
- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}

/**
 *  Callback when the app enters the background.
 *
 *  @param application The current UIApplication instance.
 *  @return None.
 */
- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

/**
 *  Callback when the app is about to return from the background to the foreground.
 *
 *  @param application The current UIApplication instance.
 *  @return None.
 */
- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}

/**
 *  Callback when the app is about to be terminated.
 *
 *  @param application The current UIApplication instance.
 *  @return None.
 */
- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
