/*
 *  AVFoundationVideoGrabber.mm
 */

#include "ofxiOSVideoWriter.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include "ofxiOSExtras.h"

//#if __IPHONE_OS_VERSION_MIN_REQUIRED > __IPHONE_3_2

#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#define ARC4RANDOM_MAX      0x100000000

@implementation ofxiOSNativeVideoWriter {
    AVAssetWriterInputGroup *group;
}

- (void)createVideo {
    
 //   session = [[AVCaptureSession alloc] init];
    imageSize = CGSizeMake(640, 480);
    
    NSError *error = nil;
    
    documentsDirectory = [NSHomeDirectory()
                          stringByAppendingPathComponent:@"Documents"];
    
    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"vidcount"])
        vidCount = [[[NSUserDefaults standardUserDefaults] valueForKey:@"vidcount"] intValue];
    else
        vidCount = 1;
    
    NSString *videoName = [NSString stringWithFormat:@"movie_edit_new_%i.mp4", (vidCount + 1)];
    
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:videoName];
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:videoOutputPath] error:nil];
    
    ///////////////////     end setup    ///////////////////////////////////

    NSLog(@"Start building video from defined frames.");

    videoWriter = [[AVAssetWriter alloc] initWithURL:
                   [NSURL fileURLWithPath:videoOutputPath] fileType:AVFileTypeQuickTimeMovie
                                               error:&error];
    
    
    // ----------- video
    NSParameterAssert(videoWriter);
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:imageSize.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:imageSize.height], AVVideoHeightKey,
                                   nil];
    
    videoWriterInput = [AVAssetWriterInput
                        assetWriterInputWithMediaType:AVMediaTypeVideo
                        outputSettings:videoSettings];
    
    dispatch_queue_t processingQueue = dispatch_queue_create("com.video.processingQueue", NULL);

    dispatch_set_context(processingQueue, self);
    
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                                           [NSNumber numberWithInt:imageSize.width], kCVPixelBufferWidthKey,
                                                           [NSNumber numberWithInt:imageSize.height], kCVPixelBufferHeightKey,
                                                           nil];
    
    adaptor = [AVAssetWriterInputPixelBufferAdaptor
               assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
               sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    NSParameterAssert(videoWriterInput);
    NSParameterAssert([videoWriter canAddInput:videoWriterInput]);
    NSParameterAssert(adaptor);
    
    videoWriterInput.expectsMediaDataInRealTime = YES;
    
    [videoWriter addInput:videoWriterInput];
    
    dispatch_release(processingQueue);
    
}

- (void)startVideo {
    
    NSError *error = nil;
    
    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"vidcount"])
        vidCount = [[[NSUserDefaults standardUserDefaults] valueForKey:@"vidcount"] intValue];
    else
        vidCount = 1;
    
    NSString *videoName = [NSString stringWithFormat:@"movie_edit_new_%i.mp4", (vidCount + 1)];
    NSLog(@"%@", videoName);
    
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:videoName];
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:videoOutputPath] error:nil];
    
    if (videoWriter)
        [videoWriter release];
    
    videoWriter = [[AVAssetWriter alloc] initWithURL:
                   [NSURL fileURLWithPath:videoOutputPath] fileType:AVFileTypeQuickTimeMovie
                                               error:&error];

    [videoWriter addInput:videoWriterInput];
    
}

- (void)composeTracks
{
    
    NSString *originalVideoPath = [documentsDirectory stringByAppendingPathComponent:@"movie.mp4"];
    NSURL *originalVideoURL = [NSURL fileURLWithPath:originalVideoPath];
    
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:originalVideoURL options:nil];
    AVAssetTrack *audioTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    // get current video name
    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"vidcount"])
        vidCount = [[[NSUserDefaults standardUserDefaults] valueForKey:@"vidcount"] intValue];
    else
        vidCount = 1;
    
    NSString *videoName = [NSString stringWithFormat:@"movie_edit_new_%i.mp4", (vidCount + 1)];
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:videoName];
    
    NSURL *videoURL = [NSURL fileURLWithPath:videoOutputPath];
    
    AVAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    
    // add / change metadata
    NSMutableArray *metadata = [NSMutableArray array];
    
    AVMutableMetadataItem *creationDateMeta = [AVMutableMetadataItem metadataItem];
    creationDateMeta.key = AVMetadataCommonKeyCreationDate;
    creationDateMeta.keySpace = AVMetadataKeySpaceCommon;
    
    // create random Date
    NSDate *startDate = [[NSDate new] autorelease];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:0];
    NSTimeInterval timeBetweenDates = [endDate timeIntervalSinceDate:startDate];
    NSTimeInterval randomInterval = ((NSTimeInterval)arc4random() / ARC4RANDOM_MAX) * timeBetweenDates;
    NSDate *randomDate = [startDate dateByAddingTimeInterval:randomInterval];
    
    // set random date as creation date
    creationDateMeta.value = randomDate;
    [metadata addObject:creationDateMeta];
    
    AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableCompositionTrack *mutableCompositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    [mutableCompositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,videoTrack.timeRange.duration) ofTrack:videoTrack atTime:kCMTimeZero error:nil];
    [mutableCompositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,audioTrack.timeRange.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    
    NSString *outputName = [NSString stringWithFormat:@"movie_with_audio %i.mp4", (vidCount + 1)];
    
    AVAssetExportSession *assetExportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    
    assetExportSession.outputFileType = AVFileTypeQuickTimeMovie;
    assetExportSession.outputURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:outputName]];
    assetExportSession.metadata = metadata;
    assetExportSession.shouldOptimizeForNetworkUse = YES;
    assetExportSession.timeRange = CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration);
    
    NSLog(@"composition bijna klaar: %@", outputName);
    NSLog(@"date: %@", randomDate);
    
    [assetExportSession exportAsynchronouslyWithCompletionHandler:^{
        
        [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:(vidCount + 1)] forKey:@"vidcount"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // remove the orignal movie, and editted movie
        [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:originalVideoPath] error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:videoOutputPath] error:nil];
        
        NSLog(@"composition IS klaar");
        
        delegate->done = true;
        
    }];
    
}



-(void)genTexture {
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                NULL,
                                                ofxiPhoneGetGLView().context,
                                                NULL,
                                                &coreVideoTextureCache);

    if(err) NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);

    CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                                               NULL,
                                               NULL,
                                               0,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                             1,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(attrs,
                         kCVPixelBufferIOSurfacePropertiesKey,
                         empty);
    
    
    // create pixelbuffer
    CVPixelBufferCreate(kCFAllocatorDefault, (int)imageSize.width, (int)imageSize.height,
                        kCVPixelFormatType_32BGRA,
                        attrs,
                        &renderTarget);
    
    CVReturn result = CVPixelBufferPoolCreatePixelBuffer (NULL, [adaptor pixelBufferPool], &renderTarget);
    if(result != kCVReturnSuccess) cout << "CVPixelBufferPoolCreatePixelBuffer failed";

    err = CVOpenGLESTextureCacheCreateTextureFromImage (
                                                  kCFAllocatorDefault, coreVideoTextureCache, renderTarget,
                                                  NULL, // texture attributes
                                                  GL_TEXTURE_2D,
                                                  GL_RGBA, // opengl format
                                                  (int)imageSize.width,
                                                  (int)imageSize.height,
                                                  GL_BGRA, // native iOS format
                                                  GL_UNSIGNED_BYTE,
                                                  0,
                                                  &renderTexture);


    if(err != kCVReturnSuccess) cout << "CVOpenGLESTextureCacheCreateTextureFromImage failed";

    target = CVOpenGLESTextureGetTarget(renderTexture);
    name = CVOpenGLESTextureGetName(renderTexture);
}

-(void)writeStart{
 //   [session startRunning];
        
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
}


-(void)startBuffer{
    // place the texture in the buffer
    glBindTexture(CVOpenGLESTextureGetTarget(renderTexture),
                  CVOpenGLESTextureGetName(renderTexture));
    
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
}


-(void)writeBuffer:(unsigned long long) time{

  //  if(!session.isRunning) return;
    CMTime frameTime = CMTimeMake(time, 1000);

    if (!videoWriterInput.readyForMoreMediaData)
    {
        NSLog(@"Had to drop a video frame");
    } else {
        
        if(![adaptor appendPixelBuffer:renderTarget withPresentationTime:frameTime])
        {
            NSLog(@"Problem appending pixel buffer at time: %lld", frameTime.value);
        } else {
            NSLog(@"Recorded pixel buffer at time: %lld", frameTime.value);
        }
    }
    CVPixelBufferUnlockBaseAddress(renderTarget, 0);
}

// Finish the session
-(void)writeEnd {
    
    std::cout << "END OF WRITING" <<std::endl;
    
    [videoWriterInput markAsFinished];
//    [videoWriter end]
    
    [videoWriter finishWritingWithCompletionHandler:^{
        
        [self composeTracks];
        
        NSLog(@"FINISHING WRITING");
        
        [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:(vidCount + 1)] forKey:@"vidcount"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
//        [videoWriter release];
        
    }];
}

- (void)cancelWriting {
    
    [videoWriterInput markAsFinished];
    
    // clean up original/source videos
    [self cleanupSources];
    
    // set delegate to done for transitioning viewcontrollers
    delegate->done = true;
    
}

- (void)cleanupSources {
    
    // clean up videos
    
    NSString *originalVideoPath = [documentsDirectory stringByAppendingPathComponent:@"movie.mp4"];
    // get current video name
    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"vidcount"])
        vidCount = [[[NSUserDefaults standardUserDefaults] valueForKey:@"vidcount"] intValue];
    else
        vidCount = 1;
    
    NSString *videoName = [NSString stringWithFormat:@"movie_edit_new_%i.mp4", (vidCount)];
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:videoName];
    
    // remove the original movie, and editted movie
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:videoOutputPath] error:nil];
    
    // also remove the upCount movie, if it exists
    videoName = [NSString stringWithFormat:@"movie_edit_new_%i.mp4", (vidCount + 1)];
    videoOutputPath = [documentsDirectory stringByAppendingPathComponent:videoName];
    
    // remove the original movie, and editted movie
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:originalVideoPath] error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:videoOutputPath] error:nil];    
    
}

@end

// ----------------------------------------------------------------------------------------

#pragma mark -
#pragma mark DEBUG THIS

ofxiOSVideoWriter::ofxiOSVideoWriter(){
    text = NULL;
    writer = [[ofxiOSNativeVideoWriter alloc] init];
    writer->delegate = this;
    [writer createVideo];
    done = false;
}

void ofxiOSVideoWriter::setup(){

}

void ofxiOSVideoWriter::startVideo(){
    [writer startVideo];
    
}

ofxiOSVideoWriter::~ofxiOSVideoWriter(){
    
}

void ofxiOSVideoWriter::writeFrame(unsigned long long time){
    
//    unsigned long long time = ofGetSystemTime() - startTime;
    [writer writeBuffer:time];
    
}
void ofxiOSVideoWriter::writeEnd(){
    [writer writeEnd];
}

void ofxiOSVideoWriter::writeStart(){        
    startTime = ofGetSystemTime();
    [writer writeStart];
}

ofFbo * ofxiOSVideoWriter::createBuffer(){
    [writer genTexture];
    name = writer->name;
    target = writer->target;
    ofFbo * fbo = new ofFbo();
    
    fbo->allocate(640, 480);
    fbo->getTextureReference().texData.glTypeInternal = GL_RGBA;
    
    fbo->getTextureReference().texData.textureID = name;
    fbo->getTextureReference().texData.textureTarget = target;
    
    return fbo;
}

void ofxiOSVideoWriter::bindBuffer(){
    [writer startBuffer];
}

void ofxiOSVideoWriter::cancelWriting() {
    [writer cancelWriting];
}

void ofxiOSVideoWriter::cleanupSources() {
    [writer cleanupSources];
}

//void ofxiOSVideoWriter::setVidCount(int count){
//    writer->vidCount = count;
//    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:count] forKey:@"vidcount"];
//    [[NSUserDefaults standardUserDefaults] synchronize];
//}


