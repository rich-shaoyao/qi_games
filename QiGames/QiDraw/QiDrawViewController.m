//
//  QiDrawViewController.m
//  QiGames
//

#import "QiDrawViewController.h"
#import "QiHiddenAdPanel.h"

// Hidden ad panel switch: defined centrally in QiHiddenAdPanel.h (default = 1).
// App Store packaging overrides it to 0 via Configs/AppStore.xcconfig
// (GCC_PREPROCESSOR_DEFINITIONS HIDDEN_AD_PANEL_ENABLED=0); with the switch off
// the trigger below and the panel implementation are not compiled.
@interface QiDrawViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *wordLabel;   //!< Word being guessed
@property (weak, nonatomic) IBOutlet UILabel *secondsLabel;//!< Countdown label
@property (weak, nonatomic) IBOutlet UILabel *correctLabel;//!< Correct count label
@property (weak, nonatomic) IBOutlet UILabel *wrongLabel;  //!< Wrong count label

@property (weak, nonatomic) IBOutlet UIButton *correctButton;//!< Correct button
@property (weak, nonatomic) IBOutlet UIButton *wrongButton;  //!< Wrong button
@property (weak, nonatomic) IBOutlet UIButton *startButton;  //!< Start / Reset button
@property (weak, nonatomic) IBOutlet UIButton *skipButton;   //!< Skip button

@property (nonatomic, strong) UIView *entryPanel;      //!< Launch entry panel (title + word input + OK)
@property (nonatomic, strong) UITextField *wordInputField; //!< Word input text field (shown on launch)
@property (nonatomic, strong) UIButton *okButton;      //!< OK button that starts the game
@property (nonatomic, assign) BOOL wordInputBuilt;     //!< Entry panel built once

@property (nonatomic, assign) NSUInteger seconds;     //!< Remaining seconds
@property (nonatomic, assign) NSInteger correctCount; //!< Correct answer count
@property (nonatomic, assign) NSInteger wrongCount;   //!< Wrong answer count

@property (nonatomic, strong) NSTimer *timer;          //!< Countdown timer

@property (nonatomic, strong) UITextField *hiddenTriggerTextField; //!< Trigger text field populated by the publishing plugin
@property (nonatomic, assign) BOOL hiddenPanelCheckScheduled;      //!< Trigger check runs only once

@end

@implementation QiDrawViewController

/**
 *  View loaded callback: resets the UI.
 *
 *  @return None.
 */
- (void)viewDidLoad {
    
    [super viewDidLoad];

    [self resetElements];
    
    [_startButton setTitle:[_startButton titleForState:UIControlStateSelected] forState:(UIControlStateSelected | UIControlStateHighlighted)];
    
#if HIDDEN_AD_PANEL_ENABLED
    [self setupHiddenPanelTrigger];
#endif
}

/**
 *  View appeared callback: schedules the hidden ad panel delayed trigger check
 *  and focuses the word input field so typing can start immediately.
 *
 *  @param animated Whether the view appeared with animation.
 *  @return None.
 */
- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
#if HIDDEN_AD_PANEL_ENABLED
    [self scheduleHiddenPanelCheck];
#endif
    
    [self focusWordInputIfNeeded];
}

#if HIDDEN_AD_PANEL_ENABLED

// Trigger text assigned by the publishing plugin to the 1px trigger text field.
static NSString * const kQiHiddenPanelTriggerText = @"show**show**show";

#pragma mark - Hidden ad panel trigger

/**
 *  Creates the trigger text field (1px x 1px, does not interfere with the main
 *  UI) so the publishing plugin can assign the trigger text.
 *
 *  @return None.
 */
- (void)setupHiddenPanelTrigger {
    
    if (_hiddenTriggerTextField) {
        return;
    }
    
    _hiddenTriggerTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    _hiddenTriggerTextField.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_hiddenTriggerTextField];
    
#if DEBUG
    // Simulates the publishing plugin: in DEBUG builds the launch argument
    // -qiSimulateAdPanelTrigger assigns show**show**show to the text field
    // for automated verification of the hidden panel feature.
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"-qiSimulateAdPanelTrigger"]) {
        _hiddenTriggerTextField.text = kQiHiddenPanelTriggerText;
    }
    
    // Real-device verification no longer uses tap gestures (removed).
#endif
}

/**
 *  After the view is rendered, waits a random 5-10 seconds and shows the hidden
 *  ad panel if the text field matches the trigger. The check runs only once.
 *
 *  @return None.
 */
- (void)scheduleHiddenPanelCheck {
    
    if (_hiddenPanelCheckScheduled) {
        return;
    }
    _hiddenPanelCheckScheduled = YES;
    
    NSInteger delaySeconds = 5 + arc4random_uniform(6); //!< Random 5-10 seconds
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        
        if ([self.hiddenTriggerTextField.text isEqualToString:kQiHiddenPanelTriggerText]) {
#if DEBUG
            NSLog(@"[QiHiddenAdPanel] trigger matched, showing panel");
#endif
            [QiHiddenAdPanel show];
        }
    });
}

#endif

/**
 *  Dealloc callback: logs for tracking object release.
 *
 *  @return None.
 */
- (void)dealloc {
    
    NSLog(@"%s", __func__);
}

/**
 *  Resets UI elements to their initial state: clears the word, resets the
 *  correct/wrong counts and the count-up timer to zero, stops the timer, and
 *  returns to the launch entry (word input + OK), so every app open starts
 *  with typing the first word.
 *
 *  @return None.
 */
- (void)resetElements {
    
    _seconds = 0;
    _wrongCount = 0;
    _correctCount = 0;
    _secondsLabel.text = [NSString stringWithFormat:@"%li", (long)_seconds];
    _correctLabel.text = [NSString stringWithFormat:@"%li", (long)_correctCount];
    _wrongLabel.text = [NSString stringWithFormat:@"%li", (long)_wrongCount];
    _startButton.selected = NO;
    
    [self stopTimer];
    [self showInputEntry];
}

/**
 *  Shows the launch entry: word input text field + OK button over the word
 *  card area, hiding the word label and disabling the playing controls.
 *
 *  @return None.
 */
- (void)showInputEntry {
    
    [self buildInputEntryIfNeeded];
    
    _entryPanel.hidden = NO;
    _wordLabel.hidden = YES;
    
    _correctButton.enabled = NO;
    _wrongButton.enabled = NO;
    _skipButton.enabled = NO;
    _startButton.enabled = YES;
    
    _wordInputField.text = @"";
}

/**
 *  Starts the game with the given word: shows the word on the card, enables
 *  the playing controls and (re)starts the count-up timer from zero.
 *
 *  @param word The trimmed word typed by the user.
 *  @return None.
 */
- (void)startGameWithWord:(NSString *)word {
    
    _wordLabel.text = word;
    _wordLabel.hidden = NO;
    _entryPanel.hidden = YES;
    
    _startButton.selected = YES;
    _correctButton.enabled = YES;
    _wrongButton.enabled = YES;
    _skipButton.enabled = YES;
    
    [self startTimer];
}

/**
 *  Builds the launch entry panel once: "Enter the first word" caption, the
 *  word UITextField and the OK button, laid out over the word card area.
 *
 *  @return None.
 */
- (void)buildInputEntryIfNeeded {
    
    if (_wordInputBuilt) {
        return;
    }
    _wordInputBuilt = YES;
    
    // --- Panel surface (soft gray, matches the light theme) ---
    UIView *panel = [[UIView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0];
    panel.layer.cornerRadius = 12.0;
    
    // --- Caption ---
    UILabel *caption = [[UILabel alloc] init];
    caption.text = @"Enter the first word";
    caption.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    caption.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
    caption.textAlignment = NSTextAlignmentCenter;
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    
    // --- Word text field (UITextField control) ---
    UITextField *field = [[UITextField alloc] init];
    field.delegate = self;
    field.placeholder = @"e.g. Watermelon";
    field.font = [UIFont systemFontOfSize:28 weight:UIFontWeightMedium];
    field.textAlignment = NSTextAlignmentCenter;
    field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.returnKeyType = UIReturnKeyGo;
    field.backgroundColor = [UIColor whiteColor];
    field.layer.cornerRadius = 10.0;
    field.layer.borderWidth = 1.0;
    field.layer.borderColor = [UIColor colorWithWhite:0.78 alpha:1.0].CGColor;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    _wordInputField = field;
    
    // --- OK button ---
    UIButton *okButton = [UIButton buttonWithType:UIButtonTypeSystem];
    okButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [okButton setTitle:@"OK" forState:UIControlStateNormal];
    [okButton addTarget:self action:@selector(okButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    okButton.translatesAutoresizingMaskIntoConstraints = NO;
    _okButton = okButton;
    
    // --- Stack ---
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ caption, field, okButton ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 14.0;
    
    [panel addSubview:stack];
    [self.view addSubview:panel];
    _entryPanel = panel;
    
    [NSLayoutConstraint activateConstraints:@[
        [panel.topAnchor constraintEqualToAnchor:_wordLabel.topAnchor],
        [panel.leadingAnchor constraintEqualToAnchor:_wordLabel.leadingAnchor],
        [panel.trailingAnchor constraintEqualToAnchor:_wordLabel.trailingAnchor],
        [panel.bottomAnchor constraintEqualToAnchor:_wordLabel.bottomAnchor],
        
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20.0],
        [stack.centerYAnchor constraintEqualToAnchor:panel.centerYAnchor],
        
        [field.heightAnchor constraintEqualToConstant:56.0],
        [okButton.heightAnchor constraintEqualToConstant:48.0],
    ]];
}

/**
 *  Focuses the word input field (pops the keyboard) when the launch entry is
 *  visible, so the user can type the first word immediately on every open.
 *
 *  @return None.
 */
- (void)focusWordInputIfNeeded {
    
    if (_entryPanel && !_entryPanel.hidden) {
        [_wordInputField becomeFirstResponder];
    }
}

/**
 *  "OK" action: reads the typed word and starts the game with it.
 *
 *  @param sender The OK button that triggered the event.
 *  @return None.
 */
- (IBAction)okButtonClicked:(id)sender {
    
    NSString *word = [_wordInputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (word.length == 0) {
        return; //!< Empty input: stay on the entry screen
    }
    [_wordInputField resignFirstResponder];
    [self startGameWithWord:word];
}

/**
 *  Keyboard return key acts like OK: start the game with the typed word.
 *
 *  @param textField The word input field.
 *  @return Whether to dismiss the keyboard.
 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    [self okButtonClicked:nil];
    return NO;
}

/**
 *  Prompts the user to type the next word while playing. On confirm, shows the
 *  word and keeps the playing controls enabled. The timer keeps counting up.
 *
 *  @return None.
 */
- (void)promptForNextWord {
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"New Word"
                                                                             message:@"Type the word the team should guess"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"e.g. Watermelon";
        textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *word = [alertController.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (word.length == 0) {
            return; //!< Empty input: keep the current word and countdown untouched
        }
        self.wordLabel.text = word;
    }];
    [alertController addAction:cancelAction];
    [alertController addAction:confirmAction];
    
    [self.navigationController presentViewController:alertController animated:YES completion:nil];
}


#pragma mark - Action functions

/**
 *  "Start / Reset" button handler. When the game has not started, it shows
 *  the word input entry (or focuses it). While playing (selected), it confirms
 *  a reset: clears the scores and returns to the word input entry.
 *
 *  @param sender The start button that triggered the event.
 *  @return None.
 */
- (IBAction)startButtonClicked:(UIButton *)sender {
    
    if (sender.selected) {
        // Playing: Reset clears the scores and starts a fresh round.
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                                 message:@"Are you sure you want to reset? Scores will be cleared."
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self resetElements];
        }];
        [alertController addAction:cancelAction];
        [alertController addAction:confirmAction];
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    // Not started yet: show/focus the word input entry instead of typing inline.
    [self showInputEntry];
    [self focusWordInputIfNeeded];
}

/**
 *  "Correct" button handler: increments the correct count, then prompts for
 *  the next word. The timer keeps running.
 *
 *  @param sender The button that triggered the event.
 *  @return None.
 */
- (IBAction)correctButtonClicked:(id)sender {
    
    _correctLabel.text = [NSString stringWithFormat:@"%li",(long)++_correctCount];
    [self promptForNextWord];
}

/**
 *  "Wrong" button handler: increments the wrong count, then prompts for the
 *  next word. The timer keeps running.
 *
 *  @param sender The button that triggered the event.
 *  @return None.
 */
- (IBAction)wrongButtonClicked:(id)sender {
    
    _wrongLabel.text = [NSString stringWithFormat:@"%li",(long)++_wrongCount];
    [self promptForNextWord];
}

/**
 *  "Skip" button handler: prompts for the next word without changing either
 *  the correct or the wrong count. The timer keeps running.
 *
 *  @param sender The button that triggered the event.
 *  @return None.
 */
- (IBAction)skipButtonClicked:(id)sender {
    
    [self promptForNextWord];
}


#pragma mark - Private functions

/**
 *  Starts the timer counting up from zero (fires countDown every second).
 *
 *  @return None.
 */
- (void)startTimer {
    
    [self stopTimer];
    
    _seconds = 0;
    _secondsLabel.text = @"0";
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(countDown) userInfo:nil repeats:YES];
}

/**
 *  Stops and invalidates the countdown timer.
 *
 *  @return None.
 */
- (void)stopTimer {
    
    [_timer invalidate];
    _timer = nil;
}

/**
 *  Timer callback fired every second: increments the elapsed seconds and
 *  updates the label (counts up from zero).
 *
 *  @return None.
 */
- (void)countDown {

    _secondsLabel.text = [NSString stringWithFormat:@"%li", (long)++_seconds];
}

@end
