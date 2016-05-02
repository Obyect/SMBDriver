//
//  ViewController.m
//  SMBDriver
//
//  Created by Shay BC on 01/05/16.
//  Copyright © 2016 Obyect. All rights reserved.
//

#import "ViewController.h"
#import "smb/SMBDriver.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // init the SMBDriver object
    SMBDriver * driver = [[SMBDriver alloc] init];
    
    // set debug mode to true
    driver.debug = YES;

    // execute the write test method
    [driver testWrite];
    
    // execute the test read method
    [driver testRead];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
