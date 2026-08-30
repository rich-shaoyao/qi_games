//
//  main.m
//  QiGames
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

/**
 *  App entry point: creates the autorelease pool and starts the UIKit main loop.
 *
 *  @param argc Number of command-line arguments.
 *  @param argv Array of command-line arguments.
 *  @return The return value of UIApplicationMain (the app exit code).
 */
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
