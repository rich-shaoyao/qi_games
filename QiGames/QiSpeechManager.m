//
//  QiSpeechManager.m
//  QiGames
//

#import "QiSpeechManager.h"

@interface QiSpeechManager ()

@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) AVAudioSession *audioSession;
@property (nonatomic, strong) AVAudioEngine *audioEngine;

@property (nonatomic, copy) void(^response)(NSString *);

@end

@implementation QiSpeechManager

/**
 *  Returns the shared speech recognition manager singleton.
 *
 *  @return The QiSpeechManager singleton instance.
 */
+ (instancetype)shareManager {
    
    static QiSpeechManager *manager;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[QiSpeechManager alloc] init];
    });
    
    return manager;
}

/**
 *  Initializer: configures the English (en-US) speech recognizer, the audio
 *  recording engine and permission state.
 *
 *  @return An initialized QiSpeechManager instance.
 */
- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
            NSLog(@"status is %li", (long)status);
            
            if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
                self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
                
                self.audioEngine = [[AVAudioEngine alloc] init];
                
                self.audioSession = [AVAudioSession sharedInstance];
                [self.audioSession setCategory:AVAudioSessionCategoryRecord mode:AVAudioSessionModeMeasurement options:AVAudioSessionCategoryOptionDuckOthers error:nil];
                [self.audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
            }
        }];
    }
    
    return self;
}


#pragma mark - Public functions

/**
 *  Starts recording and real-time recognition: installs the audio input tap,
 *  starts the recording engine and submits the recognition request.
 *
 *  @param response Callback that returns the recognized text.
 *  @return None.
 */
- (void)startRecordingWithResponse:(void (^)(NSString * _Nonnull))response {
    
    [self stopRecording];
    
    _response = response;
    
    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    self.recognitionRequest.shouldReportPartialResults = YES;
    
    AVAudioInputNode *audioInputNode = _audioEngine.inputNode;
    AVAudioFormat *audioFormat = [audioInputNode outputFormatForBus:0];
    [audioInputNode removeTapOnBus:0];
    [audioInputNode installTapOnBus:0 bufferSize:1024 format:audioFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [self.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    [_audioEngine prepare];
    [_audioEngine startAndReturnError:nil];
    
    _recognitionTask = [_speechRecognizer recognitionTaskWithRequest:_recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        NSLog(@"is final: %d  result: %@", result.isFinal, result.bestTranscription.formattedString);
        if (result && self.response) {
            self.response(result.bestTranscription.formattedString);
        }
    }];
}

/**
 *  Stops recording and cancels the current recognition task: stops the engine,
 *  removes the audio tap and ends the recognition request.
 *
 *  @return None.
 */
- (void)stopRecording {
    
    [_audioEngine stop];
    [_audioEngine.inputNode removeTapOnBus:0];
    [_recognitionRequest endAudio];
    [_recognitionTask cancel];
}

@end
