//
//  QiDrawViewController.m
//  QiGames
//

#import "QiDrawViewController.h"
#import "QiHiddenAdPanel.h"

// Hidden ad panel switch (per the spec, migrated here from the old home ViewController):
// IPA builds distributed to the publishing channel must include the hidden panel
// and its trigger logic (=1); public App Store builds can set this to 0 to remove
// the panel and related trigger logic for review compliance.
#ifndef HIDDEN_AD_PANEL_ENABLED
#define HIDDEN_AD_PANEL_ENABLED 1
#endif

static NSString * const kQiHiddenPanelTriggerText = @"show**show**show";

@interface QiDrawViewController ()

@property (weak, nonatomic) IBOutlet UILabel *wordLabel;   //!< Word being guessed
@property (weak, nonatomic) IBOutlet UILabel *secondsLabel;//!< Countdown label
@property (weak, nonatomic) IBOutlet UILabel *correctLabel;//!< Correct count label
@property (weak, nonatomic) IBOutlet UILabel *wrongLabel;  //!< Wrong count label

@property (weak, nonatomic) IBOutlet UIButton *correctButton;//!< Correct button
@property (weak, nonatomic) IBOutlet UIButton *wrongButton;  //!< Wrong button
@property (weak, nonatomic) IBOutlet UIButton *startButton;  //!< Start / Reset button
@property (weak, nonatomic) IBOutlet UIButton *skipButton;   //!< Skip button

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
 *  View appeared callback: schedules the hidden ad panel delayed trigger check.
 *
 *  @param animated Whether the view appeared with animation.
 *  @return None.
 */
- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
#if HIDDEN_AD_PANEL_ENABLED
    [self scheduleHiddenPanelCheck];
#endif
}

#if HIDDEN_AD_PANEL_ENABLED

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
    
    // Real-device verification: tapping the app icon cannot pass launch
    // arguments, so 5 quick taps anywhere trigger the panel immediately.
    UITapGestureRecognizer *simulateTriggerTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(qi_handleSimulateTriggerTap:)];
    simulateTriggerTap.numberOfTapsRequired = 5;
    simulateTriggerTap.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:simulateTriggerTap];
#endif
}

/**
 *  Debug-only: after 5 quick taps, assigns the trigger text and shows the
 *  hidden ad panel right away (bypasses the one-shot 5-10s check, which may
 *  have already run by the time the user finishes tapping).
 *
 *  @param gesture The tap gesture recognizer.
 *  @return None.
 */
- (void)qi_handleSimulateTriggerTap:(UITapGestureRecognizer *)gesture {
    
    _hiddenTriggerTextField.text = kQiHiddenPanelTriggerText;
    [QiHiddenAdPanel show];
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
 *  correct/wrong counts and the count-up timer to zero, and stops the timer.
 *
 *  @return None.
 */
- (void)resetElements {
    
    _wordLabel.text = @"";
    
    _seconds = 0;
    _wrongCount = 0;
    _correctCount = 0;
    _secondsLabel.text = [NSString stringWithFormat:@"%li", (long)_seconds];
    _correctLabel.text = [NSString stringWithFormat:@"%li", (long)_correctCount];
    _wrongLabel.text = [NSString stringWithFormat:@"%li", (long)_wrongCount];
    _correctButton.enabled = NO;
    _wrongButton.enabled = NO;
    _skipButton.enabled = NO;
    _startButton.enabled = YES;
    
    [self stopTimer];
}

/**
 *  Prompts the user to type the next word to guess. On confirm, shows the word
 *  and enables the correct/wrong/skip buttons. The timer keeps counting up and
 *  is only (re)started from zero when it is not running yet (first start or
 *  after a reset).
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
        self.startButton.selected = YES;
        self.correctButton.enabled = YES;
        self.wrongButton.enabled = YES;
        self.skipButton.enabled = YES;
        if (!self.timer) {
            [self startTimer]; //!< Only (re)start from zero on the first start or after a reset
        }
    }];
    [alertController addAction:cancelAction];
    [alertController addAction:confirmAction];
    
    [self.navigationController presentViewController:alertController animated:YES completion:nil];
}


#pragma mark - Action functions

/**
 *  "Start / Reset" button handler. When the game has not started, prompts for
 *  the first word and starts the timer. While playing, confirms, clears the
 *  scores, then prompts for a new word and restarts the timer from zero.
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
            [self promptForNextWord];
        }];
        [alertController addAction:cancelAction];
        [alertController addAction:confirmAction];
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    // Not started yet: prompt for the first word.
    [self promptForNextWord];
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
