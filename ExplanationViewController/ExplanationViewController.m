//
//  ExplanationViewController.m
//  Bluescreen
//
//  Created by Wes Saalmink on 15/04/14.
//
//

#import "ExplanationViewController.h"

#define NUMBER_OF_INSTRUCTIONS 7

@interface ExplanationViewController ()

@property (retain, nonatomic) IBOutlet UIScrollView *scrollView;
@property (retain, nonatomic) IBOutlet UIPageControl *pageControl;
@property (retain, nonatomic) IBOutlet UIButton *closeButton;

@end

@implementation ExplanationViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        remove = false;
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    // welcome screen
    UIImageView *welcomeImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"00_welcome.jpg"]];
    welcomeImageView.transform =  CGAffineTransformMakeRotation(M_PI/ 2);
    welcomeImageView.frame = CGRectMake(0, 0, 320, 568);
    [self.scrollView addSubview:welcomeImageView];
    
    // add instruction images
    for (int i = 1; i < NUMBER_OF_INSTRUCTIONS; i++) {
        NSString *imageName = [NSString stringWithFormat:@"0%d_step%d.jpg", i, i];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:imageName]];
        imageView.transform =  CGAffineTransformMakeRotation(M_PI/ 2);
        imageView.frame = CGRectMake(0, i * 568, 320, 568);
        [self.scrollView addSubview:imageView];
    }
    
    // set scrollview content size
    self.scrollView.delegate = self;
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.frame.size.width, self.scrollView.frame.size.height * NUMBER_OF_INSTRUCTIONS)];
    
    self.closeButton.transform = CGAffineTransformMakeRotation(M_PI/2);
    
    self.pageControl.transform = CGAffineTransformMakeRotation(M_PI/2);
    self.pageControl.numberOfPages = 7;
    self.pageControl.currentPageIndicatorTintColor = [UIColor colorWithRed:14.0f/255.0f green:43.0f/255.0f blue:251.0f/255.0f alpha:1.0f];
    
    // add tap recognizer
    UITapGestureRecognizer *scrollViewTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeExplanation:)];
    [scrollViewTap setDelegate:self];
    [scrollViewTap setNumberOfTapsRequired:1];
    [scrollViewTap setCancelsTouchesInView:NO];
    [self.scrollView addGestureRecognizer:scrollViewTap];
    [scrollViewTap release];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_scrollView release];
    [_pageControl release];
    [_closeButton release];
    [super dealloc];
}

#pragma mark - Custom Methods
-(IBAction)closeExplanation:(UITapGestureRecognizer *)gestureRecognizer {

    float fractionalPage = self.scrollView.contentOffset.y / self.scrollView.frame.size.height;
    NSInteger page = lround(fractionalPage);
    
    if (page == NUMBER_OF_INSTRUCTIONS - 1)
        remove = true;
    
}

#pragma mark - Delegate Methods
-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    float fractionalPage = self.scrollView.contentOffset.y / self.scrollView.frame.size.height;
    NSInteger page = lround(fractionalPage);
    self.pageControl.currentPage = page;
    
}

@end
