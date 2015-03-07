#include "testApp.h"

#import "AVFoundationVideoPlayer.h"

using namespace ofxCv;
using namespace cv;


//--------------------------------------------------------------
void testApp::setup(){
    
    ofSetOrientation(OF_ORIENTATION_90_LEFT);

    writer.setup();

    // security cleanup
    writer.cleanupSources();
    
    fbo = writer.createBuffer();
    
    clrImg.allocate(640, 480);
    greyImg.allocate(640, 480);
    
    ofSetColor(0,0,0, 255);
    
    tracker.setup();
    tracker.setIterations(25);
    tracker.setClamp(3);
    tracker.setAttempts(4);
    
    openExplanation();
    
    //openCam();
    
    writer.startVideo();

    pluginOverlay.loadImage("images/pluginvideo.png");
    statusOverlay.loadImage("images/Wait_grijs.png");
    font.loadFont("arialbold.ttf", 10);
    
    // Setup
    maxSize = 4.4f;
    minSize = 1.45f;
    factor = 2.85f;
    mouthDist = 2.9f;
    alpha = 0.415f;
    ease = 0.92f;
    rotateRects = true;
    hh = 2.0f;
    
//    player
    skipFrames = 2;
    
    [[controller view] setHidden:YES];
    [[controller view] setAlpha:0.0f];
    
    
}

void testApp::openExplanation() {
    
    if(!explanationController) {
        
        explanationController = [[ExplanationViewController alloc] init];
        [ofxiOSGetGLParentView() addSubview:explanationController.view];
  
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:NO];
//        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
        
    }
    
}

void testApp::closeExplanation() {
    [explanationController.view removeFromSuperview];
    [explanationController release];
    explanationController = nil;
}

void testApp::openCam(){
    
    controller = [[AVCamViewController alloc] initWithNibName:@"AVCamViewController" bundle:nil];
    [ofxiOSGetGLParentView() addSubview:controller.view];
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:YES];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
    
}

//--------------------------------------------------------------
void testApp::update(){
    
    if (explanationController && explanationController->remove) {
        
        closeExplanation();
        openCam();
        
    }
    
    if(controller && controller->done){
                
        player.loadMovie(ofxiPhoneGetDocumentsDirectory() + "movie.mp4");
        
        working = true;
        
        // set camera position
        cameraPosition = controller->cameraPosition;
        
        writer.writeStart();
        
        std::cout << "controller done" << std::endl;
        
        controller->done = false;
        
        [UIView animateWithDuration:0.15f
                              delay:0 options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [[controller view] setAlpha:0];
                         } completion:^(BOOL) {
                             [[controller view] setHidden:YES];
                         }];
        
//        controller = NULL;
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
        
    }
    
    if((controller && controller->lib) || writer.done){
        
        writer.done = false;
        
        if (controller && controller->lib)
            controller->lib = false;
        
        std::cout << "writing done" << std::endl;
        
        if(!libController) {
            
            libController = [[DocumentsVideoContainerViewController alloc] init];
            [ofxiOSGetGLParentView() addSubview:libController.view];
            
            // make libController appear out of view
            CGRect libFrame = [libController.view frame];
            libFrame.origin.x = libFrame.size.height;
            [libController.view setFrame:libFrame];
            
            // set back to 0
            libFrame.origin.x = 0;
            
            // animate lib IN
            [UIView animateWithDuration:0.25f
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 [libController.view setFrame:libFrame];
                             }
                             completion:^(BOOL){
                                 
                                 if (controller) {
                                     [[controller view] setHidden:YES];
                                     [[controller view] setAlpha:1.0f];
                                 }
                                 
                             }];
            
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
            
        }
        else {
            
            [libController reloadTableView];
                        
            CGRect libFrame = [libController.view frame];
            libFrame.origin.x = libFrame.size.height;
            [libController.view setFrame:libFrame];
            
            // set back to 0
            libFrame.origin.x = 0;
            
            if (controller && controller->lib) {
                controller->lib = false;
            }
            
            // animate IN
            [UIView animateWithDuration:0.25f
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 [libController.view setFrame:libFrame];
                             }
                             completion:nil];
            
            [[libController view] setHidden:NO];
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
            
        }
    }
    
    if(libController && libController->remove){
        
        if (!controller) {
            std::cout << "controller is null" << std::endl;
            openCam();
            
            writer.startVideo();
            
        } else {
            
            [[controller view] setHidden:NO];
            [[controller view] setAlpha:1.0f];
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
            
            writer.startVideo();
            
        }
        
        libController->remove = false;
        
        // make lib appear out of view
        CGRect libFrame = [libController.view frame];
        libFrame.origin.x = 320;
        
        [UIView animateWithDuration:0.25f
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             [libController.view setFrame:libFrame];
                         }
                         completion:^(BOOL){
                             
                             [[libController view] setHidden:YES];
                         }];

    }
    
    if(working){
        
        int newFrame = min(player.getTotalNumFrames(), player.getCurrentFrame() + skipFrames);
        player.setFrame(newFrame);
        
        player.update();
        
        if(player.getPosition() == 0.0f) {
            
            firstFaceDetected = false;
            
            processingLeft = ceil((player.getDuration() * 1000) / 66.0f);
            skipFrames = 2;
            totalProcessingTime = totalProcessings = 0;
            
            ofClear(255,255,255, 0);
            
            // enable battery monitoring
            [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
            
        }
        
        if(player.getPosition() >= 1.0f){
            
            working = false;
            writer.writeEnd();
            
            skipFrames = 2;
            
            std::cout << "DONE" <<std::endl;
            
            ofSetColor(0,0,0, 255);
            clrImg.draw(0,0,640,480);
            greyImg.draw(0,0,640,480);
            
            ofClear(255,255,255, 0);
            
            // disable battery monitoring
            [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
            
        }
        if(player.isFrameNew()){
            
            clock_t begin = clock();
            
            clrImg.setFromPixels(player.getPixels(), 640, 480);
            greyImg.setFromColorImage(clrImg);
            
            // mirror image vertically when front camera is used
            if(cameraPosition == AVCaptureDevicePositionFront) {
                greyImg.mirror(true, false);
                clrImg.mirror(true, false);
            }
            
            // feed cvImage to tracker for face detection
            tracker.update(toCv(clrImg));
            
            // if found, set attributes
            if (tracker.getFound()) {
                
                firstFaceDetected = true;
                
                position = tracker.getPosition();
                scale = tracker.getScale();
                orientation = tracker.getOrientation();
                rotationMatrix = tracker.getRotationMatrix();
            }
            
            // set up fbo
            fbo->getTextureReference().texData.tex_u = 1.0f;
            fbo->getTextureReference().texData.tex_t = 1.0f;
            
            fbo->begin();
            
            // reset color for drawing
            ofSetColor(255, 255, 255);
            
            // only if a face is detected, draw it to fbo
            if (tracker.getFound()) {
                
                writer.bindBuffer();
                greyImg.draw(0, 0);
                drawMask();
                
            }
            
            // send fbo data to videowriter
            writer.writeFrame((player.getPosition() * player.getDuration()) * 1000.0f);
            fbo->end();
            
            std::cout << "working >> " << (player.getPosition() * player.getDuration()) * 1000.0f << std::endl;
            
            clock_t end = clock();
            
            // track estimated time left
            double elapsed_secs = double(end - begin) / CLOCKS_PER_SEC;
            totalProcessingTime += elapsed_secs;
            
            // average processed time for more accurate estimates
            timeLeft = (totalProcessingTime / totalProcessings ) * processingLeft;
            
            // if no face found, skip a couple of frame extra to speed it up
            if (!tracker.getFound()) {
                std::cout << "tracking face did not work" << std::endl;
                skipFrames = 16;
            } else {
                skipFrames = 2;
            }
        
            // decrement processingLeft for time calculation
            totalProcessings = totalProcessings + (skipFrames * 0.5);
            processingLeft = processingLeft - (skipFrames * 0.5);
            
        }
    }
    
    
}

//--------------------------------------------------------------
void testApp::draw(){
    //player.draw(0,0);
    
    ofBackground(61, 61, 61);
    ofSetColor(255, 255, 255);
    
    ofEnableAlphaBlending();
    
    // only draw this if video is rendering
    if (working) {
        
//        clrImg.draw(70, 0,428,320);
        
        // to prevent old fragments being drawn, only draw the fbo when the trackers recognizes a face from the start,
        // or if a face has already been recognized in the current loop
        if (tracker.getFound() || firstFaceDetected)
            fbo->draw(70,0,428,320);
        
        /*
        glPushMatrix();
        glTranslatef(70,0,0);
        ofScale(428.0f/640.0f, 320.0f/480.0f);
        
        tracker.draw();
        
        ofSetColor(255, 255, 255);
        glPopMatrix();
        */

        statusOverlay.draw( 0, 0, 568, 320);
        
        // loading status bar
        float statusBarX = ((ofGetWidth() - (statusOverlay.width * 0.5)) * 0.5) + 166;
        ofSetColor(14, 43, 251);
        ofRect( statusBarX, 251, 197 * player.getPosition(), 12); // 250 is the width of the filler
        
        ofSetColor(255, 255, 255);
        if (timeLeft > 60) {
            font.drawString("Rendering video, " + ofToString(round(timeLeft / 60.0f)) + " minutes left...", statusBarX , 243);
        } else {
            font.drawString("Rendering video, " + ofToString(round(timeLeft)) + " seconds left...", statusBarX , 243);
        }
        
        if ([[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateUnplugged) {
            pluginOverlay.draw( 0, 0, 568, 320);
        }
        
    }
    
    ofDisableAlphaBlending();
    
}


void testApp::drawPolly(ofPolyline line, int expand) {
    
    glPushMatrix();
    
    ofEnableAlphaBlending();
    glBlendFunc(GL_ZERO, GL_SRC_COLOR);
    
    ofRectangle boundingBox = line.getBoundingBox();
    ofTexture texture = greyImg.getTextureReference();
    
//    ofSetColor(0,0,240,150);
    

    ofSetColor(0,0,255,255);

    // translated coordinates
    greyImg.setROI(position.x + ((boundingBox.x * scale) - expand),
                   position.y + ((boundingBox.y * scale) - expand),
                   (boundingBox.width * scale) + (expand * 2),
                   (boundingBox.height * scale) + (expand * 2));
    
    greyImg.drawROI(position.x + ((boundingBox.x * scale) - expand),
                    position.y + ((boundingBox.y * scale) - expand));
  
//    greyImg.drawROI(0,0);
    
    greyImg.resetROI();

//    texture.drawSubsection(position.x + (boundingBox.x * scale),
//                           position.y + (boundingBox.y * scale),
//                           boundingBox.width * scale,
//                           boundingBox.height * scale,
//                           position.x + (boundingBox.x * scale),
//                           position.y + (boundingBox.y * scale));
  
    ofDisableAlphaBlending();
    
    glPopMatrix();
    
}

void testApp::drawMask() {
    
    if(tracker.getFound()) {
        
        
//        fbo.begin();        // ------- FBO BEGIN --------//
        ofSetColor(255);
        
		ofSetLineWidth(1);
        
        ofPolyline face;
        face.addVertex(tracker.getMeanObjectMesh().getVertex(0));
        face.addVertex(tracker.getMeanObjectMesh().getVertex(17));
        face.addVertex(tracker.getMeanObjectMesh().getVertex(21));
        face.addVertex(tracker.getMeanObjectMesh().getVertex(22));
        face.addVertex(tracker.getMeanObjectMesh().getVertex(25));
        face.addVertex(tracker.getMeanObjectMesh().getVertex(16));
        
        ofVec3f topL = tracker.getMeanObjectMesh().getVertex(26);
        ofVec3f topR = tracker.getMeanObjectMesh().getVertex(17);
        ofVec3f top = tracker.getMeanObjectMesh().getVertex(21) + tracker.getMeanObjectMesh().getVertex(22);
        
        top /= hh;
        
        float hdiff = tracker.getMeanObjectMesh().getVertex(27).y - top.y; // was 8
        
        hdiff /= 0.2f;
        
        topL.y -= (hdiff * 0.8);
        topR.y -= (hdiff * 0.8);
        
        top.y -= hdiff;
        
        face.addVertex(topL);
        
        face.addVertex(top);
        face.addVertex(topR);
        
        face.close();
        face.draw();
        ofMesh mm ;
        
        mm.addVertices(face.getVertices());
        
        vector<ofIndexType> ind;
        
        ind.push_back(0);
        ind.push_back(1);
        ind.push_back(face.getVertices().size()-1);
        
        ind.push_back(1);
        ind.push_back(face.getVertices().size()-2);
        ind.push_back(face.getVertices().size()-1);
        
        ind.push_back(1);
        ind.push_back(2);
        ind.push_back(face.getVertices().size()-2);
        
        ind.push_back(2);
        ind.push_back(3);
        ind.push_back(face.getVertices().size()-2);
        
        ind.push_back(3);
        ind.push_back(4);
        ind.push_back(face.getVertices().size()-2);
        
        ind.push_back(4);
        ind.push_back(face.getVertices().size()-2);
        ind.push_back(face.getVertices().size()-3);
        
        ind.push_back(4);
        ind.push_back(face.getVertices().size()-3);
        ind.push_back(5);
        
        mm.addIndices(ind);
        
        ofSetupScreenOrtho(640, 480, OF_ORIENTATION_UNKNOWN, false, -1000, 1000);
        glPushMatrix();
        
//        ofTranslate(position.x, position.y);
        glTranslatef(position.x, position.y, 0);
		applyMatrix(rotationMatrix);
        ofScale(scale,scale,scale);
        
        int count_i = 0;
        
        ofMesh m = tracker.getObjectMesh();
        
        vector<ofIndexType> ii =  m.getIndices();
        
        for(int i = 0; i < ii.size(); i += 3){ // --- draw the face --- //
            int amount = 40;
            for(int k = 0; k < amount; k++){
                
                if(elems.size() <= count_i) {
                    elem e;
                    e.per1 = ofRandom(0, 1);
                    e.per2 = ofRandom(0, 1);
                    e.per3 = ofRandom(0, 1);
                    e.id = i;
                    
                    if(i == 66 || i == 69 || i == 72 || i == 75 || i == 78 || i == 87|| i == 183 || i ==186|| i == 81 || i == 84) e.color = 0.1;
                    else if (i == 6 || i == 12 || i == 30 || i == 81 || i == 147 ||  i == 153 ) e.color = 0.1;
                    else if(i == 24 || i == 27 || i == 36 || i == 39 || i == 42 || i == 54 || i == 57) e.color = 0.1;
                    else if(i == 93 || i == 99 || i == 165 || i == 171 || i == 189 || i == 207 || i == 213) e.color = 0.1;
                    else if(i == 219 || i == 225 || i == 228 || i == 63 ) e.color = 0.3;
                    else e.color = 0.8;
                    
                    elems.push_back(e);
                }
                
                elems[count_i].p1 = m.getVertex(ii[i]);
                elems[count_i].p2 = m.getVertex(ii[i + 1]);
                elems[count_i].p3 = m.getVertex(ii[i + 2]);
                count_i++;
            }
        }
        
        for(int i = 0; i < ind.size(); i += 3){ // --- draw the head --- //
            int amount = 65;
            for(int k = 0; k < amount; k++){
                if(elems.size() <= count_i) {
                    elem e;
                    e.per1 = ofRandom(0, 1);
                    e.per2 = ofRandom(0, 1);
                    e.per3 = ofRandom(0, 1);
                    e.color = 1;
                    
                    if (i == 0) {
                        e.color = 0.1;
                    }
                    
                    elems.push_back(e);
                }
                
                elems[count_i].p1 = mm.getVertex(ind[i]);
                elems[count_i].p2 = mm.getVertex(ind[i + 1]);
                elems[count_i].p3 = mm.getVertex(ind[i + 2]);
                count_i++;
            }
        }
        
        if(elems.size() > count_i){
            elems.erase(elems.begin() + count_i, elems.begin() +elems.size());
        }
        
//        ofPolyline eye_left = tracker.getObjectFeature(ofxFaceTracker::LEFT_EYE);
//        ofPoint pp_eye_left_center = eye_left.getBoundingBox().getCenter();
//        ofPolyline eye_right = tracker.getObjectFeature(ofxFaceTracker::RIGHT_EYE);
//        ofPoint pp_eye_right_center = eye_right.getBoundingBox().getCenter();
//        ofPolyline mouth = tracker.getObjectFeature(ofxFaceTracker::INNER_MOUTH);
//        ofPoint pp_mouth_center = mouth.getBoundingBox().getCenter();
        
        for(int i = 0; i < elems.size(); i++){
            
            ofPoint c;
            c =  elems[i].p1 / 3;
            c += elems[i].p2 / 3;
            c += elems[i].p3 / 3;
            
            ofPoint p;
            p = (( elems[i].p1 - c) * elems[i].per1);
            p += ((elems[i].p2 - c) * elems[i].per2);
            p += ((elems[i].p3 - c) * elems[i].per3);
            p += c;
//            float sizeLE = pp_eye_left_center.distance(p);
//            float sizeRE = pp_eye_right_center.distance(p);
//            float sizeM = pp_mouth_center.distance(p);
            float size = 4.0f;
           
            elems[i].prev = (elems[i].prev * (1.0f - ease)) + (p * ease);
            
            p = elems[i].prev;
            
            ofEnableAlphaBlending();
            
            ofSetColor(0, 0, (255 - p.z) * ((elems[i].color/4.0f)+0.75f), (255.0f * ( 1.0f - alpha)) + ( elems[i].color * alpha));
            
            glPushMatrix();
            glTranslatef(p.x, p.y, p.z);
            if(!rotateRects) applyMatrix(rotationMatrix.getInverse());
            
            ofRect( - (size/2),  - (size/2), 0, size,size);
            
            glPopMatrix();
            
            ofDisableAlphaBlending();
        }
        
//        ofSetColor(0,0,100,255);
        ofSetColor(0,0,255,255);
        
        glPopMatrix();
        
        ofSetColor(255,255,255);
        
        greyImg.threshold(70);
        
        drawPolly(tracker.getObjectFeature(ofxFaceTracker::LEFT_EYE), 8);
        drawPolly(tracker.getObjectFeature(ofxFaceTracker::LEFT_EYEBROW), 5);
        drawPolly(tracker.getObjectFeature(ofxFaceTracker::RIGHT_EYE), 9);
        drawPolly(tracker.getObjectFeature(ofxFaceTracker::RIGHT_EYEBROW), 7);
        drawPolly(tracker.getObjectFeature(ofxFaceTracker::OUTER_MOUTH), 2);
        
        
        
        /*
        glPushMatrix();
        glTranslatef(position.x, position.y, 0);
//        ofTranslate(position.x, position.y );
        applyMatrix(rotationMatrix);
        ofScale(scale,scale,scale);
        
        ofPoint le = tracker.getObjectFeature(ofxFaceTracker::LEFT_EYE).getCentroid2D();
        ofPoint re = tracker.getObjectFeature(ofxFaceTracker::RIGHT_EYE).getCentroid2D();
        ofPoint me = tracker.getObjectFeature(ofxFaceTracker::OUTER_MOUTH).getCentroid2D();
        
        ofEnableAlphaBlending();
        glBlendFunc(GL_ZERO, GL_SRC_COLOR);
        
        ofSetColor(0, 0, 255, 255);
        ofRect(le.x-5, le.y-5, 10,10);
        
        ofRect(re.x-5, re.y-5, 10,10);
        ofRect(me.x-10, me.y-7, 20,14);
        
        ofDisableAlphaBlending();
        glPopMatrix();
         */
        
//        fbo.end();         // ------- FBO EIND --------//
        
	}
    
}

//--------------------------------------------------------------
void testApp::exit(){
    writer.cleanupSources();
}

//--------------------------------------------------------------
void testApp::touchDown(ofTouchEventArgs & touch){
}

//--------------------------------------------------------------
void testApp::touchMoved(ofTouchEventArgs & touch){

}

//--------------------------------------------------------------
void testApp::touchUp(ofTouchEventArgs & touch){
    
    // cancel event
    float cancelButtonLeft = ofGetWidth() - 200;
    
    if (working &&
        touch.x > cancelButtonLeft &&
        touch.x < (cancelButtonLeft + 60) &&
        touch.y > 240 && touch.y < 280) {
        
            std::cout << "cancelbutton" << std::endl;
            working = false;
            writer.cancelWriting();

            ofSetColor(0,0,0, 255);
        
            clrImg.draw(0,0);
            greyImg.draw(0,0);
        
    }
    
    
}

//--------------------------------------------------------------
void testApp::touchDoubleTap(ofTouchEventArgs & touch){

}

//--------------------------------------------------------------
void testApp::touchCancelled(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void testApp::lostFocus(){
    writer.cleanupSources();
}

//--------------------------------------------------------------
void testApp::gotFocus(){
    writer.cleanupSources();
}

//--------------------------------------------------------------
void testApp::gotMemoryWarning(){

}

//--------------------------------------------------------------
void testApp::deviceOrientationChanged(int newOrientation){
//    ofSetOrientation((ofOrientation)newOrientation);
}

