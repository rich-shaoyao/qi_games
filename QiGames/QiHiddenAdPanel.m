//
//  QiHiddenAdPanel.m
//  QiGames
//
//  Hidden ad panel implementation.
//  Requirements (per the spec):
//  1. Automatically loads all platform ads on first open; the corresponding
//     button highlights once loaded, and turns gray on failure / no ad;
//  2. Tapping Rewarded Video grays it out, waits a random 5-10 second countdown,
//     then restores highlight/gray according to the load result;
//  3. Tapping Interstitial follows the same refresh logic as rewarded video;
//  4. Tapping an ad-slot button plays the ad; after playback it automatically
//     reloads and updates the button state;
//  5. Once the panel is shown, the app does not show toasts / alerts.
//
//  Style: full-width landscape panel filling the window (small margins on the
//  sides and at the top/bottom) -- white rounded container; one header row with
//  the ✕ close button at the top-right and two column titles "Rewarded Video" /
//  "Interstitial"; below, one row per ad platform (AdMob / Meta / Vungle /
//  Chartboost / InMobi / Unity Ads), each row holding the platform's two ad
//  windows (Rewarded | Interstitial) evenly distributed side by side across the
//  full width -- light blue (rgb 163,214,252) for Rewarded, light orange
//  (rgb 255,217,171) for Interstitial. No platform name column. The loaded /
//  tappable state uses a solid blue background (rgb 0,152,251) with white text;
//  idle rows show their status in the window.
//

#import "QiHiddenAdPanel.h"
#import "QiAdManager.h"

// The whole implementation below is compiled only when the hidden ad panel
// switch is on (default 1). App Store packaging compiles with the switch off
// (see QiHiddenAdPanel.h / Configs/AppStore.xcconfig), excluding this file's
// contents from the binary entirely.
#if HIDDEN_AD_PANEL_ENABLED

static NSString * const kQiPlatformNameAdMob      = @"AdMob";
static NSString * const kQiPlatformNameMeta       = @"Meta";
static NSString * const kQiPlatformNameVungle     = @"Vungle";
static NSString * const kQiPlatformNameChartboost = @"Chartboost";
static NSString * const kQiPlatformNameInMobi     = @"InMobi";
static NSString * const kQiPlatformNameUnityAds   = @"Unity Ads";

// Panel style colors (per the attached sample image): white rounded container,
// black titles, light-blue Rewarded window / light-orange Interstitial window,
// solid blue for the loaded/highlighted state.
static UIColor *QiPanelWhiteColor(void) {
    return [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:1.00];
}
static UIColor *QiPanelTitleColor(void) {
    return [UIColor blackColor];
}
static UIColor *QiPanelRewardedColumnColor(void) {
    return [UIColor colorWithRed:163.0/255.0 green:214.0/255.0 blue:252.0/255.0 alpha:1.0];
}
static UIColor *QiPanelInterstitialColumnColor(void) {
    return [UIColor colorWithRed:255.0/255.0 green:217.0/255.0 blue:171.0/255.0 alpha:1.0];
}
static UIColor *QiPanelHighlightColor(void) {
    return [UIColor colorWithRed:0.0/255.0 green:152.0/255.0 blue:251.0/255.0 alpha:1.0];
}

/**
 *  Returns the resting (idle / loading / not-connected) window color of the
 *  given ad type: light blue for Rewarded Video, light orange for Interstitial
 *  (per the sample image).
 *
 *  @param type Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @return The window background color.
 */
static UIColor *QiPanelColumnColorForType(QiAdType type) {
    return (type == QiAdTypeRewarded) ? QiPanelRewardedColumnColor() : QiPanelInterstitialColumnColor();
}

@interface QiHiddenAdPanel ()

@property (nonatomic, strong) UIView *overlayView;             //!< Full-screen overlay
@property (nonatomic, strong) UIView *containerView;           //!< Panel container
@property (nonatomic, strong) UIButton *closeButton;           //!< Close button (✕ top-right)
@property (nonatomic, strong) UILabel *rewardedTitleLabel;     //!< Rewarded Video column title
@property (nonatomic, strong) UILabel *interstitialTitleLabel; //!< Interstitial column title
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIButton *> *rewardedButtons;     //!< Rewarded ad window buttons, keyed by QiAdPlatform
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIButton *> *interstitialButtons; //!< Interstitial ad window buttons, keyed by QiAdPlatform

// Per (type, platform) countdown refresh state, keyed by keyForType:platform:.
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSTimer *> *countDownTimers; //!< Countdown timers per ad slot
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *remainingSeconds; //!< Remaining seconds per ad slot
@property (nonatomic, strong) NSMutableSet<NSNumber *> *busyKeys;                           //!< Ad slots currently in refresh countdown

@end

@implementation QiHiddenAdPanel

static QiHiddenAdPanel *_sharedPanel = nil;

/**
 *  The list of shown platforms (order = row order inside a column). Only AdMob
 *  has a real implementation; the others are placeholders until their platform
 *  IDs and integration are configured.
 */
static NSArray<NSNumber *> *QiPanelPlatforms(void) {
    return @[ @(QiAdPlatformAdMob), @(QiAdPlatformMeta), @(QiAdPlatformVungle),
              @(QiAdPlatformChartboost), @(QiAdPlatformInMobi), @(QiAdPlatformUnityAds) ];
}

/**
 *  Returns whether the given platform is actually connected (loadable / playable).
 *  Only AdMob is integrated for now; the remaining five platforms are placeholders.
 *
 *  @param platform Ad network platform.
 *  @return YES if the platform has a real implementation; NO otherwise.
 */
static BOOL QiPlatformConnected(QiAdPlatform platform) {
    return (platform == QiAdPlatformAdMob);
}

#pragma mark - Lifecycle

/**
 *  Returns the panel singleton.
 *
 *  @return The QiHiddenAdPanel singleton instance.
 */
+ (instancetype)sharedPanel {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedPanel = [[QiHiddenAdPanel alloc] init];
    });
    return _sharedPanel;
}

#pragma mark - Public

/**
 *  Shows the hidden ad panel.
 *
 *  @return None.
 */
+ (void)show {
    
    [[self sharedPanel] showPanel];
}

/**
 *  Dismisses the hidden ad panel.
 *
 *  @return None.
 */
+ (void)dismiss {
    
    [[self sharedPanel] dismissPanel];
}

#pragma mark - Show / Dismiss

/**
 *  Shows the panel: creates the full-screen overlay and container, and
 *  automatically loads all platform ads on first open.
 *
 *  @return None.
 */
- (void)showPanel {
    
    UIWindow *keyWindow = [[self class] keyWindow];
    if (!keyWindow) {
        return;
    }
    
    if (_overlayView.superview) {
        return; //!< Already showing, do not show again
    }
    
#if DEBUG
    NSLog(@"[QiHiddenAdPanel] show");
#endif
    
    _overlayView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    _overlayView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    _overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [keyWindow addSubview:_overlayView];
    
    [self buildContainer];
    [_overlayView addSubview:_containerView];
    
    // First open: auto-load ads for connected platforms (AdMob rewarded +
    // interstitial); placeholder platforms show as "not connected" (grayed).
    for (NSNumber *platformNumber in QiPanelPlatforms()) {
        QiAdPlatform platform = [platformNumber integerValue];
        if (!QiPlatformConnected(platform)) {
            [self setButtonForType:QiAdTypeRewarded platform:platform enabled:NO title:[self slotTitleForType:QiAdTypeRewarded state:@"未接入"]];
            [self setButtonForType:QiAdTypeInterstitial platform:platform enabled:NO title:[self slotTitleForType:QiAdTypeInterstitial state:@"未接入"]];
            continue;
        }
        [self setButtonForType:QiAdTypeRewarded platform:platform enabled:NO title:[self slotTitleForType:QiAdTypeRewarded state:@"加载中…"]];
        [self setButtonForType:QiAdTypeInterstitial platform:platform enabled:NO title:[self slotTitleForType:QiAdTypeInterstitial state:@"加载中…"]];
        [self loadAdForType:QiAdTypeRewarded platform:platform];
        [self loadAdForType:QiAdTypeInterstitial platform:platform];
    }
}

/**
 *  Dismisses the panel: invalidates countdown timers and removes the overlay.
 *
 *  @return None.
 */
- (void)dismissPanel {
    
    [self invalidateAllTimers];
    [_overlayView removeFromSuperview];
    _overlayView = nil;
    _containerView = nil;
}

#pragma mark - Build UI

/**
 *  Builds the panel UI: a container that stretches across the window (small
 *  margin on each side) and fills its height (small blank area at the top and
 *  bottom) -- one header row with the ✕ close button at the top-right and the
 *  two column titles (Rewarded Video / Interstitial); then one row per ad
 *  platform (AdMob / Meta / Vungle / Chartboost / InMobi / Unity Ads), each row
 *  holding the platform's two ad windows (Rewarded | Interstitial) evenly
 *  distributed side by side over the full width. No platform name column.
 *
 *  @return None.
 */
- (void)buildContainer {
    
    _rewardedButtons = [NSMutableDictionary dictionary];
    _interstitialButtons = [NSMutableDictionary dictionary];
    
    // Full-width panel: stretches across the window (small margin each side)
    // and fills its height, leaving only a little blank space at top/bottom.
    CGFloat edgeMargin = 10.0; //!< Horizontal side margins
    CGFloat verticalEdge = 12.0; //!< Top / bottom blank margins
    CGFloat panelWidth = CGRectGetWidth(_overlayView.bounds) - edgeMargin * 2.0;
    
    // Horizontal layout (left to right):
    //   pad(12) | Rewarded window | gap(8) | Interstitial window | pad(12)
    //   The two ad windows are evenly distributed over the full width
    //   (no platform name column).
    CGFloat padX = 12.0;
    CGFloat columnGap = 8.0;
    CGFloat slotsAreaWidth = panelWidth - padX * 2.0;
    CGFloat slotWidth = (slotsAreaWidth - columnGap) / 2.0;
    CGFloat slotX = padX;
    
    // Vertical layout: header row, then 6 platform rows evenly filling the
    // remaining height. Row height is capped so the panel does not stretch
    // absurdly tall when the window is portrait; in landscape the rows fill
    // the window height leaving only the small top/bottom margins.
    CGFloat headerHeight = 34.0; //!< Close button + column titles
    CGFloat rowGap = 6.0;
    CGFloat maxRowHeight = 96.0; //!< Cap for portrait screens
    CGFloat panelHeight = CGRectGetHeight(_overlayView.bounds) - verticalEdge * 2.0;
    CGFloat rowHeight = MIN(maxRowHeight, (panelHeight - headerHeight - 5.0 * rowGap) / 6.0);
    panelHeight = headerHeight + 6.0 * rowHeight + 5.0 * rowGap; //!< Recompute if the cap kicked in
    CGFloat rowTop = headerHeight;
    
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelWidth, panelHeight)];
    _containerView.center = CGPointMake(CGRectGetMidX(_overlayView.bounds), CGRectGetMidY(_overlayView.bounds));
    _containerView.backgroundColor = QiPanelWhiteColor();
    _containerView.layer.cornerRadius = 12.0;
    _containerView.layer.masksToBounds = YES;
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    // Close button (✕ top-right)
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.frame = CGRectMake(panelWidth - 40.0, 6.0, 32.0, 32.0);
    [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont systemFontOfSize:18.0];
    _closeButton.tintColor = [UIColor colorWithWhite:0.4 alpha:1.0];
    [_closeButton addTarget:self action:@selector(closeButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_closeButton];
    
    // Column titles (Rewarded Video / Interstitial), aligned above their windows
    _rewardedTitleLabel = [self makeColumnTitleLabelWithFrame:CGRectMake(slotX, 7.0, slotWidth, 20.0)
                                                         text:@"Rewarded Video"];
    [_containerView addSubview:_rewardedTitleLabel];
    _interstitialTitleLabel = [self makeColumnTitleLabelWithFrame:CGRectMake(slotX + slotWidth + columnGap, 7.0, slotWidth, 20.0)
                                                             text:@"Interstitial"];
    [_containerView addSubview:_interstitialTitleLabel];
    
    // One row per platform: Rewarded window + Interstitial window side by side
    NSArray<NSNumber *> *platforms = QiPanelPlatforms();
    for (NSUInteger i = 0; i < platforms.count; i++) {
        QiAdPlatform platform = [platforms[i] integerValue];
        CGFloat rowY = rowTop + i * (rowHeight + rowGap);
        
        // Rewarded window
        NSInteger rewardedTag = [self keyForType:QiAdTypeRewarded platform:platform].integerValue;
        UIButton *rewardedButton = [self makeSlotButtonWithFrame:CGRectMake(slotX, rowY, slotWidth, rowHeight)
                                                             tag:rewardedTag];
        [_containerView addSubview:rewardedButton];
        _rewardedButtons[@(platform)] = rewardedButton;
        
        // Interstitial window
        NSInteger interstitialTag = [self keyForType:QiAdTypeInterstitial platform:platform].integerValue;
        UIButton *interstitialButton = [self makeSlotButtonWithFrame:CGRectMake(slotX + slotWidth + columnGap, rowY, slotWidth, rowHeight)
                                                                 tag:interstitialTag];
        [_containerView addSubview:interstitialButton];
        _interstitialButtons[@(platform)] = interstitialButton;
    }
}

/**
 *  Creates a column title label (Rewarded Video / Interstitial).
 *
 *  @param frame The label frame.
 *  @param text  The title text.
 *  @return The configured label.
 */
- (UILabel *)makeColumnTitleLabelWithFrame:(CGRect)frame text:(NSString *)text {
    
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.font = [UIFont boldSystemFontOfSize:14.0];
    label.textColor = QiPanelTitleColor();
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

/**
 *  Creates an ad window (slot) button for a platform row. The tag encodes the
 *  (type, platform) key so the tap handler can resolve both from the sender
 *  alone.
 *
 *  @param frame The button frame.
 *  @param tag   The (type, platform) key (see keyForType:platform:).
 *  @return The configured button.
 */
- (UIButton *)makeSlotButtonWithFrame:(CGRect)frame tag:(NSInteger)tag {
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    button.tag = tag;
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    button.layer.cornerRadius = 8.0;
    button.layer.masksToBounds = YES;
    [button addTarget:self action:@selector(platformButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Slot key helpers

/**
 *  Returns the stable key for an ad slot (type, platform).
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform.
 *  @return The slot key.
 */
- (NSNumber *)keyForType:(QiAdType)type platform:(QiAdPlatform)platform {
    
    return @(type * 10 + platform);
}

/**
 *  Resolves the platform display name.
 *
 *  @param platform Ad network platform.
 *  @return The display name (AdMob / Vungle).
 */
- (NSString *)platformName:(QiAdPlatform)platform {
    
    if (platform == QiAdPlatformMeta) { return kQiPlatformNameMeta; }
    if (platform == QiAdPlatformVungle) { return kQiPlatformNameVungle; }
    if (platform == QiAdPlatformChartboost) { return kQiPlatformNameChartboost; }
    if (platform == QiAdPlatformInMobi) { return kQiPlatformNameInMobi; }
    if (platform == QiAdPlatformUnityAds) { return kQiPlatformNameUnityAds; }
    return kQiPlatformNameAdMob;
}

/**
 *  Builds the two-line title for an ad window: the Chinese ad-type name on the
 *  first line and the current state on the second. The platform name is not
 *  repeated here -- it is shown by the platform name label of the row.
 *
 *  @param type  Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param state The state text (loading / loaded / not connected / countdown...).
 *  @return The two-line window title.
 */
- (NSString *)slotTitleForType:(QiAdType)type state:(NSString *)state {
    
    NSString *typeName = (type == QiAdTypeRewarded) ? @"激励视频" : @"插屏广告";
    return [NSString stringWithFormat:@"%@\n%@", typeName, state];
}

/**
 *  Returns the platform row button of the given ad slot.
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform.
 *  @return The button (created by buildContainer).
 */
- (UIButton *)buttonForType:(QiAdType)type platform:(QiAdPlatform)platform {
    
    NSDictionary<NSNumber *, UIButton *> *buttons = (type == QiAdTypeRewarded) ? _rewardedButtons : _interstitialButtons;
    return buttons[@(platform)];
}

#pragma mark - Button state

/**
 *  Sets an ad window button state and title: enabled highlights it with the
 *  solid blue background and white text (tappable); disabled keeps the resting
 *  light column color (light blue for Rewarded / light orange for Interstitial)
 *  with white text and is not tappable.
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform.
 *  @param enabled  YES means tappable (highlighted); NO means not tappable (idle).
 *  @param title    The button title to display.
 *  @return None.
 */
- (void)setButtonForType:(QiAdType)type platform:(QiAdPlatform)platform enabled:(BOOL)enabled title:(NSString *)title {
    
    UIButton *button = [self buttonForType:type platform:platform];
    if (!button) { return; }
    button.enabled = enabled;
    [button setTitle:title forState:UIControlStateNormal];
    
    if (enabled) {
        // Highlighted / tappable: solid blue background, white text (per the sample image)
        button.backgroundColor = QiPanelHighlightColor();
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        // Idle / not tappable: resting light column color, white text
        button.backgroundColor = QiPanelColumnColorForType(type);
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
}

#pragma mark - Ad loading / playing

/**
 *  Loads the given ad slot and updates the corresponding button state on
 *  completion.
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform.
 *  @return None.
 */
- (void)loadAdForType:(QiAdType)type platform:(QiAdPlatform)platform {
    
    if (!QiPlatformConnected(platform)) { return; }
    __weak typeof(self) weakSelf = self;
    [[QiAdManager sharedManager] loadAdOfType:type completion:^(BOOL success) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        
        [self updateButtonForType:type platform:platform loaded:success];
    }];
}

/**
 *  Updates the corresponding button by load result: highlights on success,
 *  grays out on failure. If the button is in countdown refresh, the countdown
 *  callback handles the state uniformly.
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform.
 *  @param loaded   YES if the ad loaded successfully; NO on failure / no ad.
 *  @return None.
 */
- (void)updateButtonForType:(QiAdType)type platform:(QiAdPlatform)platform loaded:(BOOL)loaded {
    
    NSNumber *key = [self keyForType:type platform:platform];
    if ([_busyKeys containsObject:key]) { return; } //!< During countdown refresh, state is handled by the countdown callback
    
    NSString *title = loaded ? [self slotTitleForType:type state:@"点击播放"]
                             : [self slotTitleForType:type state:@"暂无广告"];
    [self setButtonForType:type platform:platform enabled:loaded title:title];
    
#if DEBUG
    NSLog(@"[QiHiddenAdPanel] type=%lu platform=%lu loaded=%d", (unsigned long)type, (unsigned long)platform, loaded);
#endif
}

#pragma mark - Actions

/**
 *  Close button tap handler.
 *
 *  @param sender The close button that triggered the event.
 *  @return None.
 */
- (void)closeButtonClicked:(UIButton *)sender {
    
    [[self class] dismiss];
}

/**
 *  Platform row button tap handler: grays out and plays the ad. The tag encodes
 *  the (type, platform) key.
 *
 *  @param sender The platform button that triggered the event.
 *  @return None.
 */
- (void)platformButtonClicked:(UIButton *)sender {
    
    NSInteger key = sender.tag;
    QiAdType type = (QiAdType)(key / 10);
    QiAdPlatform platform = (QiAdPlatform)(key % 10);
    if ([_busyKeys containsObject:@(key)]) { return; }
    [self playAdForType:type platform:platform];
}

/**
 *  Plays the given ad slot: grays the button out showing "Playing", reloads
 *  the ad after playback finishes, then enters a random 5-10 second countdown
 *  to refresh the button state.
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform.
 *  @return None.
 */
- (void)playAdForType:(QiAdType)type platform:(QiAdPlatform)platform {
    
    if (!QiPlatformConnected(platform)) { return; }
    NSNumber *key = [self keyForType:type platform:platform];
    [self setButtonForType:type platform:platform enabled:NO title:[self slotTitleForType:type state:@"播放中…"]];
    
    __weak typeof(self) weakSelf = self;
    [[QiAdManager sharedManager] showAdOfType:type completion:^(BOOL success) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        
        // Auto-reload after playback is already done (showAdOfType loads first,
        // then calls back); start a random 5-10 second countdown with the result.
        [self startCountDownForKey:key loaded:success];
    }];
}

#pragma mark - Count down refresh

/**
 *  Starts the countdown refresh for the given ad slot (random 5-10 sec).
 *
 *  @param key    The (type, platform) slot key.
 *  @param loaded Ad reload result (YES success / NO failure).
 *  @return None.
 */
- (void)startCountDownForKey:(NSNumber *)key loaded:(BOOL)loaded {
    
    NSInteger seconds = 5 + arc4random_uniform(6); //!< Random 5-10 seconds
    [self invalidateTimerForKey:key];
    
    [_busyKeys addObject:key];
    _remainingSeconds[key] = @(seconds);
    _countDownTimers[key] = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(countDownTick:)
                                                           userInfo:@{ @"key" : key, @"loaded" : @(loaded) }
                                                            repeats:YES];
    [self updateCountDownButtonForKey:key];
}

/**
 *  Per-second countdown handling: decrements the remaining seconds and updates
 *  the button title; when it reaches 0, ends the countdown and restores the
 *  button highlight/gray per the ad reload result.
 *
 *  @param timer The countdown timer (userInfo carries the slot key and reload result).
 *  @return None.
 */
- (void)countDownTick:(NSTimer *)timer {
    
    NSNumber *key = timer.userInfo[@"key"];
    BOOL loaded = [timer.userInfo[@"loaded"] boolValue];
    NSInteger remaining = [_remainingSeconds[key] integerValue] - 1;
    _remainingSeconds[key] = @(remaining);
    if (remaining <= 0) {
        [self finishCountDownForKey:key loaded:loaded];
    } else {
        [self updateCountDownButtonForKey:key];
    }
}

/**
 *  Updates the button title during the countdown (keeps it gray, shows only
 *  the remaining seconds).
 *
 *  @param key The (type, platform) slot key.
 *  @return None.
 */
- (void)updateCountDownButtonForKey:(NSNumber *)key {
    
    // During the countdown the button stays idle (not tappable); only the
    // remaining-seconds hint is updated. Note: no toast / alert is shown once
    // the panel is up; all countdown feedback is contained in the button title.
    NSInteger keyValue = key.integerValue;
    QiAdType type = (QiAdType)(keyValue / 10);
    NSInteger remaining = [_remainingSeconds[key] integerValue];
    [self setButtonForType:type platform:(QiAdPlatform)(keyValue % 10) enabled:NO
                     title:[self slotTitleForType:type state:[NSString stringWithFormat:@"%ld 秒后恢复", (long)remaining]]];
}

/**
 *  Ends the countdown: invalidates the timer and restores the corresponding
 *  button state per the ad reload result.
 *
 *  @param key    The (type, platform) slot key.
 *  @param loaded Ad reload result (YES success / NO failure).
 *  @return None.
 */
- (void)finishCountDownForKey:(NSNumber *)key loaded:(BOOL)loaded {
    
    [self invalidateTimerForKey:key];
    [_busyKeys removeObject:key];
    
    NSInteger keyValue = key.integerValue;
    QiAdType type = (QiAdType)(keyValue / 10);
    QiAdPlatform platform = (QiAdPlatform)(keyValue % 10);
    [self updateButtonForType:type platform:platform loaded:loaded];
}

/**
 *  Invalidates the countdown timer for the given ad slot.
 *
 *  @param key The (type, platform) slot key.
 *  @return None.
 */
- (void)invalidateTimerForKey:(NSNumber *)key {
    
    [_countDownTimers[key] invalidate];
    [_countDownTimers removeObjectForKey:key];
}

/**
 *  Invalidates all countdown timers and resets the busy set.
 *
 *  @return None.
 */
- (void)invalidateAllTimers {
    
    for (NSTimer *timer in _countDownTimers.allValues) {
        [timer invalidate];
    }
    [_countDownTimers removeAllObjects];
    [_remainingSeconds removeAllObjects];
    [_busyKeys removeAllObjects];
}

#pragma mark - Key window

/**
 *  Returns the current key window (supports iOS 13+ multi-scene and
 *  non-scene modes).
 *
 *  @return The current key window (nil if not found).
 */
+ (UIWindow *)keyWindow {
    
    UIWindow *window = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (window) { break; }
            }
        }
    }
    
    if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    
    if (!window) {
        window = [UIApplication sharedApplication].delegate.window;
    }
    
    return window;
}

@end

#endif // HIDDEN_AD_PANEL_ENABLED
