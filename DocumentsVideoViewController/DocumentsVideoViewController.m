//
//  DocumentsVideoViewController.m
//  DocumentsVideo
//
//  Created by Wes Saalmink on 12/7/13.
//  Copyright (c) 2013 Revolución. All rights reserved.
//

#import "DocumentsVideoViewController.h"

@interface DocumentsVideoViewController ()

@end

@implementation DocumentsVideoViewController
    
@synthesize videoArray = _videoArray;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self readDocumentsDirectoryForVideos];
    
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] init];
    backBarButton.title = @"Back";
    backBarButton.target = self;
    backBarButton.action = @selector(selfClose);
    self.navigationItem.leftBarButtonItem = backBarButton;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
}

- (void)viewWillAppear:(BOOL)animated {
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
}

- (void)reloadTableView {
    
    NSLog(@"reloading tableview child");
    
    [self readDocumentsDirectoryForVideos];
    [self.tableView reloadData];
    
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
     self.videoArray = nil;
}

#pragma mark - Custom Methods

- (void)readDocumentsDirectoryForVideos
{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSArray * files = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:documentsDirectory  error:nil];
  
    self.videoArray = [files filteredArrayUsingPredicate:
                       [NSPredicate predicateWithFormat:@"pathExtension IN %@",
                        [NSArray arrayWithObjects:@"mp4", @"mov", @"m4v", nil]
                        ]];
    
    // sort alphanumerically
    self.videoArray = [self.videoArray sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [(NSString *)obj1 compare:(NSString *)obj2 options:NSNumericSearch];
    }];

    NSLog(@"videoArray: %@", self.videoArray);
    
}

- (void)deleteVideo:(NSString *)fileName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];

    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:filePath error: &error];

    [self readDocumentsDirectoryForVideos];
}

- (void)selfClose
{
    [self.delegate backButtonTapped];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.videoArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    cell.textLabel.text = [[[self.videoArray objectAtIndex:indexPath.row] lastPathComponent] stringByDeletingPathExtension];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

// Enabling deletion of rows
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        NSString *videoFile= [self.videoArray objectAtIndex:indexPath.row];
        
        [self deleteVideo:videoFile];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
    }
    
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (self.videoArray == nil)
        [self readDocumentsDirectoryForVideos];
    
    NSLog(@"videoArray: %@", self.videoArray);
    
    NSString *videoFile= [self.videoArray objectAtIndex:indexPath.row];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *videoPath = [documentsDirectory stringByAppendingPathComponent:videoFile];
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    
    MPMoviePlayerViewController *moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:videoURL];
    [self.view.window.rootViewController presentViewController:moviePlayer animated:YES completion:nil];
    
//    [self presentMoviePlayerViewControllerAnimated:moviePlayer];
    
    
}



@end
