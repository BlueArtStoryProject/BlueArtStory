/*
 *  AVFoundationVideoGrabber.h
 *
 */

#pragma once

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVCaptureOutput.h>

//#if __IPHONE_OS_VERSION_MIN_REQUIRED > __IPHONE_3_2

#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#include "ofMain.h"

class ofxiOSVideoWriter;

@interface ofxiOSNativeVideoWriter : UIViewController <AVCaptureAudioDataOutputSampleBufferDelegate> {
    
@public
    AVAssetWriter *videoWriter;
    AVAssetWriterInput* videoWriterInput;
    AVAssetWriterInput* audioWriterInput;
   // AVCaptureDevice* audioDevice;
    //AVCaptureDeviceInput *audioInput;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
   // AVCaptureAudioDataOutput *audioOutput;
//    NSString *videoOutputPath;
    NSString *documentsDirectory;

    CVPixelBufferRef renderTarget;
    CVOpenGLESTextureCacheRef coreVideoTextureCache;
    
    CVOpenGLESTextureRef renderTexture;
    
    GLenum target;
    GLuint name;
    
    int vidCount;
    
    ofxiOSVideoWriter *delegate;
    
    CGSize imageSize;
   // AVCaptureSession *session ;
    
    
}

@end

// ----------------------------------------------------------------------------------------

class ofxiOSVideoWriter {
    
    public:
        ofxiOSVideoWriter();
        ~ofxiOSVideoWriter();
        
        void setup();
        void startVideo();
    
        ofFbo * createBuffer();
        void writeStart();
        void bindBuffer();
        void writeFrame(unsigned long long time);
        void writeEnd();
        void setVidCount(int count);
        void cancelWriting();
        void cleanupSources();    
    
        GLenum target;
        GLuint name;
        unsigned long long startTime;
        ofTexture * text;
    
        bool done;
    
    protected:
        ofxiOSNativeVideoWriter * writer;
    
};

