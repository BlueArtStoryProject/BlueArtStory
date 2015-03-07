#pragma once

#include "ofMain.h"
#include "ofxiOS.h"
#include "ofxiOSExtras.h"


#include "ofxOpenCv.h"

#include "ofxFaceTracker.h"
#include "ofxiOSVideoWriter.h"

#include "DocumentsVideoContainerViewController.h"
#include "ExplanationViewController.h"

#include "ofxXmlSettings.h"

#include "AVCamViewController.h"

// struct Blokje element
class elem {
    
public:
    ofVec3f p1;
    ofVec3f p2;
    ofVec3f p3;
    
    float per1;
    float per2;
    float per3;
    
    float color;
    
    ofVec3f prev;
    
    int size;
    
    float x;
    float y;
    
    int id;
    
};

class testApp : public ofxiOSApp{
	
    public:
        void setup(); 
        void update();
        void draw();
        void exit();
	
        void touchDown(ofTouchEventArgs & touch);
        void touchMoved(ofTouchEventArgs & touch);
        void touchUp(ofTouchEventArgs & touch);
        void touchDoubleTap(ofTouchEventArgs & touch);
        void touchCancelled(ofTouchEventArgs & touch);

        void lostFocus();
        void gotFocus();
        void gotMemoryWarning();
        void deviceOrientationChanged(int newOrientation);
    
        void openExplanation();
        void closeExplanation();
        void openCam();
        
        void drawPolly(ofPolyline line,int expand);
        void drawMask();
    
        AVCamViewController * controller;
        DocumentsVideoContainerViewController * libController;
        ExplanationViewController *explanationController;
    
        ofxiOSVideoPlayer player;
        ofxCvColorImage clrImg;
        ofxCvGrayscaleImage greyImg;
    
        ofxiOSVideoWriter writer;
        
        // GUI
        ofImage pluginOverlay;
        ofImage statusOverlay;
        ofTrueTypeFont font;

        int cameraPosition;
        bool working;
    
        int processingLeft;
        int totalProcessings;
        double totalProcessingTime;
        float timeLeft;
        int skipFrames;
    
        bool firstFaceDetected;
    
        ofFbo * fbo;
//
//        ofFbo * drawFBO;
    
        // mask stuff
        ofxFaceTracker tracker;
        vector<elem>            elems;
        
        
        // -------- mask position -------- //
        ofVec2f             position;
        float               scale;
        ofVec3f             orientation;
        ofMatrix4x4         rotationMatrix;
        // -------- mask position -------- //
        
        
        // -------- mask settings -------- //
        float maxSize;          // max blok size
        float minSize;          // minimale blok size
        float factor;           // grootte
        float ease;             // transition ease
        float alpha;            // blok alpha
        float hh;               // hoogte hoofd
        float mouthDist;        // mond afstand. nog gebruikt????
        bool rotateRects;       // flat or rotate the rects
        // -------- mask settings -------- //
    
    GLuint viewFrameBuffer;
    GLuint viewRenderBuffer;
    
    GLuint depthStencilBuffer;
    
    
    
    
};


