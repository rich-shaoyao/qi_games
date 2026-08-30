//
//  QiSpeechManager.h
//  QiGames
//

#import <Foundation/Foundation.h>
#import <Speech/Speech.h>

/**
 *  Speech recognition manager: wraps SFSpeechRecognizer and AVAudioEngine
 *  to provide real-time voice recognition with an English (en-US) locale.
 */
@interface QiSpeechManager : NSObject

/**
 *  Returns the shared singleton instance.
 *
 *  @return The QiSpeechManager singleton instance.
 */
+ (instancetype)shareManager;

/**
 *  Starts recording and real-time recognition.
 *
 *  @param response Callback that returns the recognized text.
 */
- (void)startRecordingWithResponse:(void (^)(NSString * _Nonnull))response;

/**
 *  Stops recording and cancels the current recognition task.
 */
- (void)stopRecording;

@end
