//
//  AppDelegate.m
//  QiGames
//

#import "AppDelegate.h"
#import "QiDrawViewController.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <UserMessagingPlatform/UserMessagingPlatform.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

/**
 *  App launch completion callback: creates the window, shows the Word Charades
 *  game page (QiDraw.storyboard) as the root view controller, then initializes
 *  the AdMob SDK (after the ATT prompt on iOS 14+).
 *
 *  @param application   The current UIApplication instance.
 *  @param launchOptions Launch options (information carried when the app is opened externally).
 *  @return YES if the app can launch normally; NO to abort the launch flow.
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    UIStoryboard *drawStoryboard = [UIStoryboard storyboardWithName:@"QiDraw" bundle:nil];
    QiDrawViewController *drawViewController = [drawStoryboard instantiateInitialViewController];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:drawViewController];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = navigationController;
    [self.window makeKeyAndVisible];
    
    // AdMob is initialized after the ATT prompt (iOS 14+) so the SDK can serve
    // personalized ads when the user grants tracking permission; the App ID is
    // configured in Info.plist as GADApplicationIdentifier. Rewarded / interstitial
    // ads are loaded on demand through QiAdManager.
    [self qi_initializeAdMobAfterTrackingAuthorization];
    
    // UMP consent flow (GDPR / EEA + UK + Brazil). Must be requested before ads
    // are loaded; QiAdManager loads ads on demand, so consent is normally ready
    // by the time the first ad is requested.
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
