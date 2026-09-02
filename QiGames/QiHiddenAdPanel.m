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
//  Style: implemented per the "panel sample image" from the spec (calibrated
//  after obtaining the sample on 2026-08-26) -- two-column layout: left column
//  (blue) Rewarded Video + right column (red) Interstitial. Each column has a
//  title on top and platform row buttons inside (AdMob + Vungle + InMobi rows).
//  A ✕ close button sits at the top-right; below the bottom gray separator line
//  there is a small-text placeholder (TBD).
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

@interface QiHiddenAdPanel ()

@property (nonatomic, strong) UIView *overlayView;             //!< Full-screen overlay
@property (nonatomic, strong) UIView *containerView;           //!< Panel container
@property (nonatomic, strong) UIButton *closeButton;           //!< Close button (✕ top-right)
@property (nonatomic, strong) UILabel *rewardedTitleLabel;     //!< Left column title (Rewarded Video)
@property (nonatomic, strong) UILabel *interstitialTitleLabel; //!< Right column title (Interstitial)
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIButton *> *rewardedButtons;     //!< Left column platform row buttons, keyed by QiAdPlatform
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIButton *> *interstitialButtons; //!< Right column platform row buttons, keyed by QiAdPlatform
@property (nonatomic, strong) UIView *separatorView;           //!< Bottom gray separator line
@property (nonatomic, strong) UILabel *bottomLabel;            //!< Bottom small-text placeholder (TBD)

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
    // interstitial); placeholder platforms show as "not configured" (grayed).
    for (NSNumber *platformNumber in QiPanelPlatforms()) {
        QiAdPlatform platform = [platformNumber integerValue];
        NSString *platformName = [self platformName:platform];
        if (!QiPlatformConnected(platform)) {
            [self setButtonForType:QiAdTypeRewarded platform:platform enabled:NO title:[NSString stringWithFormat:@"%@\n未接入", platformName]];
            [self setButtonForType:QiAdTypeInterstitial platform:platform enabled:NO title:[NSString stringWithFormat:@"%@\n未接入", platformName]];
            continue;
        }
        [self setButtonForType:QiAdTypeRewarded platform:platform enabled:NO title:[NSString stringWithFormat:@"%@\nLoading...", platformName]];
        [self setButtonForType:QiAdTypeInterstitial platform:platform enabled:NO title:[NSString stringWithFormat:@"%@\nLoading...", platformName]];
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
 *  Builds the panel UI (per the sample image): two columns (left blue Rewarded
 *  Video / right red Interstitial), each with a column title on top and
 *  platform row buttons (AdMob + Vungle + InMobi) inside; ✕ close at the
 *  top-right; bottom gray separator line plus a small-text placeholder.
 *
 *  @return None.
 */
- (void)buildContainer {
    
    CGFloat panelWidth = MIN(320.0, CGRectGetWidth(_overlayView.bounds) - 32.0);
    CGFloat panelHeight = 400.0;
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelWidth, panelHeight)];
    _containerView.center = CGPointMake(CGRectGetMidX(_overlayView.bounds), CGRectGetMidY(_overlayView.bounds));
    _containerView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.98];
    _containerView.layer.cornerRadius = 12.0;
    _containerView.layer.masksToBounds = YES;
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    _rewardedButtons = [NSMutableDictionary dictionary];
    _interstitialButtons = [NSMutableDictionary dictionary];
    
    CGFloat columnGap = 12.0;
    CGFloat columnWidth = (panelWidth - 32.0 - columnGap) / 2.0; //!< Column width (including 16pt side margins)
    CGFloat columnHeight = 346.0; //!< Fits 6 platform rows (AdMob / Meta / Vungle / Chartboost / InMobi / Unity Ads)
    CGFloat columnTop = 12.0;
    
    // Close button (✕ top-right)
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.frame = CGRectMake(panelWidth - 42.0, 6.0, 32.0, 32.0);
    [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont systemFontOfSize:18.0];
    _closeButton.tintColor = [UIColor lightGrayColor];
    [_closeButton addTarget:self action:@selector(closeButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_closeButton];
    
    // Left column: Rewarded Video (blue)
    UIView *rewardedColumn = [self makeColumnWithFrame:CGRectMake(16.0, columnTop, columnWidth, columnHeight)
                                                 color:[UIColor colorWithRed:0.20 green:0.44 blue:0.85 alpha:1.0]];
    [_containerView addSubview:rewardedColumn];
    
    _rewardedTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(6.0, 8.0, columnWidth - 12.0, 20.0)];
    _rewardedTitleLabel.text = @"Rewarded Video";
    _rewardedTitleLabel.textColor = [UIColor whiteColor];
    _rewardedTitleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    _rewardedTitleLabel.textAlignment = NSTextAlignmentCenter;
    [rewardedColumn addSubview:_rewardedTitleLabel];
    
    // Right column: Interstitial (red)
    UIView *interstitialColumn = [self makeColumnWithFrame:CGRectMake(16.0 + columnWidth + columnGap, columnTop, columnWidth, columnHeight)
                                                    color:[UIColor colorWithRed:0.85 green:0.30 blue:0.28 alpha:1.0]];
    [_containerView addSubview:interstitialColumn];
    
    _interstitialTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(6.0, 8.0, columnWidth - 12.0, 20.0)];
    _interstitialTitleLabel.text = @"Interstitial";
    _interstitialTitleLabel.textColor = [UIColor whiteColor];
    _interstitialTitleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    _interstitialTitleLabel.textAlignment = NSTextAlignmentCenter;
    [interstitialColumn addSubview:_interstitialTitleLabel];
    
    // Platform row buttons inside each column (AdMob, then Vungle, then InMobi)
    CGFloat rowX = 12.0;
    CGFloat rowWidth = columnWidth - 24.0;
    CGFloat rowHeight = 44.0;
    CGFloat rowGap = 8.0;
    CGFloat rowTop = 34.0;
    NSArray<NSNumber *> *platforms = QiPanelPlatforms();
    for (NSUInteger i = 0; i < platforms.count; i++) {
        QiAdPlatform platform = [platforms[i] integerValue];
        NSInteger tag = [self keyForType:QiAdTypeRewarded platform:platform].integerValue;
        
        UIButton *rewardedButton = [self makePlatformRowButtonWithFrame:CGRectMake(rowX, rowTop + i * (rowHeight + rowGap), rowWidth, rowHeight) tag:tag];
        [rewardedColumn addSubview:rewardedButton];
        _rewardedButtons[@(platform)] = rewardedButton;
        
        UIButton *interstitialButton = [self makePlatformRowButtonWithFrame:CGRectMake(rowX, rowTop + i * (rowHeight + rowGap), rowWidth, rowHeight) tag:tag];
        [interstitialColumn addSubview:interstitialButton];
        _interstitialButtons[@(platform)] = interstitialButton;
    }
    
    // Bottom gray separator line + small-text placeholder (TBD)
    _separatorView = [[UIView alloc] initWithFrame:CGRectMake(16.0, columnTop + columnHeight + 10.0, panelWidth - 32.0, 1.0)];
    _separatorView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    [_containerView addSubview:_separatorView];
    
    _bottomLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0, columnTop + columnHeight + 16.0, panelWidth - 32.0, 20.0)];
    _bottomLabel.text = @""; //!< Placeholder: small text at the bottom, content TBD
    _bottomLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    _bottomLabel.font = [UIFont systemFontOfSize:11.0];
    _bottomLabel.textAlignment = NSTextAlignmentCenter;
    [_containerView addSubview:_bottomLabel];
}

/**
 *  Creates an ad column container (rounded color block).
 *
 *  @param frame The column frame.
 *  @param color The column background color (blue left / red right).
 *  @return The column view.
 */
- (UIView *)makeColumnWithFrame:(CGRect)frame color:(UIColor *)color {
    
    UIView *column = [[UIView alloc] initWithFrame:frame];
    column.backgroundColor = color;
    column.layer.cornerRadius = 10.0;
    column.layer.masksToBounds = YES;
    column.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    return column;
}

/**
 *  Creates a platform row button. The tag encodes the (type, platform) key so
 *  the tap handler can resolve both from the sender alone.
 *
 *  @param frame The button frame.
 *  @param tag   The (type, platform) key (see keyForType:platform:).
 *  @return The configured button.
 */
- (UIButton *)makePlatformRowButtonWithFrame:(CGRect)frame tag:(NSInteger)tag {
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    button.tag = tag;
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
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
 *  Sets the platform row button state and title: when enabled it highlights
 *  (semi-transparent white background, white text); when disabled it grays out
 *  (semi-transparent black background, gray text, not tappable).
 *
 *  @param type     Ad type (QiAdTypeRewarded / QiAdTypeInterstitial).
 *  @param platform Ad network platform.
 *  @param enabled  YES means tappable (highlighted); NO means not tappable (gray).
 *  @param title    The button title to display.
 *  @return None.
 */
- (void)setButtonForType:(QiAdType)type platform:(QiAdPlatform)platform enabled:(BOOL)enabled title:(NSString *)title {
    
    UIButton *button = [self buttonForType:type platform:platform];
    if (!button) { return; }
    button.enabled = enabled;
    [button setTitle:title forState:UIControlStateNormal];
    
    if (enabled) {
        // Highlighted: tappable
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.28];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        // Grayed out: not tappable
        button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];
        [button setTitleColor:[UIColor colorWithWhite:0.8 alpha:1.0] forState:UIControlStateNormal];
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
    
    NSString *platformName = [self platformName:platform];
    NSString *title = loaded ? [NSString stringWithFormat:@"%@\nTap to Play", platformName]
                             : [NSString stringWithFormat:@"%@\nNo Ad", platformName];
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
    NSString *platformName = [self platformName:platform];
    [self setButtonForType:type platform:platform enabled:NO title:[NSString stringWithFormat:@"%@\nPlaying...", platformName]];
    
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
    
    // During the countdown the button stays gray (not tappable); only the
    // remaining-seconds hint is updated. Note: no toast / alert is shown once
    // the panel is up; all countdown feedback is contained in the button title.
    NSInteger keyValue = key.integerValue;
    QiAdType type = (QiAdType)(keyValue / 10);
    QiAdPlatform platform = (QiAdPlatform)(keyValue % 10);
    NSString *platformName = [self platformName:platform];
    NSInteger remaining = [_remainingSeconds[key] integerValue];
    [self setButtonForType:type platform:platform enabled:NO
                     title:[NSString stringWithFormat:@"%@\nRefreshing %lds", platformName, (long)remaining]];
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
