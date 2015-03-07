//
//  DocumentsVideoViewController.h
//  DocumentsVideo
//
//  Created by Wes Saalmink on 12/7/13.
//  Copyright (c) 2013 Revolución. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@class DocumentsVideoViewController;

@protocol DocumentsVideoViewControllerDelegate <NSObject>
    - (void)backButtonTapped;
@end

@interface DocumentsVideoViewController : UITableViewController

- (void)reloadTableView;

@property (nonatomic, strong) id <DocumentsVideoViewControllerDelegate> delegate;
@property (nonatomic, strong) NSArray *videoArray;

@end
