//
//  DKLaunchController.m
//  TabDump
//
//  Created by Daniel on 4/22/14.
//  Copyright (c) 2014 dkhamsing. All rights reserved.
//

#import "DKLaunchController.h"

// Categories
#import "NSString+DK.h"
#import "UIColor+TD.h"
#import "UIImage+DK.h"
#import "UIView+DK.h"
#import "UIViewController+DK.h"

// Controllers
#import "DKSettingsController.h"
#import "DKDayController.h"
#import "DKListSelectionController.h"

#import "DKCategoriesController.h"
#import "DKTabDumpsController.h"

// Defines
#import "DKTabDumpDefines.h"

// Models
#import "DKDevice.h"
#import "DKTab.h"
#import "DKTabDump.h"

// Libraries
#import "AFNetworking.h"
#import "AFOnoResponseSerializer.h"
#import "DKUserMessageView.h"


@interface DKLaunchController () <DKTabDumpsControllerDelegate, DKDayControllerDelegate>
@property (nonatomic,strong) NSString *currentTitle;
@property (nonatomic,strong) DKListSelectionController *selectionController;
@property (nonatomic,strong) DKDayController *dayController;
@property (nonatomic,strong) UIView *loadingView;
@property (nonatomic,strong) DKUserMessageView *loadingSpinner;
@property (nonatomic,strong) DKUserMessageView *loadingText;
@property (nonatomic,strong) UIButton *reloadButton;
@property (nonatomic,strong) UIButton *scrollButton;
@end

@implementation DKLaunchController

CGFloat kNavigationButtonInset = -7;
CGRect kNavigationButtonFrame = {0,0,30,44};
CGFloat kNavigationBarHeight = 64;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // style
        [[UINavigationBar appearance] setTintColor:[UIColor td_highlightColor]];
        [[UINavigationBar appearance] setTitleTextAttributes:@{NSFontAttributeName:[UIFont fontWithName:kFontBold size:15]}];
        [[UINavigationBar appearance] setBackIndicatorImage:[UIImage imageNamed:@"top-left"]];
        [[UINavigationBar appearance] setBackIndicatorTransitionMaskImage:[UIImage imageNamed:@"top-left"]];
        [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSFontAttributeName:[UIFont fontWithName:kFontRegular size:11]} forState:UIControlStateNormal];
        
        // init
        self.selectionController = [[DKListSelectionController alloc]init];
        self.selectionController.calendarController.delegate = self;
        
        self.dayController = [[DKDayController alloc] initWithStyle:UITableViewStyleGrouped];
        self.dayController.delegate = self;
        [self dk_addChildController:self.dayController];
        
        // navigaton bar
        UIBarButtonItem *spacerBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        spacerBarButton.width = kNavigationButtonInset;
        UIImage *gearsImage = [UIImage dk_maskedImageNamed:@"top-gears" color:[UIColor td_highlightColor]];
        UIButton *settingsButton = [[UIButton alloc] initWithFrame:kNavigationButtonFrame];
        [settingsButton setImage:gearsImage forState:UIControlStateNormal];
        [settingsButton addTarget:self action:@selector(actionSettings) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *settingsBarButton = [[UIBarButtonItem alloc] initWithCustomView:settingsButton];
        UIImage *listImage = [UIImage dk_maskedImageNamed:@"top-list" color:[UIColor td_highlightColor]];
        
        UIButton *listButton = [[UIButton alloc] initWithFrame:kNavigationButtonFrame];
        [listButton setImage:listImage forState:UIControlStateNormal];
        [listButton addTarget:self action:@selector(actionList) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *listBarButton = [[UIBarButtonItem alloc]initWithCustomView:listButton];
        self.navigationItem.leftBarButtonItems = @[spacerBarButton, listBarButton, settingsBarButton];
        
        self.scrollButton = [[UIButton alloc] init];
        [self setupRightButtons];
        
        // loading
        CGFloat inset = 10;
        self.loadingView = [[UIView alloc] initWithFrame:CGRectMake(0, [DKDevice headerHeight] +kNavigationBarHeight, self.view.dk_width, self.view.dk_height)];
        [self.view addSubview:self.loadingView];
        
        CGRect frame = CGRectMake(0, inset, self.view.dk_width, 40);
        self.loadingSpinner = [[DKUserMessageView alloc] initWithFrame:frame];
        self.loadingText = [[DKUserMessageView alloc] initWithFrame:CGRectMake(0, self.loadingSpinner.dk_bottom +inset, self.view.dk_width, 20)];
        self.loadingText.dk_userMessageLabel.textColor = [UIColor grayColor];
        self.loadingText.dk_userMessageLabel.font = [UIFont fontWithName:kFontRegular size:11];
        
        frame = self.loadingText.frame;
        frame.origin.y = self.loadingText.dk_bottom +inset;
        self.reloadButton = [[UIButton alloc] initWithFrame:frame];
        self.reloadButton.titleLabel.font = self.loadingText.dk_userMessageLabel.font;
        [self.reloadButton setTitle:@"Reload" forState:UIControlStateNormal];
        [self.reloadButton setTitleColor:[UIColor td_highlightColor] forState:UIControlStateNormal];
        [self.reloadButton addTarget:self action:@selector(loadTabDumpRSS) forControlEvents:UIControlEventTouchUpInside];
        [UIView dk_addSubviews:@[self.loadingSpinner, self.loadingText, self.reloadButton] onView:self.loadingView];
        
        NSNumber *nightMode = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaultsSettingsNightMode];
        if ([nightMode isEqual:@1]) {
            self.loadingView.backgroundColor = [UIColor blackColor];
            self.loadingText.backgroundColor = [UIColor blackColor];
        }
        else {
            self.loadingView.backgroundColor = [UIColor whiteColor];
            self.loadingText.backgroundColor = [UIColor whiteColor];
        }
        
        [self loadTabDumpRSS];
    }
    return self;
}


#pragma mark - UIViewController

- (void)viewWillDisappear:(BOOL)animated {
    self.title = @" ";
    [super viewWillDisappear:animated];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = self.currentTitle;
}


#pragma mark - Private

- (void)loadDump:(DKTabDump*)dump {
    self.title = [dump title];
    self.currentTitle = self.title;
    self.dayController.dump = dump;
    
    // update tab dumps read
    NSArray *tabDumpsRead = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaultsTabDumpsRead];
    NSMutableArray *temp;
    if (tabDumpsRead) {
        temp = [tabDumpsRead mutableCopy];
    }
    else {
        temp = [[NSMutableArray alloc] init];
    }
    if (![temp containsObject:dump.date]) {
        [temp addObject:dump.date];
    }
    [[NSUserDefaults standardUserDefaults] setObject:[temp copy] forKey:kUserDefaultsTabDumpsRead];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"launch - load dump - tab dumps read=%@",temp);
}


- (void)loadBeginAnimate {
    [self.loadingSpinner dk_loading:YES spinner:YES];
    [self.loadingText dk_displayMessage:@"Loading Tab Dump"];
    
    self.reloadButton.hidden = YES;
}


- (void)loadTabDumpRSS {    
    NSLog(@"launch - loading rss");
    [self loadBeginAnimate];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFOnoResponseSerializer XMLResponseSerializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:  @"application/rss+xml"];
    [manager GET:kLaunchBlogRSSLink parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        self.loadingView.hidden = YES;
        
        NSArray *dumps = [DKTabDump newListOfDumpsFromResponseData:operation.responseData];
        
        self.selectionController.calendarController.dataSource = dumps;
        self.selectionController.categoriesController.categoriesTabDumps = dumps;
        DKTabDump *dump = dumps[0];
        [self loadDump:dump];
        
        // save to nsuser defaults
        [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:dumps] forKey:kUserDefaultsTabDumpsFromRSS];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"launch - load tab dump - error: %@", error);
        
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        if ([def objectForKey:kUserDefaultsTabDumpsFromRSS]) {
            self.loadingView.hidden = YES;
            NSLog(@"launch - loading previously saved rss");
            
            NSData *data = [def objectForKey:kUserDefaultsTabDumpsFromRSS];
            NSArray *dumps = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            
            self.selectionController.calendarController.dataSource = dumps;
            self.selectionController.categoriesController.categoriesTabDumps = dumps;
            DKTabDump *dump = dumps[0];
            [self loadDump:dump];
        } else {
            
            [self.loadingSpinner dk_loading:NO];
            [self.loadingText dk_loading:NO];
            [self.loadingText dk_displayMessage:@"There was a problem loading Tab Dump."];
            self.reloadButton.hidden = NO;
        }
    }];
}


- (void)setupRightButtons {
    UIImage *downImage = [UIImage dk_maskedImageNamed:@"top-down" color:[UIColor td_highlightColor]];
    self.scrollButton.frame = kNavigationButtonFrame;
    
    [self.scrollButton setImage:downImage forState:UIControlStateNormal];
    [self.scrollButton addTarget:self action:@selector(actionNext) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *nextBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.scrollButton];
    UIBarButtonItem *spacerBarButton2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacerBarButton2.width = kNavigationButtonInset -2;
    [self.navigationItem setRightBarButtonItems:@[spacerBarButton2,nextBarButton] animated:YES];
}


#pragma mark Actions

- (void)actionSettings {
    DKSettingsController *aboutController = [[DKSettingsController alloc] init];
    [self.navigationController pushViewController:aboutController animated:YES];
}


- (void)actionList {
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:self.selectionController];
    [self presentViewController:navigationController animated:YES completion:nil];
}


- (void)actionNext {
    [self.dayController scrollToNextTab];
}


- (void)actionTop {
    [self.dayController scrollToTop];
}


#pragma mark - Delegate

#pragma mark DKListControllerDelegate

- (void)DKTabDumpsControllerSelectedDump:(DKTabDump *)dump {
    [self loadDump:dump];
    [self setupRightButtons];
}


#pragma mark DKDayControllerDelegate

- (void)DKDayControllerDidScroll {
    //rotate
    [UIView beginAnimations:@"rotate" context:nil];
    [UIView setAnimationDuration:0.5];
    self.scrollButton.transform = CGAffineTransformMakeRotation(M_PI);
    [UIView commitAnimations];
    
    // remove target
    [self.scrollButton removeTarget:nil action:nil forControlEvents:UIControlEventTouchUpInside];
    
    // add target
    [self.scrollButton addTarget:self action:@selector(actionTop) forControlEvents:UIControlEventTouchUpInside];
}


- (void)DKDayControllerScrolledToTop {
    // rotate
    [UIView beginAnimations:@"rotate" context:nil];
    [UIView setAnimationDuration:0.5];
    self.scrollButton.transform = CGAffineTransformMakeRotation(180*M_PI);
    [UIView commitAnimations];
    
    // remove target
    [self.scrollButton removeTarget:nil action:nil forControlEvents:UIControlEventTouchUpInside];
    
    // add target
    [self.scrollButton addTarget:self action:@selector(actionNext) forControlEvents:UIControlEventTouchUpInside];
}


- (void)DKDayControllerRequestRefresh {
    [self loadTabDumpRSS];
}


@end
