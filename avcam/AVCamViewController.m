/*
 File: AVCamViewController.m
 Abstract: View controller for camera interface.
 Version: 3.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import "AVCamViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "AVCamPreviewView.h"

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]


static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * RecordingContext = &RecordingContext;
static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;
static void * const AdjustingExposureObservationContext = (void*)&AdjustingExposureObservationContext;


@interface AVCamViewController () <AVCaptureFileOutputRecordingDelegate>

// For use in the storyboards.
@property (nonatomic, retain) IBOutlet AVCamPreviewView *previewView;
@property (nonatomic, retain) IBOutlet UIButton *recordButton;
@property (nonatomic, retain) IBOutlet UIButton *cameraButton;
@property (nonatomic, retain) IBOutlet UIButton *libButton;
@property (nonatomic, retain) IBOutlet UIImageView *overlayImageView;
@property (retain, nonatomic) IBOutlet UILabel *recordTimerLabel;
@property (retain, nonatomic) IBOutlet UIView *buttonView;

@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSTimer *recordTimer;
@property (nonatomic, strong) NSTimer *storytipTimer;

// Shadow imageviews
@property (retain, nonatomic) IBOutlet UIImageView *shadowFlipImageView;
@property (retain, nonatomic) IBOutlet UIImageView *shadowRecImageView;
@property (retain, nonatomic) IBOutlet UIImageView *shadowLibImageView;

@property (retain, nonatomic) IBOutlet UIImageView *storytipImageView;

- (IBAction)toggleMovieRecording:(id)sender;
- (IBAction)changeCamera:(id)sender;
- (IBAction)snapStillImage:(id)sender;
- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;


@end

@implementation AVCamViewController


- (BOOL)isSessionRunningAndDeviceAuthorized
{
	return [[self session] isRunning] && [self isDeviceAuthorized];
    
}

+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized
{
	return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}

- (void)viewDidLoad
{
    
    done = false;
	[super viewDidLoad];
	
	// Create the AVCaptureSession
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	[self setSession:session];
	
	// Setup the preview view
	[[self previewView] setSession:session];
    
    // add tap recognizer to previewView
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(exposureAtPoint:)];
    [self.previewView addGestureRecognizer:tapRecognizer];
    [tapRecognizer release];
	
	// Check for device authorization
	[self checkDeviceAuthorizationStatus];
	
	// Dispatch the rest of session setup to the sessionQueue so that the main queue isn't blocked.
	dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	[self setSessionQueue:sessionQueue];
	
	dispatch_async(sessionQueue, ^{
		[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
		
		NSError *error = nil;
		
		AVCaptureDevice *videoDevice = [AVCamViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionFront];
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        cameraPosition = AVCaptureDevicePositionFront;
		
		if (error)
		{
			NSLog(@"%@", error);
		}
        [videoDevice lockForConfiguration:Nil];
        videoDevice.activeVideoMinFrameDuration = CMTimeMake(1,15);
        
        videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1,15);
		[videoDevice unlockForConfiguration];
        
		if ([session canAddInput:videoDeviceInput])
		{
			[session addInput:videoDeviceInput];
			[self setVideoDeviceInput:videoDeviceInput];
		}
		
		AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
		AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
		
		if (error)
		{
			NSLog(@"%@", error);
		}
		
		if ([session canAddInput:audioDeviceInput])
		{
			[session addInput:audioDeviceInput];
		}
        
        NSString * preset = AVCaptureSessionPreset640x480;
        
        [session setSessionPreset:preset];
        
        
        //		[session set]
		
		AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
		if ([session canAddOutput:movieFileOutput])
		{
			[session addOutput:movieFileOutput];
			AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
			if ([connection isVideoStabilizationSupported])
				[connection setEnablesVideoStabilizationWhenAvailable:YES];
            
            //  [connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
            
			[self setMovieFileOutput:movieFileOutput];
            //    [connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
            
		}
		
		AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
		if ([session canAddOutput:stillImageOutput])
		{
			[stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
			[session addOutput:stillImageOutput];
			[self setStillImageOutput:stillImageOutput];
		}
	});
    
    [[self libButton] setEnabled:YES];
    
    // rotate images and buttons
    self.cameraButton.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    self.libButton.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    self.recordButton.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    
    self.shadowFlipImageView.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    self.shadowLibImageView.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    self.shadowRecImageView.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    
    self.overlayImageView.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    self.recordTimerLabel.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    self.recordTimerLabel.hidden = YES;
    
    self.storytipImageView.transform = CGAffineTransformMakeRotation(M_PI/ 2);
    
    // set first storytip
    [self updateStorytip];
    self.storytipTimer = [NSTimer scheduledTimerWithTimeInterval:6.0f target:self selector:@selector(updateStorytip) userInfo:nil repeats:YES];
    
}

- (void)viewWillAppear:(BOOL)animated
{
	dispatch_async([self sessionQueue], ^{
		[self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
		[self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
		[self addObserver:self forKeyPath:@"movieFileOutput.recording" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:RecordingContext];
        
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		
		__weak AVCamViewController *weakSelf = self;
		[self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:[self session] queue:nil usingBlock:^(NSNotification *note) {
			AVCamViewController *strongSelf = weakSelf;
			dispatch_async([strongSelf sessionQueue], ^{
				// Manually restarting the session since it must have been stopped due to an error.
				[[strongSelf session] startRunning];
				[[strongSelf recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
			});
		}]];
		[[self session] startRunning];
	});
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    
	dispatch_async([self sessionQueue], ^{
		[[self session] stopRunning];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		[[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
		
		[self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
		[self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
        
	});
    
}

- (void)viewDidAppear:(BOOL)animated {
    
    //    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
}

//- (BOOL)prefersStatusBarHidden
//{
//	return YES;
//}

- (BOOL)shouldAutorotate
{
	// Disable autorotation of the interface when recording is in progress.
	return ![self lockInterfaceRotation];
}

- (NSUInteger)supportedInterfaceOrientations
{
    //	return UIInterfaceOrientationMaskLandscapeRight;
    return UIInterfaceOrientationMaskPortrait;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	//[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)toInterfaceOrientation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    
    if (context == AdjustingExposureObservationContext) {

        // set to main queue, to prevent infinite loop
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(![object isAdjustingExposure]){
                
                AVCaptureDevice *device = [[self videoDeviceInput] device];
                NSError *error;
                
                if([device isExposureModeSupported:AVCaptureExposureModeLocked]) {
                    
                    // cleanup observer
                    @try{
                        [device removeObserver:self forKeyPath:@"adjustingExposure" context:AdjustingExposureObservationContext];
                    }@catch (id anException) {
                        //do nothing, obviously it wasn't attached because an exception was thrown
                    }
                                        
                    [device lockForConfiguration:&error];
                    [device setExposureMode:AVCaptureExposureModeLocked];
                    [device unlockForConfiguration];
                    
                }
                
            }
        });
        
    }
	else if (context == CapturingStillImageContext)
	{
		BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
		
		if (isCapturingStillImage)
		{
			[self runStillImageCaptureAnimation];
		}
	}
	else if (context == RecordingContext)
	{
		BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRecording)
			{
				[[self cameraButton] setEnabled:NO];
				[[self recordButton] setEnabled:YES];
				[[self libButton] setEnabled:NO];
                
                [UIView animateWithDuration:0.3f
                                 animations:^{
                                     [[self cameraButton] setAlpha:0.3f];
                                     [[self recordButton] setAlpha:1.0f];
                                     [[self libButton] setAlpha:0.3f];
                                     
                                     [[self overlayImageView] setAlpha:0.3f];
                                     
                                 }];
                
                // change recordButton image
                [self.recordButton setImage:[UIImage imageNamed:@"Record-Button-Stop.png"] forState:UIControlStateNormal];
                [self.recordButton setImage:[UIImage imageNamed:@"Record-Button-Stop.png"] forState:UIControlStateHighlighted];
                [self.recordButton setImage:[UIImage imageNamed:@"Record-Button-Stop.png"] forState:UIControlStateDisabled];
                
                // record timer
                self.startDate = [NSDate date];
                self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:1/10 target:self selector:@selector(updateTimerLabel) userInfo:nil repeats:YES];
                self.recordTimerLabel.hidden = NO;
                
                // invalidate story tip timers
                [self.storytipTimer invalidate];
                self.storytipTimer = nil;

                // animate story tips out in case they're still visible
                [UIView animateWithDuration:0.35f
                                      delay:0.0f
                                    options:nil
                                 animations:^{
                                     self.storytipImageView.alpha = 0.0f;
                                 }
                                 completion:^(BOOL finished) {
                                     self.storytipImageView.image = nil;
                                 }];
                
                
			}
			else
			{
				[[self cameraButton] setEnabled:YES];
				[[self recordButton] setEnabled:YES];
				[[self libButton] setEnabled:YES];
                
                
                [UIView animateWithDuration:0.3f
                                 animations:^{
                                     [[self cameraButton] setAlpha:1.0f];
                                     [[self recordButton] setAlpha:1.0f];
                                     [[self libButton] setAlpha:1.0f];
                                     
                                     [[self overlayImageView] setAlpha:1.0f];
                                     
                                 }];
                
                // change recordButton image
                [self.recordButton setImage:[UIImage imageNamed:@"Record-Button.png"] forState:UIControlStateNormal];
                [self.recordButton setImage:[UIImage imageNamed:@"Record-Button.png"] forState:UIControlStateHighlighted];
                [self.recordButton setImage:[UIImage imageNamed:@"Record-Button.png"] forState:UIControlStateDisabled];
                
                self.recordTimerLabel.hidden = YES;
                self.recordTimerLabel.text = @"";
                
                [self.recordTimer invalidate];
                self.recordTimer = nil;
                
                // storytip timer
                self.storytipTimer = [NSTimer scheduledTimerWithTimeInterval:6.0f target:self selector:@selector(updateStorytip) userInfo:nil repeats:YES];
                
			}
		});
	}
	else if (context == SessionRunningAndDeviceAuthorizedContext)
	{
		BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRunning)
			{
				[[self cameraButton] setEnabled:YES];
				[[self recordButton] setEnabled:YES];
				[[self libButton] setEnabled:YES];
                
                [UIView animateWithDuration:0.3f
                                 animations:^{
                                     [[self cameraButton] setAlpha:1.0f];
                                     [[self recordButton] setAlpha:1.0f];
                                     [[self libButton] setAlpha:1.0f];
                                 }];
                
			}
			else
			{
				[[self cameraButton] setEnabled:NO];
				[[self recordButton] setEnabled:NO];
				[[self libButton] setEnabled:NO];
                
                [UIView animateWithDuration:0.3f
                                 animations:^{
                                     [[self cameraButton] setAlpha:0.3f];
                                     [[self recordButton] setAlpha:0.3f];
                                     [[self libButton] setAlpha:0.3f];
                                 }];
                
			}
		});
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark Actions

- (IBAction)showLib:(id)sender
{
    lib = true;
}


- (IBAction)toggleMovieRecording:(id)sender
{
	[[self recordButton] setEnabled:NO];
	[[self libButton] setEnabled:NO];
	
	dispatch_async([self sessionQueue], ^{
		if (![[self movieFileOutput] isRecording])
		{
            
            AVCaptureDevice *captureDevice = [[self videoDeviceInput] device];
            
			[self setLockInterfaceRotation:YES];
			
			if ([[UIDevice currentDevice] isMultitaskingSupported])
			{
				// Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
				[self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil]];
			}
            //			videoOrientation = AVCaptureVideoOrientationLandscapeRight;
			// Update the orientation on the movie file output video connection before starting recording.
            [[[self movieFileOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
            
			// Turning OFF flash for video recording
			[AVCamViewController setFlashMode:AVCaptureFlashModeOff forDevice:captureDevice];
            
			// Start recording to a temporary file.
            
            NSString * documentsDirectory = [NSHomeDirectory()
                                             stringByAppendingPathComponent:@"Documents"];
            NSString *videoName = [NSString stringWithFormat:@"movie.mp4"];
            
			NSString *outputFilePath = [documentsDirectory stringByAppendingPathComponent:videoName];//[NSTemporaryDirectory() stringByAppendingPathComponent:[@"movie" stringByAppendingPathExtension:@"mov"]];
            
            
            [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:outputFilePath] error:nil];
            
            //            NSLog(@"%@", outputFilePath);
			[[self movieFileOutput] startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
            
		}
		else
		{
			[[self movieFileOutput] stopRecording];
		}
	});
}

- (void)updateTimerLabel {
    
    // Update the slider about the music time
    if([[self movieFileOutput] isRecording]) {
        
        NSDate *currentDate = [NSDate date];
        NSTimeInterval timeInterval = [currentDate timeIntervalSinceDate:self.startDate];
        NSDate *timerDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];
        
        // Set date formatter
        NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
        [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0.0]];
        
        // Format the elapsed time and set it to the label
        NSString *timeString = [dateFormatter stringFromDate:timerDate];
        self.recordTimerLabel.text = [NSString stringWithFormat:@" %@", timeString];
        
    }
    
}

- (void)updateStorytip {
    
    // get random number between 1 - 7
    int randomNumber = 1 + ceil(arc4random() % 7);
    
    self.storytipImageView.alpha = 0.0f;
    self.storytipImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"storytip0%i.png", randomNumber]];
    
    [UIView animateWithDuration:0.35f
                     animations:^{
                         self.storytipImageView.alpha = 1.0f;
                     }
                     completion:^(BOOL finished) {
                         
                         [UIView animateWithDuration:0.35f
                                               delay:5.0f
                                             options:nil
                                          animations:^{
                                              self.storytipImageView.alpha = 0.0f;
                                          }
                                          completion:^(BOOL finished) {
                                              self.storytipImageView.image = nil;
                                          }];
                         
                     }];
    
    
}

- (void)exposureAtPoint:(UITapGestureRecognizer *)recognizer {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[self session] beginConfiguration];
        
        AVCaptureDevice *device = [[self videoDeviceInput] device];
        CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)[[self previewView] layer] captureDevicePointOfInterestForPoint:[recognizer locationInView:[recognizer view]]];
        
        NSError *error;
        
        if ([device isAdjustingExposure]) return;
        
        if ([device lockForConfiguration:&error]) {
        
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
            {
                [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                [device setFocusPointOfInterest:devicePoint];
            }
            
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                
                    [device setExposurePointOfInterest:devicePoint];
                    [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
                
                    [device addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:AdjustingExposureObservationContext];
                
                }
                
            }
        
        [device unlockForConfiguration];
    
        [[self session] commitConfiguration];
    
    });
    
}

- (IBAction)changeCamera:(id)sender
{
	[[self cameraButton] setEnabled:NO];
	[[self recordButton] setEnabled:NO];
	[[self libButton] setEnabled:NO];
    
    [UIView animateWithDuration:0.3f
                     animations:^{
                         [[self cameraButton] setAlpha:0.3f];
                         [[self recordButton] setAlpha:0.3f];
                         [[self libButton] setAlpha:0.3f];
                     }];
    
	dispatch_async([self sessionQueue], ^{
		AVCaptureDevice *currentVideoDevice = [[self videoDeviceInput] device];
		AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
		AVCaptureDevicePosition currentPosition = [currentVideoDevice position];
		
		switch (currentPosition)
		{
			case AVCaptureDevicePositionUnspecified:
				preferredPosition = AVCaptureDevicePositionBack;
				break;
			case AVCaptureDevicePositionBack:
				preferredPosition = AVCaptureDevicePositionFront;
				break;
			case AVCaptureDevicePositionFront:
				preferredPosition = AVCaptureDevicePositionBack;
				break;
		}
		
		AVCaptureDevice *videoDevice = [AVCamViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
		
		[[self session] beginConfiguration];
		
		[[self session] removeInput:[self videoDeviceInput]];
		if ([[self session] canAddInput:videoDeviceInput])
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
			
			[AVCamViewController setFlashMode:AVCaptureFlashModeAuto forDevice:videoDevice];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];
            
            // [videoDevice setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
			[[self session] addInput:videoDeviceInput];
			[self setVideoDeviceInput:videoDeviceInput];
		}
		else
		{
			[[self session] addInput:[self videoDeviceInput]];
		}
        
		[[self session] commitConfiguration];
		
		dispatch_async(dispatch_get_main_queue(), ^{
            
            cameraPosition = preferredPosition;
            
			[[self cameraButton] setEnabled:YES];
			[[self recordButton] setEnabled:YES];
			[[self libButton] setEnabled:YES];
            
            [UIView animateWithDuration:0.3f
                             animations:^{
                                 [[self cameraButton] setAlpha:1.0f];
                                 [[self recordButton] setAlpha:1.0f];
                                 [[self libButton] setAlpha:1.0f];
                             }];
            
		});
	});
}

- (IBAction)snapStillImage:(id)sender
{
	dispatch_async([self sessionQueue], ^{
        
		// Update the orientation on the still image output video connection before capturing.
		[[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
		
		// Flash set to Auto for Still Capture
		[AVCamViewController setFlashMode:AVCaptureFlashModeAuto forDevice:[[self videoDeviceInput] device]];
		
		// Capture a still image.
		[[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
			
			if (imageDataSampleBuffer)
			{
				NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
				UIImage *image = [[UIImage alloc] initWithData:imageData];
				//[[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
			}
		}];
	});
}

#pragma mark File Output Delegate


- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
	if (error)
		NSLog(@"%@", error);
	
	[self setLockInterfaceRotation:YES];
	
	// Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
	UIBackgroundTaskIdentifier backgroundRecordingID = [self backgroundRecordingID];
	[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
	NSLog(@"Klaar met opnemen");
    done = true;
    
    /*
     [[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
     if (error)
     NSLog(@"%@", error);
     
     [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
     
     if (backgroundRecordingID != UIBackgroundTaskInvalid)
     [[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
     }];
     */
}

#pragma mark Device Configuration
+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
	if ([device hasFlash] && [device isFlashModeSupported:flashMode])
	{
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
		{
			[device setFlashMode:flashMode];
			[device unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	}
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = [devices firstObject];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == position)
		{
			captureDevice = device;
			break;
		}
	}
	
	return captureDevice;
}

#pragma mark UI

- (void)runStillImageCaptureAnimation
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[[self previewView] layer] setOpacity:0.0];
		[UIView animateWithDuration:.25 animations:^{
			[[[self previewView] layer] setOpacity:1.0];
		}];
	});
}

- (void)checkDeviceAuthorizationStatus
{
	NSString *mediaType = AVMediaTypeVideo;
	
	[AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
		if (granted)
		{
			//Granted access to mediaType
			[self setDeviceAuthorized:YES];
		}
		else
		{
			//Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"AVCam!"
											message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
										   delegate:self
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil] show];
				[self setDeviceAuthorized:NO];
			});
		}
	}];
}

- (void)dealloc {
    [_shadowFlipImageView release];
    [_shadowRecImageView release];
    [_shadowLibImageView release];
    [_recordTimerLabel release];
    [_storytipImageView release];
    [_buttonView release];
    [super dealloc];
}
@end
