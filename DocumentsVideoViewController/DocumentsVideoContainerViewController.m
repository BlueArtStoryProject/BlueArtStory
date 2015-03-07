//
//  DocumentsVideoContainerViewController
//  DocumentsVideo
//
//  Created by Wes Saalmink on 12/7/13.
//  Copyright (c) 2013 Revolución. All rights reserved.
//

#import "DocumentsVideoContainerViewController.h"
#import "DocumentsVideoViewController.h"

@interface DocumentsVideoContainerViewController ()

@end

@implementation DocumentsVideoContainerViewController

-(id)init {
    self.documentsVideoViewController = [[DocumentsVideoViewController alloc] initWithNibName:@"DocumentsVideoViewController" bundle:nil];
    self = [super initWithRootViewController:self.documentsVideoViewController];
    if (self) {
        // Custom initialization
        self.documentsVideoViewController.delegate = self;
    }
    remove = false;
    return self;
    
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
        
}

- (void)viewWillAppear:(BOOL)animated {
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
}

- (void)reloadTableView {
    NSLog(@"reload table view container");
    [self.documentsVideoViewController reloadTableView];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - DocumentsVideoController delegate methods
- (void)backButtonTapped {
    remove = true;
}


@end
