//
//  DocumentsVideoContainerViewController.h
//  DocumentsVideo
//
//  Created by Wes Saalmink on 12/7/13.
//  Copyright (c) 2013 Revolución. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DocumentsVideoViewController.h"

@interface DocumentsVideoContainerViewController : UINavigationController <DocumentsVideoViewControllerDelegate>{
@public
    bool remove;
    
}

- (void)reloadTableView;

@property (nonatomic, strong) DocumentsVideoViewController *documentsVideoViewController;

@end
