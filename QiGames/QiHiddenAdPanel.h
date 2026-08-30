//
//  QiHiddenAdPanel.h
//  QiGames
//
//  Hidden ad panel: used for ad triggering tests by the publishing channel.
//  Trigger condition: the text field in the home view == "show**show**show".
//  Note: once the panel is shown, no toast / alert is displayed (per the spec).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Hidden ad panel: overlaid on the current keyWindow, providing load-status
 *  display, playback and auto-refresh for the rewarded / interstitial ad slots.
 */
@interface QiHiddenAdPanel : NSObject

/**
 *  Shows the hidden ad panel (overlaid on the current keyWindow, covering the
 *  full screen). Automatically loads all platform ads on first open.
 *
 *  @return None.
 */
+ (void)show;

/**
 *  Dismisses the hidden ad panel.
 *
 *  @return None.
 */
+ (void)dismiss;

@end

NS_ASSUME_NONNULL_END
